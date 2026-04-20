import 'package:flutter/foundation.dart';

import '../../domain/repositories/task_repository.dart';

/// ============================================================
/// SyncService — Core Offline-First Sync Engine
/// ============================================================
///
/// Responsibilities:
///   1. Pull queued tasks from the local database
///   2. Attempt to upload each task to the remote API (mocked)
///   3. Handle success/failure with status updates and logging
///   4. Retry failed tasks with exponential backoff
///   5. Permanently fail tasks that exceed the max retry threshold
///   6. Process tasks in controlled batches to limit resource usage
///
/// This service operates against the [TaskRepository] abstraction,
/// keeping it fully decoupled from the data layer (Drift/DAO).
/// ============================================================

import '../network/api_service.dart';
import 'sync_models.dart';
export 'sync_models.dart';

class SyncService {
  /// The repository abstraction used for all database operations.
  final TaskRepository _repository;

  /// The api service used to perform remote network requests.
  final ApiService _apiService;

  /// Maximum number of retry attempts before a task is permanently failed.
  static const int maxRetries = 3;

  /// Maximum number of tasks to process concurrently in a single batch.
  static const int batchSize = 5;

  /// Base delay (in seconds) for exponential backoff calculation.
  /// Actual delay = baseBackoffSeconds * 2^(retryCount - 1)
  /// Retry 1 → 2s, Retry 2 → 4s, Retry 3 → 8s
  static const int baseBackoffSeconds = 2;

  SyncService(this._repository, this._apiService);

  // =====================================================================
  // PUBLIC API
  // =====================================================================

