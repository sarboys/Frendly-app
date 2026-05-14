import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_local_database.g.dart';

@DriftDatabase(
  tables: [
    CacheEntries,
    ChatSummaries,
    ChatMessages,
    SyncCursors,
    PendingCommands,
  ],
)
class AppLocalDatabase extends _$AppLocalDatabase {
  AppLocalDatabase()
      : super(
          driftDatabase(
            name: 'frendly_local_cache',
            native: const DriftNativeOptions(shareAcrossIsolates: true),
          ),
        );

  AppLocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );
}

class CacheEntries extends Table {
  TextColumn get userId => text()();
  TextColumn get namespace => text()();
  TextColumn get cacheKey => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get staleAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userId, namespace, cacheKey};
}

class ChatSummaries extends Table {
  TextColumn get userId => text()();
  TextColumn get chatId => text()();
  TextColumn get chatKind => text()();
  TextColumn get summaryJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, chatId};
}

class ChatMessages extends Table {
  TextColumn get userId => text()();
  TextColumn get chatId => text()();
  TextColumn get messageId => text()();
  TextColumn get clientMessageId => text().nullable()();
  TextColumn get messageJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, chatId, messageId};
}

class SyncCursors extends Table {
  TextColumn get userId => text()();
  TextColumn get chatId => text()();
  TextColumn get cursor => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, chatId};
}

class PendingCommands extends Table {
  TextColumn get userId => text()();
  TextColumn get commandId => text()();
  TextColumn get chatId => text().nullable()();
  TextColumn get commandType => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userId, commandId};
}
