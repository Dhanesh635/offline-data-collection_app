import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'dao.dart';

part 'database.g.dart';

/// The central entry point for the offline database.
/// Provides access to the DAO and manages database schema migrations.
@DriftDatabase(
  tables: [Tasks, SyncQueues, SyncLogs],
  daos: [AppDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Bump this number when you change tables or columns.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // Creates all tables initially required for the offline db setup
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Implement schema migrations (e.g. adding columns) here
      },
    );
  }
}

/// Helper method to initialize the database connection lazily
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Get the application document directory where sqlite db will be stored
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'data_collection_app.sqlite'));
    
    // Create the NativeDatabase in the background to avoid blocking main isolate
    return NativeDatabase.createInBackground(file);
  });
}
