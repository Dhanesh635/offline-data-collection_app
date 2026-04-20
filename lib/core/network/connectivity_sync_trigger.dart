import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../sync/sync_service.dart';
import '../sync/background_sync_worker.dart';

/// ============================================================
/// ConnectivitySyncTrigger — Network-Aware Sync Trigger
/// ============================================================
///
/// Listens for network connectivity changes via connectivity_plus.
/// When the device transitions from offline → online, it triggers
/// an immediate sync cycle to flush any queued tasks.
///
/// Two operating modes:
///   1. **Foreground mode** — uses an injected SyncService instance
///      (from Riverpod) to run sync in the same isolate. Ideal for
///      real-time UI feedback.
///   2. **Background mode** — schedules a Workmanager one-shot task
///      via [triggerOneShotSync()]. This is the fallback when no
///      foreground SyncService is available.
///
/// Usage:
///   final trigger = ConnectivitySyncTrigger(syncService: syncService);
///   trigger.startListening();
///   // ... later ...
///   trigger.dispose();
/// ============================================================

class ConnectivitySyncTrigger {
  /// Optional foreground sync service instance.
  /// If provided, sync runs in-process; otherwise a background task is scheduled.
  final SyncService? _syncService;

  /// The connectivity plugin instance.
  final Connectivity _connectivity = Connectivity();

  /// Stream subscription for connectivity changes.
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Tracks the previous connectivity state to detect offline → online transitions.
  bool _wasOffline = false;

  /// Prevents multiple sync triggers from firing simultaneously.
  bool _isSyncTriggered = false;

  ConnectivitySyncTrigger({SyncService? syncService})
      : _syncService = syncService;

  // =====================================================================
  // PUBLIC API
  // =====================================================================

  /// Start listening for connectivity changes.
  ///
  /// Performs an initial check to set the baseline connectivity state,
  /// then subscribes to ongoing changes.
  Future<void> startListening() async {
    debugPrint('[ConnectivitySync] 📡 Starting connectivity listener...');

    // ── Initial state check ──
    try {
      final initialResults = await _connectivity.checkConnectivity();
      _wasOffline = _isOffline(initialResults);
      debugPrint('[ConnectivitySync] 📶 Initial state: ${_wasOffline ? "OFFLINE" : "ONLINE"}');
    } catch (e) {
      debugPrint('[ConnectivitySync] ⚠️ Failed to check initial connectivity: $e');
      _wasOffline = true; // Assume offline as safe default
    }

    // ── Subscribe to connectivity stream ──
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        debugPrint('[ConnectivitySync] ❌ Connectivity stream error: $error');
      },
    );

    debugPrint('[ConnectivitySync] ✅ Connectivity listener active');
  }

  /// Stop listening and release resources.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('[ConnectivitySync] 🛑 Connectivity listener disposed');
  }

  // =====================================================================
  // INTERNAL — Connectivity Change Handler
  // =====================================================================

  /// Called every time the device's connectivity state changes.
  ///
  /// Detects the offline → online transition pattern and triggers sync:
  ///   - If was offline AND now online → trigger sync
  ///   - All other transitions → just update the state tracker
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final isCurrentlyOffline = _isOffline(results);

    debugPrint('[ConnectivitySync] 📶 Connectivity changed: '
        '${results.map((r) => r.name).join(", ")} '
        '(${isCurrentlyOffline ? "OFFLINE" : "ONLINE"})');

    if (_wasOffline && !isCurrentlyOffline) {
      // ── OFFLINE → ONLINE transition detected ──
      debugPrint('[ConnectivitySync] 🔄 Network restored! Triggering sync...');
      await _triggerSync();
    }

    // Update the tracker for next transition detection
    _wasOffline = isCurrentlyOffline;
  }

  /// Triggers a sync cycle, either in-process or via background task.
  /// Includes a guard to prevent overlapping triggers.
  Future<void> _triggerSync() async {
    // Guard against rapid-fire triggers
    if (_isSyncTriggered) {
      debugPrint('[ConnectivitySync] ⚠️ Sync already triggered, skipping');
      return;
    }

    _isSyncTriggered = true;

    try {
      if (_syncService != null) {
        // ── Foreground mode: run sync directly ──
        debugPrint('[ConnectivitySync] ⚡ Running foreground sync...');
        final result = await _syncService.syncTasks();
        debugPrint('[ConnectivitySync] 📊 Foreground sync result: $result');
      } else {
        // ── Background mode: schedule via Workmanager ──
        debugPrint('[ConnectivitySync] 📦 Scheduling background one-shot sync...');
        await triggerOneShotSync();
      }
    } catch (e) {
      debugPrint('[ConnectivitySync] ❌ Sync trigger failed: $e');
    } finally {
      // Reset the guard after a short delay to allow re-triggering
      // if connectivity flaps (disconnect → reconnect quickly)
      Future.delayed(const Duration(seconds: 10), () {
        _isSyncTriggered = false;
      });
    }
  }

  // =====================================================================
  // UTILITY — Connectivity Helpers
  // =====================================================================

  /// Returns true if the device has no usable network connection.
  bool _isOffline(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
  }
}
