import 'dart:convert';
import 'package:drift/drift.dart';

/// Define enums for the data layer to ensure type safety.
enum TaskType { audio, survey, image, text }

enum TaskStatus { local, pending, syncing, synced, failed }

enum SyncStatus { queued, inProgress, success, failed }

enum LogStatus { success, failed }

/// Task Model Table
/// Stores offline data collection tasks.
@DataClassName('Task')
@TableIndex(name: 'task_status_idx', columns: {#status})
class Tasks extends Table {
  /// Unique identifier for the task
  TextColumn get id => text()();

  /// Short title or description of the task
  TextColumn get title => text()();

  /// The type of data collection task (mapped using an integer index)
  IntColumn get type => intEnum<TaskType>()();

  /// The current synchronization status of the task
  IntColumn get status => intEnum<TaskStatus>()();

  /// Stores dynamic task data/payload as an encoded JSON string.
  /// A TypeConverter handles the `Map<String, dynamic>` <=> JSON String conversion.
  TextColumn get payload => text().map(const MapConverter())();

  /// Timestamp for when the task was created locally
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)() ;

  /// Timestamp for the latest modification of the task
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)() ;

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync Queue Model Table
/// Keeps track of tasks that need to be synced with the remote server.
@DataClassName('SyncQueue')
@TableIndex(name: 'queue_status_idx', columns: {#status})
@TableIndex(name: 'queue_task_id_idx', columns: {#taskId})
class SyncQueues extends Table {
  /// Auto-incrementing primary key
  IntColumn get id => integer().autoIncrement()();

  /// The task id that this sync entry refers to, creates a foreign key ref
  TextColumn get taskId => text().references(Tasks, #id)();

  /// Keeps track of retry attempts in case of sync failures
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Timestamp of the last sync attempt
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Status of the sync operation
  IntColumn get status => intEnum<SyncStatus>()();
}

/// Sync Log Model Table
/// Detailed logs for sync activities, useful for debugging and tracing.
@DataClassName('SyncLog')
class SyncLogs extends Table {
  /// Auto-incrementing primary key
  IntColumn get id => integer().autoIncrement()();

  /// The task id this log is associated with
  TextColumn get taskId => text().references(Tasks, #id)();

  /// Detailed result or error message
  TextColumn get message => text()();

  /// Log outcome mapped via enum (success / failed)
  IntColumn get status => intEnum<LogStatus>()();

  /// When the log entry was created
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

/// Type Converter for mapping JSON map payloads to Drift Texts
class MapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const MapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    return json.decode(fromDb) as Map<String, dynamic>;
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return json.encode(value);
  }
}
