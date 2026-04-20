// ============================================================
// Sync Models — Supporting types for the sync engine
// ============================================================
//
// Extracted from sync_service.dart to keep the orchestrator
// focused on behavior and these types independently reusable.
// ============================================================

/// Classifies the outcome of a single task sync attempt.
/// Used internally by [SyncService] to tally batch results.
enum TaskSyncResult { success, retryable, permanentlyFailed }

/// Public result class returned by [SyncService.syncTasks] to summarize
/// what happened during a complete sync cycle.
class SyncResult {
  /// Total number of queued tasks that were processed.
  final int totalProcessed;

  /// How many tasks synced successfully.
  final int successCount;

  /// How many tasks failed but are eligible for retry.
  final int failureCount;

  /// How many tasks exhausted all retries and were permanently failed.
  final int permanentlyFailedCount;

  /// Whether the sync was skipped because another cycle was already running.
  final bool skippedBecauseBusy;

  /// Any unexpected error message from the sync cycle itself.
  final String? error;

  SyncResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failureCount,
    required this.permanentlyFailedCount,
    this.skippedBecauseBusy = false,
    this.error,
  });

  /// True if every processed task synced successfully.
  bool get isFullSuccess =>
      totalProcessed > 0 &&
      successCount == totalProcessed &&
      error == null;

  /// True if at least one task failed (retryable or permanent).
  bool get hasFailures => failureCount > 0 || permanentlyFailedCount > 0;

  @override
  String toString() {
    if (skippedBecauseBusy) return 'SyncResult: Skipped (already syncing)';
    if (error != null) return 'SyncResult: Error — $error';
    return 'SyncResult: $successCount/$totalProcessed synced, '
        '$failureCount retryable, $permanentlyFailedCount permanently failed';
  }
}
