import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/local/database.dart';
import '../../data/local/dao.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../network/api_service.dart';
import '../sync/sync_service.dart';

/// ============================================================
/// Background Sync Worker — Workmanager Integration
/// ============================================================
///
/// This file contains:
///   1. The top-level callbackDispatcher (runs in a separate isolate)
///   2. Helper to register the periodic background sync task
///   3. Task name constants
///
/// IMPORTANT: Workmanager runs callbacks in a separate Dart isolate.
/// This means we CANNOT use Riverpod providers or any state from
/// the main isolate. All dependencies (database, DAO, repository,
/// sync service) must be freshly instantiated inside the callback.
/// ============================================================

// =====================================================================
// CONSTANTS — Task identifiers
// =====================================================================

/// Unique name for the periodic sync task registered with Workmanager.
const String backgroundSyncTaskName = 'com.datacollection.backgroundSync';

/// Unique name for the one-shot sync task (used for connectivity triggers).
const String oneShotSyncTaskName = 'com.datacollection.oneShotSync';

// =====================================================================
// TOP-LEVEL CALLBACK — Entry point for Workmanager isolate
// =====================================================================

/// Top-level function required by Workmanager.
///
/// This function is the entry point for ALL background tasks registered
/// with Workmanager. It runs in a completely separate Dart isolate,
/// so it has no access to the main isolate's memory, providers, or state.
///
/// Steps:
///   1. Create fresh database + DAO instances (same SQLite file on disk)
///   2. Build the repository and sync service
///   3. Run syncTasks()
///   4. Clean up the database connection
///   5. Return true (success) or false (failure) to the OS scheduler
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint("🔥 Background task started");
    debugPrint('[BackgroundSync] ═══════════════════════════════════════');
    debugPrint('[BackgroundSync] 🚀 Background task started: $taskName');
    debugPrint('[BackgroundSync]    Time: ${DateTime.now()}');
    debugPrint('[BackgroundSync] ═══════════════════════════════════════');

    // Track the database reference so we can close it in finally
    AppDatabase? db;

    try {
      // ── STEP 1: Create fresh dependency chain ──
      // We're in a new isolate — no access to Riverpod providers.
      // Must construct the full chain: Database → DAO → Repository → SyncService
      db = AppDatabase();
      final dao = AppDao(db);
      final repository = TaskRepositoryImpl(dao);
      final apiService = ApiService();
      final syncService = SyncService(repository, apiService);

      debugPrint('[BackgroundSync] ✅ Dependencies initialized');

      // ── STEP 2: Execute sync ──
      final result = await syncService.syncTasks();

      debugPrint('[BackgroundSync] ═══════════════════════════════════════');
      debugPrint('[BackgroundSync] 📊 Sync result: $result');
      debugPrint('[BackgroundSync] ═══════════════════════════════════════');

      // Return true to indicate successful execution to the OS.
      // Even if some tasks failed sync, the background job itself completed.
      return Future.value(true);
    } catch (e, stackTrace) {
      // ── Catch-all: prevent crashes in background isolate ──
      debugPrint('[BackgroundSync] ❌ BACKGROUND SYNC CRASHED');
      debugPrint('[BackgroundSync]    Error: $e');
      debugPrint('[BackgroundSync]    Stack: $stackTrace');

      // Return false tells the OS the task failed.
      // On Android, this may trigger a retry based on backoff policy.
      return Future.value(false);
    } finally {
      // ── STEP 3: Always close the database to avoid connection leaks ──
      if (db != null) {
        await db.close();
        debugPrint('[BackgroundSync] 🔒 Database connection closed');
      }
    }
  });
}

// =====================================================================
// REGISTRATION — Schedule periodic and one-shot background tasks
// =====================================================================

/// Initialize Workmanager and register the periodic background sync task.
///
/// Call this once from main() after WidgetsFlutterBinding.ensureInitialized().
///
/// The periodic task runs approximately every 15 minutes (the minimum
/// interval allowed by Android). On iOS, background fetch intervals
/// are controlled by the OS and may vary.
///
/// [isDebugMode] enables verbose Workmanager logging during development.
Future<void> initializeBackgroundSync({bool isDebugMode = false}) async {
  // ── Initialize the Workmanager plugin ──
  await Workmanager().initialize(
    callbackDispatcher,
    // ignore: deprecated_member_use
    isInDebugMode: isDebugMode,
  );

  debugPrint('[BackgroundSync] ✅ Workmanager initialized (debug: $isDebugMode)');

  // ── Register a one-off task for immediate testing ──
  debugPrint('[BackgroundSync] ⚡ Registering one-off task for testing');
  await Workmanager().registerOneOffTask(
    '${oneShotSyncTaskName}_startup_test',
    oneShotSyncTaskName,
    constraints: Constraints(networkType: NetworkType.connected),
  );

  // ── Register the periodic sync task ──
  // Frequency: every 15 minutes (minimum allowed by Android)
  // Constraints: requires network connectivity
  await Workmanager().registerPeriodicTask(
    backgroundSyncTaskName,         // Unique task identifier
    backgroundSyncTaskName,         // Task name passed to callbackDispatcher
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,   // Only run when network is available
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,  // Don't duplicate if already scheduled
    backoffPolicy: BackoffPolicy.exponential,     // Exponential backoff on failure
    backoffPolicyDelay: const Duration(minutes: 1),
  );

  debugPrint('[BackgroundSync] 📅 Periodic sync registered (every 15 min, requires network)');
}

/// Schedule a one-shot sync task. Useful for triggering an immediate
/// background sync when connectivity is restored.
///
/// Unlike the periodic task, this runs once and then completes.
Future<void> triggerOneShotSync() async {
  await Workmanager().registerOneOffTask(
    '${oneShotSyncTaskName}_${DateTime.now().millisecondsSinceEpoch}',
    oneShotSyncTaskName,
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,  // Replace any pending one-shot
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(seconds: 30),
  );

  debugPrint('[BackgroundSync] ⚡ One-shot sync task scheduled');
}

/// Cancel all registered background sync tasks.
/// Useful for logout, app reset, or user-initiated cancellation.
Future<void> cancelAllBackgroundSync() async {
  await Workmanager().cancelAll();
  debugPrint('[BackgroundSync] 🛑 All background sync tasks cancelled');
}
