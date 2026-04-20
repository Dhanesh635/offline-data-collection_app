import 'package:drift/drift.dart';

import 'database.dart';
import 'models.dart';

part 'dao.g.dart';

/// App Data Access Object
/// Provides focused, typed methods for querying the SQLite database.
@DriftAccessor(tables: [Tasks, SyncQueues, SyncLogs])
class AppDao extends DatabaseAccessor<AppDatabase> with _$AppDaoMixin {
  AppDao(super.db);

  // =====================
  // Task Operations
  // =====================

  /// Insert a newly created data collection task into the database.
  Future<int> insertTask(TasksCompanion task) {
    return into(tasks).insert(task);
  }

  /// Update the synchronization status of a specific task.
  /// Also bumps the updatedAt timestamp.
  Future<int> updateTaskStatus(String id, TaskStatus status) {
    return (update(tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ));
  }

  /// Retrieve all tasks for general user listing.
  Future<List<Task>> getAllTasks() {
    return select(tasks).get();
  }

  /// Retrieve only tasks that are ready for syncing to the backend.
  Future<List<Task>> getPendingTasks() {
    return (select(tasks)..where((t) => t.status.equals(TaskStatus.pending.index))).get();
  }

  // =====================
  // Sync Queue Operations
  // =====================

  /// Retrieve all sync queue entries that are currently queued.
  Future<List<SyncQueue>> getQueuedTasks() {
    return (select(syncQueues)..where((q) => q.status.equals(SyncStatus.queued.index))).get();
  }

  /// Delete a sync queue item, typically called after a successful sync.
  Future<int> deleteQueueItem(int id) {
    return (delete(syncQueues)..where((q) => q.id.equals(id))).go();
  }

  /// Update the status of a sync queue entry.
  Future<int> updateSyncStatus(int queueId, SyncStatus status) {
    return (update(syncQueues)..where((q) => q.id.equals(queueId)))
        .write(SyncQueuesCompanion(
          status: Value(status),
          lastAttemptAt: Value(DateTime.now()),
        ));
  }

  /// Enqueue a task for synchronization by inserting it into the sync table.
  Future<int> insertSyncQueue(SyncQueuesCompanion entry) {
    return into(syncQueues).insert(entry);
  }

  /// Update the retry count and last attempt timestamp when sync fails.
  /// Useful for backoff strategies.
  Future<int> updateRetryCount(int queueId, int retryCount) {
    return (update(syncQueues)..where((q) => q.id.equals(queueId)))
        .write(SyncQueuesCompanion(
          retryCount: Value(retryCount),
          lastAttemptAt: Value(DateTime.now()),
        ));
  }

  // =====================
  // Sync Log Operations
  // =====================

  /// Insert a detailed log message for sync results (success or failure).
  Future<int> insertLog(SyncLogsCompanion log) {
    return into(syncLogs).insert(log);
  }

  /// Get logs associated with a specific task, ordered from newest to oldest.
  Future<List<SyncLog>> getLogs(String taskId) {
    return (select(syncLogs)
          ..where((l) => l.taskId.equals(taskId))
          ..orderBy([(l) => OrderingTerm(expression: l.timestamp, mode: OrderingMode.desc)]))
        .get();
  }

  // =====================
  // ATOMIC SYNC QUEUE CLAIM
  // =====================

  /// Atomically fetch up to [limit] queued tasks and immediately mark them as 'inProgress'.
  /// This ensures that another concurrent sync process doesn't pick up the same tasks.
  Future<List<SyncQueue>> claimQueuedTasks(int limit) async {
    return transaction(() async {
      // 1. Fetch available queued items
      final queuedItems = await (select(syncQueues)
            ..where((q) => q.status.equals(SyncStatus.queued.index))
            ..limit(limit))
          .get();

      if (queuedItems.isEmpty) return [];

      final queueIds = queuedItems.map((e) => e.id).toList();
      final taskIds = queuedItems.map((e) => e.taskId).toList();

      final now = DateTime.now();

      // 2. Mark queue items as inProgress
      await (update(syncQueues)..where((q) => q.id.isIn(queueIds))).write(
        SyncQueuesCompanion(
          status: Value(SyncStatus.inProgress),
          lastAttemptAt: Value(now),
        ),
      );

      // 3. Mark the corresponding tasks as syncing
      await (update(tasks)..where((t) => t.id.isIn(taskIds))).write(
        TasksCompanion(
          status: Value(TaskStatus.syncing),
          updatedAt: Value(now),
        ),
      );

  // Return the claimed items with their updated status
      return queuedItems
          .map((item) => item.copyWith(
                status: SyncStatus.inProgress,
                lastAttemptAt: Value(now),
              ))
          .toList();
    });
  }

  // =====================
  // CLEANUP OPERATIONS
  // =====================

  /// Deletes sync logs that are older than 7 days.
  Future<int> clearOldLogs() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return (delete(syncLogs)..where((l) => l.timestamp.isSmallerThanValue(cutoff))).go();
  }

  /// Removes sync queue entries that have successfully completed synchronization.
  Future<int> clearSuccessfulSyncQueues() {
    return (delete(syncQueues)..where((q) => q.status.equals(SyncStatus.success.index))).go();
  }

  /// Deletes tasks that have been successfully synced and are older than 30 days.
  Future<int> clearOldSyncedTasks() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return (delete(tasks)
          ..where((t) => t.status.equals(TaskStatus.synced.index) & t.updatedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
