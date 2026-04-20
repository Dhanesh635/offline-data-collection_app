import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/task_repository.dart';
import 'providers.dart';

// ==========================================
// UI STATE PROVIDERS
// ==========================================

/// Main task list provider
final allTasksProvider = FutureProvider<List<TaskEntity>>((ref) async {
  // If we want to refresh data, calling `ref.invalidate(allTasksProvider)` triggers a requery
  return ref.watch(repositoryProvider).getAllTasks();
});

// --- Dashboard Specific Counts ---

final totalTasksProvider = FutureProvider<int>((ref) async {
  final tasks = await ref.watch(allTasksProvider.future);
  return tasks.length;
});

final pendingTasksProvider = FutureProvider<int>((ref) async {
  final tasks = await ref.watch(allTasksProvider.future);
  return tasks.where((t) => t.status == TaskStatus.pending).length;
});

final syncedTasksProvider = FutureProvider<int>((ref) async {
  final tasks = await ref.watch(allTasksProvider.future);
  return tasks.where((t) => t.status == TaskStatus.synced).length;
});

final failedTasksProvider = FutureProvider<int>((ref) async {
  final tasks = await ref.watch(allTasksProvider.future);
  return tasks.where((t) => t.status == TaskStatus.failed).length;
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  // Placeholder logic until explicit global sync logs endpoint exists
  // Return recent time for demonstration
  return null;
});

// --- Sync Queue Providers ---

final queuedTasksProvider = FutureProvider<List<SyncQueueEntity>>((ref) async {
  return ref.watch(repositoryProvider).getQueuedTasks();
});

/// Logs provider depending on dynamic taskId parameter
final logsProvider = FutureProvider.family<List<SyncLogEntity>, String>((
  ref,
  taskId,
) async {
  return ref.watch(repositoryProvider).getLogs(taskId);
});
