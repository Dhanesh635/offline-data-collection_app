import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/dao.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/task_repository.dart';
import '../network/api_service.dart';
import '../network/connectivity_sync_trigger.dart';
import '../sync/sync_service.dart';

/// Provide the single instance of the Drift Database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provide the Data Access Object (DAO) mapped specifically for task queries.
final daoProvider = Provider<AppDao>((ref) {
  final db = ref.watch(databaseProvider);
  return AppDao(db);
});

/// Expose the Repository abstraction to the rest of the application.
final repositoryProvider = Provider<TaskRepository>((ref) {
  final dao = ref.watch(daoProvider);
  return TaskRepositoryImpl(dao);
});

// ==========================================
// UI STATE PROVIDERS (Added for Integration)
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

// ==========================================
// SYNC ENGINE PROVIDERS
// ==========================================

/// Provide the ApiService for network requests
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Provides a singleton SyncService instance backed by the TaskRepository.
/// Use this to access the service directly for manual trigger or scheduling.
final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.watch(repositoryProvider);
  final apiService = ref.watch(apiServiceProvider);
  return SyncService(repository, apiService);
});

/// One-shot provider to trigger a full sync cycle and observe its result.
///
/// Usage from UI/controller:
///   final result = await ref.read(syncTasksProvider.future);
///
/// To re-trigger, invalidate first:
///   ref.invalidate(syncTasksProvider);
///   final result = await ref.read(syncTasksProvider.future);
final syncTasksProvider = FutureProvider<SyncResult>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.syncTasks();
});

// ==========================================
// CONNECTIVITY SYNC TRIGGER
// ==========================================

/// Provides and auto-starts the ConnectivitySyncTrigger.
///
/// When first read/watched, it creates the trigger with the foreground
/// SyncService and immediately begins listening for offline→online transitions.
/// Properly disposes the listener when the provider is torn down.
///
/// Usage — read once from your root widget to activate:
///   ref.read(connectivitySyncProvider);
final connectivitySyncProvider = Provider<ConnectivitySyncTrigger>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final trigger = ConnectivitySyncTrigger(syncService: syncService);

  // Start listening immediately
  trigger.startListening();

  // Clean up when provider is disposed
  ref.onDispose(() => trigger.dispose());

  return trigger;
});
