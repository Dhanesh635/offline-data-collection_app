import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/background_sync_worker.dart';
import 'core/providers/providers.dart';
import 'features/main_screen.dart';

/// ============================================================
/// Application Entry Point
/// ============================================================
///
/// Initialization order:
///   1. WidgetsFlutterBinding — required before any plugin calls
///   2. Workmanager — registers the background sync callback
///   3. ProviderScope — Riverpod dependency tree (database, repo, etc.)
///   4. ConnectivitySyncTrigger — started from within the widget tree
///      via a provider so it has access to the foreground SyncService
/// ============================================================

void main() async {
  // Required before calling any plugin (Workmanager, path_provider, etc.)
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize Workmanager & register periodic background sync ──
  // isDebugMode: true → shows a notification when background tasks run (dev only)
  // Set to false for production builds.
  await initializeBackgroundSync(isDebugMode: true);

  runApp(
    // ProviderScope is REQUIRED at the root for Riverpod to function.
    // All providers (database, dao, repository, UI state) are resolved through this scope.
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── ACTIVATE CONNECTIVITY SYNC TRIGGER ──
    // This starts listening to network changes to trigger sync on internet restore.
    ref.watch(connectivitySyncProvider);

    return MaterialApp(
      title: 'Data Collection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Charcoal / almost black
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurpleAccent,
          secondary: Colors.blueAccent,
          surface: const Color(0xFF1E1E1E), // Elevated surface
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
