/// Enums defined independently of the data layer
enum TaskType { audio, survey, image, text }
enum TaskStatus { local, pending, syncing, synced, failed }
enum SyncStatus { queued, inProgress, success, failed }
enum LogStatus { success, failed }

/// Domain Entity for Task
class TaskEntity {
  final String id;
  final String title;
  final TaskType type;
  final TaskStatus status;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Domain Entity for SyncQueue
class SyncQueueEntity {
  final int id;
  final String taskId;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final SyncStatus status;

  SyncQueueEntity({
    required this.id,
    required this.taskId,
    required this.retryCount,
    this.lastAttemptAt,
    required this.status,
  });
}

/// Domain Entity for SyncLog
class SyncLogEntity {
  final int id;
  final String taskId;
  final String message;
  final LogStatus status;
  final DateTime timestamp;

  SyncLogEntity({
    required this.id,
    required this.taskId,
    required this.message,
    required this.status,
    required this.timestamp,
  });
}

/// Abstract interface for the Task Repository.
/// This acts as a boundary between the Domain layer and the Data layer.
/// All application-level logic should consume this interface instead of the Data layer directly.
abstract class TaskRepository {
  /// Fetch all tasks from the offline database
  Future<List<TaskEntity>> getAllTasks();

  /// Fetch all tasks that are marked as 'pending' for synchronization
  Future<List<TaskEntity>> getPendingTasks();

  /// Insert a newly structured task into the system.
  /// Automatically attempts to create a unified transaction inserting into the sync queue.
  Future<void> addTask(TaskEntity task);

  /// Modify the status of an existing task (e.g. from local to pending)
  Future<void> updateTaskStatus(String id, TaskStatus status);

  /// Queue a specific task id into the sync engine table manually
  Future<void> addToSyncQueue(String taskId);

  /// Pull all tasks currently designated as 'queued' in the SyncQueue table
  Future<List<SyncQueueEntity>> getQueuedTasks();

  /// Atomically fetch up to [limit] queued tasks and immediately mark them as 'inProgress' in the database.
  Future<List<SyncQueueEntity>> claimQueuedTasks(int limit);

  /// Update the retry value and attempt timestamp for a failing sync operation
  Future<void> updateRetry(int queueId, int retryCount);

  /// Transition the status of a sync queue item linearly across the operation
  Future<void> updateSyncStatus(int queueId, SyncStatus status);

  /// Emits a persistent logging output for traceability of data engine tasks
  Future<void> addLog(String taskId, String message, LogStatus status);

  /// Returns historical trace logs associated with a particular task execution
  Future<List<SyncLogEntity>> getLogs(String taskId);

  // =====================
  // CLEANUP OPERATIONS
  // =====================

  /// Deletes sync logs older than 7 days
  Future<void> clearOldLogs();

  /// Removes sync queue entries that have successfully completed sync
  Future<void> clearSuccessfulSyncQueues();

  /// Deletes tasks successfully synced and older than 30 days
  Future<void> clearOldSyncedTasks();
}
