import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/dao.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/task_repository.dart';

// Re-export the split provider files so all existing imports of this file
// continue to resolve every provider without any consumer-side changes.
export 'ui_providers.dart';
export 'sync_providers.dart';

// ==========================================
// CORE INFRASTRUCTURE PROVIDERS
// ==========================================

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
