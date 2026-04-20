import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_service.dart';
import '../network/connectivity_sync_trigger.dart';
import '../sync/sync_service.dart';
import 'providers.dart';

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
