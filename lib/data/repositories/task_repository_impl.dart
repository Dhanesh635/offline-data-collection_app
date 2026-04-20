import 'package:drift/drift.dart';
import '../../domain/repositories/task_repository.dart';
import '../local/database.dart' as db;
import '../local/dao.dart';
import '../local/models.dart' as models;

class TaskRepositoryImpl implements TaskRepository {
  final AppDao _dao;

  TaskRepositoryImpl(this._dao);

  TaskEntity _mapTask(db.Task t) {
    return TaskEntity(
      id: t.id,
      title: t.title,
      type: TaskType.values[t.type.index],
      status: TaskStatus.values[t.status.index],
      payload: t.payload,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    );
  }

  SyncQueueEntity _mapQueue(db.SyncQueue q) {
    return SyncQueueEntity(
      id: q.id,
      taskId: q.taskId,
      retryCount: q.retryCount,
      lastAttemptAt: q.lastAttemptAt,
      status: SyncStatus.values[q.status.index],
    );
  }

  SyncLogEntity _mapLog(db.SyncLog l) {
    return SyncLogEntity(
      id: l.id,
      taskId: l.taskId,
      message: l.message,
      status: LogStatus.values[l.status.index],
      timestamp: l.timestamp,
    );
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    final tasks = await _dao.getAllTasks();
    return tasks.map(_mapTask).toList();
  }

  @override
  Future<List<TaskEntity>> getPendingTasks() async {
    final tasks = await _dao.getPendingTasks();
    return tasks.map(_mapTask).toList();
  }

  @override
  Future<void> addTask(TaskEntity task) async {
    try {
      await _dao.transaction(() async {
        final companion = db.TasksCompanion(
          id: Value(task.id),
          title: Value(task.title),
          type: Value(models.TaskType.values[task.type.index]),
          status: Value(models.TaskStatus.values[task.status.index]),
          payload: Value(task.payload),
          createdAt: Value(task.createdAt),
          updatedAt: Value(task.updatedAt),
        );
        await _dao.insertTask(companion);

        final queueCompanion = db.SyncQueuesCompanion.insert(
          taskId: task.id,
          status: models.SyncStatus.queued,
          retryCount: const Value(0),
          lastAttemptAt: Value(DateTime.now()),
        );
        await _dao.insertSyncQueue(queueCompanion);
      });
    } catch (e) {
      await addLog(task.id, 'Failed to add task: $e', LogStatus.failed);
      rethrow;
    }
  }

  @override
  Future<void> updateTaskStatus(String id, TaskStatus status) async {
    try {
      await _dao.updateTaskStatus(id, models.TaskStatus.values[status.index]);
    } catch (e) {
      await addLog(id, 'Failed to update task status: $e', LogStatus.failed);
      rethrow;
    }
  }

  @override
  Future<void> addToSyncQueue(String taskId) async {
    try {
      final companion = db.SyncQueuesCompanion.insert(
        taskId: taskId,
        status: models.SyncStatus.queued,
        retryCount: const Value(0),
        lastAttemptAt: Value(DateTime.now()),
      );
      await _dao.insertSyncQueue(companion);
    } catch (e) {
      await addLog(taskId, 'Failed to add to sync queue: $e', LogStatus.failed);
      rethrow;
    }
  }

  @override
  Future<List<SyncQueueEntity>> getQueuedTasks() async {
    final queues = await _dao.getQueuedTasks();
    return queues.map(_mapQueue).toList();
  }

  @override
  Future<List<SyncQueueEntity>> claimQueuedTasks(int limit) async {
    final queues = await _dao.claimQueuedTasks(limit);
    return queues.map(_mapQueue).toList();
  }


  @override
  Future<void> updateRetry(int queueId, int retryCount) async {
    try {
      await _dao.updateRetryCount(queueId, retryCount);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateSyncStatus(int queueId, SyncStatus status) async {
    try {
      await _dao.updateSyncStatus(queueId, models.SyncStatus.values[status.index]);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addLog(String taskId, String message, LogStatus status) async {
    try {
      final companion = db.SyncLogsCompanion.insert(
        taskId: taskId,
        message: message,
        status: models.LogStatus.values[status.index],
        timestamp: Value(DateTime.now()),
      );
      await _dao.insertLog(companion);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<SyncLogEntity>> getLogs(String taskId) async {
    final logs = await _dao.getLogs(taskId);
    return logs.map(_mapLog).toList();
  }

  // =====================
  // CLEANUP OPERATIONS
  // =====================

  @override
  Future<void> clearOldLogs() async {
    try {
      await _dao.clearOldLogs();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearSuccessfulSyncQueues() async {
    try {
      await _dao.clearSuccessfulSyncQueues();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> clearOldSyncedTasks() async {
    try {
      await _dao.clearOldSyncedTasks();
    } catch (e) {
      rethrow;
    }
  }
}