  /// Entry point for the sync engine.
  ///
  /// Fetches items atomically from the database via [claimQueuedTasks],
  /// and processes each batch sequentially. Each task within a batch is
  /// processed concurrently via [Future.wait].
  ///
  /// Returns a [SyncResult] summarizing the outcome of the entire cycle.
  Future<SyncResult> syncTasks() async {
    debugPrint('[SyncEngine] ═══════════════════════════════════════');
    debugPrint('[SyncEngine] 🔄 SYNC CYCLE STARTED at ${DateTime.now()}');
    debugPrint('[SyncEngine] ═══════════════════════════════════════');

    try {
      int successCount = 0;
      int failureCount = 0;
      int permanentlyFailedCount = 0;
      int totalProcessed = 0;
      int batchIndex = 0;

      // ── Process tasks in atomic batches until the queue is drained ──
      while (true) {
        // Atomically fetch and lock a batch of queued tasks
        final batch = await _repository.claimQueuedTasks(batchSize);

        if (batch.isEmpty) {
          if (totalProcessed == 0) {
            debugPrint('[SyncEngine] ℹ️  No queued tasks found. Nothing to sync.');
          } else {
            debugPrint('[SyncEngine] ℹ️  Queue fully drained.');
          }
          break; // Exit the loop when no more items are queued
        }

        batchIndex++;
        totalProcessed += batch.length;
        
        debugPrint('[SyncEngine] ── Batch $batchIndex (${batch.length} tasks) ──');
        
        // Process all tasks in this batch concurrently
        final results = await Future.wait(
          batch.map((queueItem) => _processTask(queueItem)),
        );

        // Tally results from this batch
        for (final result in results) {
          switch (result) {
            case TaskSyncResult.success:
              successCount++;
              break;
            case TaskSyncResult.retryable:
              failureCount++;
              break;
            case TaskSyncResult.permanentlyFailed:
              permanentlyFailedCount++;
              break;
          }
        }
      }

      debugPrint('[SyncEngine] ═══════════════════════════════════════');
      debugPrint('[SyncEngine] ✅ SYNC CYCLE COMPLETE');
      debugPrint('[SyncEngine]    Total processed: $totalProcessed');
      debugPrint('[SyncEngine]    Synced:           $successCount');
      debugPrint('[SyncEngine]    Retryable fails:  $failureCount');
      debugPrint('[SyncEngine]    Permanent fails:  $permanentlyFailedCount');
      debugPrint('[SyncEngine] ═══════════════════════════════════════');

      // ── Maintanence: Run database cleanup ──
      await cleanupOldData();

      return SyncResult(
        totalProcessed: totalProcessed,
        successCount: successCount,
        failureCount: failureCount,
        permanentlyFailedCount: permanentlyFailedCount,
      );
    } catch (e) {
      // Catch-all for unexpected errors in the sync loop itself
      debugPrint('[SyncEngine] ❌ SYNC CYCLE CRASHED: $e');
      return SyncResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
        permanentlyFailedCount: 0,
        error: e.toString(),
      );
    }
  }

  /// Performs routine database cleanup to prevent infinite growth.
  /// Safely removes old successful queue entries, old logs, and old synced tasks.
  Future<void> cleanupOldData() async {
    try {
      debugPrint('[SyncEngine] 🧹 Running database cleanup...');
      await _repository.clearSuccessfulSyncQueues();
      await _repository.clearOldLogs();
      await _repository.clearOldSyncedTasks();
      debugPrint('[SyncEngine] 🧹 Cleanup finished successfully.');
    } catch (e) {
      debugPrint('[SyncEngine] ⚠️ Cleanup failed: $e');
    }
  }

  // =====================================================================
  // INTERNAL — Per-Task Processing Pipeline
  // =====================================================================

  /// Processes a single [SyncQueueEntity] through the full sync lifecycle:
  ///
  /// 1. Mark the task as "syncing" (in_progress in queue)
  /// 2. Attempt the mock API upload
  /// 3. On success → mark synced, log success
  /// 4. On failure → apply retry logic or permanently fail
  Future<TaskSyncResult> _processTask(SyncQueueEntity queueItem) async {
    final taskId = queueItem.taskId;
    debugPrint('[SyncEngine] ──────────────────────────────────');
    debugPrint('[SyncEngine] 🔄 Processing task: $taskId');
    debugPrint('[SyncEngine]    Queue ID: ${queueItem.id} | Retry count: ${queueItem.retryCount}/$maxRetries');

    try {
      debugPrint('[SyncEngine]    Status → instantly locked via DB transaction');

      // ── Apply exponential backoff delay if this is a retry ──
      if (queueItem.retryCount > 0) {
        final delaySeconds = _calculateBackoff(queueItem.retryCount);
        debugPrint('[SyncEngine]    ⏳ Backoff delay: ${delaySeconds}s (retry #${queueItem.retryCount})');
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      // ── Retrieve the full TaskEntity ──
      final allTasks = await _repository.getAllTasks();
      final taskEntity = allTasks.firstWhere((t) => t.id == taskId);

      // ── Attempt the API upload ──
      debugPrint('[SyncEngine]    📡 Calling real API for task: $taskId ...');
      final success = await _apiService.uploadTask(taskEntity);

      if (success) {
        debugPrint('[SyncEngine]    ✅ API call SUCCEEDED for task: $taskId');
        return await _handleSuccess(queueItem);
      } else {
        debugPrint('[SyncEngine]    ❌ API call FAILED for task: $taskId');
        return await _handleFailure(queueItem, 'API returned failure response');
      }
    } catch (e) {
      // Network errors, timeouts, serialization issues, etc.
      debugPrint('[SyncEngine]    💥 EXCEPTION for task $taskId: $e');
      return await _handleFailure(queueItem, 'Exception during sync: $e');
    }
  }

  // =====================================================================
  // INTERNAL — Success Handler
  // =====================================================================

  /// Called when the API upload succeeds.
  /// Updates both the task and queue status, and logs the success.
  Future<TaskSyncResult> _handleSuccess(SyncQueueEntity queueItem) async {
    final taskId = queueItem.taskId;

    // ── Update task status to synced ──
    await _repository.updateTaskStatus(taskId, TaskStatus.synced);

    // ── Update queue entry to success ──
    await _repository.updateSyncStatus(queueItem.id, SyncStatus.success);

    // ── Log the successful sync ──
    await _repository.addLog(
      taskId,
      'Task synced successfully on attempt ${queueItem.retryCount + 1}',
      LogStatus.success,
    );

    debugPrint('[SyncEngine]    🎉 Task $taskId → SYNCED (attempt ${queueItem.retryCount + 1})');
    return TaskSyncResult.success;
  }

  // =====================================================================
  // INTERNAL — Failure & Retry Handler
  // =====================================================================

  /// Called when the API upload fails (either returns false or throws).
  ///
  /// Retry logic:
  ///   - If retryCount <= [maxRetries]: increment retry, keep status queued
  ///     so the next sync cycle picks it up again.
  ///   - If retryCount > [maxRetries]: mark as permanently failed.
  Future<TaskSyncResult> _handleFailure(
    SyncQueueEntity queueItem,
    String errorMessage,
  ) async {
    final taskId = queueItem.taskId;
    final newRetryCount = queueItem.retryCount + 1;

    if (newRetryCount <= maxRetries) {
      // ── Still has retries left → increment and re-queue ──
      await _repository.updateRetry(queueItem.id, newRetryCount);

      // Reset task back to pending so it's eligible for the next sync cycle
      await _repository.updateTaskStatus(taskId, TaskStatus.pending);

      // Reset queue status back to queued so it's picked up again
      await _repository.updateSyncStatus(queueItem.id, SyncStatus.queued);

      // ── Log the retryable failure ──
      await _repository.addLog(
        taskId,
        'Sync failed (retry $newRetryCount/$maxRetries): $errorMessage. '
        'Will retry with ${_calculateBackoff(newRetryCount)}s backoff.',
        LogStatus.failed,
      );

      debugPrint('[SyncEngine]    🔁 Task $taskId → RETRY ($newRetryCount/$maxRetries) — next backoff: ${_calculateBackoff(newRetryCount)}s');
      return TaskSyncResult.retryable;
    } else {
      // ── Max retries exhausted → permanently fail ──
      await _repository.updateTaskStatus(taskId, TaskStatus.failed);
      await _repository.updateSyncStatus(queueItem.id, SyncStatus.failed);

      // ── Log the permanent failure ──
      await _repository.addLog(
        taskId,
        'Sync permanently failed after $maxRetries retries: $errorMessage',
        LogStatus.failed,
      );

      debugPrint('[SyncEngine]    ⛔ Task $taskId → PERMANENTLY FAILED after $maxRetries retries');
      return TaskSyncResult.permanentlyFailed;
    }
  }

  // =====================================================================
  // UTILITY — Batching & Backoff
  // =====================================================================

  /// Calculates exponential backoff delay in seconds.
  ///
  /// Formula: baseBackoffSeconds × 2^(retryCount - 1)
  ///   Retry 1 → 2s
  ///   Retry 2 → 4s
  ///   Retry 3 → 8s
  int _calculateBackoff(int retryCount) {
    return baseBackoffSeconds * (1 << (retryCount - 1)); // 2^(n-1)
  }
}

// Types are defined in sync_models.dart (re-exported from this file).
