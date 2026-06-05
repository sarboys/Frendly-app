import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_local_database.g.dart';

class CacheEntries extends Table {
  TextColumn get userScope => text()();
  TextColumn get namespace => text()();
  TextColumn get cacheKey => text()();
  TextColumn get jsonValue => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userScope, namespace, cacheKey};
}

class ChatSummaries extends Table {
  TextColumn get userId => text()();
  TextColumn get kind => text()();
  TextColumn get chatId => text()();
  TextColumn get jsonValue => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, kind, chatId};
}

class ChatMessages extends Table {
  TextColumn get userId => text()();
  TextColumn get chatId => text()();
  TextColumn get localKey => text()();
  TextColumn get messageId => text().nullable()();
  TextColumn get clientMessageId => text().nullable()();
  TextColumn get jsonValue => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, chatId, localKey};
}

class SyncCursors extends Table {
  TextColumn get userId => text()();
  TextColumn get scope => text()();
  TextColumn get cursor => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, scope};
}

class PendingCommands extends Table {
  TextColumn get userId => text()();
  TextColumn get commandId => text()();
  TextColumn get dedupeKey => text()();
  TextColumn get jsonValue => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, commandId};
}

class PendingMediaUploads extends Table {
  TextColumn get userId => text()();
  TextColumn get uploadId => text()();
  TextColumn get chatId => text()();
  TextColumn get clientMessageId => text()();
  TextColumn get localPath => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  TextColumn get kind => text()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get waveformJson => text()();
  TextColumn get objectKey => text().nullable()();
  TextColumn get assetId => text().nullable()();
  TextColumn get status => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, uploadId};
}

@DriftDatabase(
  tables: [
    CacheEntries,
    ChatSummaries,
    ChatMessages,
    SyncCursors,
    PendingCommands,
    PendingMediaUploads,
  ],
)
class AppLocalDatabase extends _$AppLocalDatabase {
  AppLocalDatabase() : super(_openConnection());

  AppLocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(pendingMediaUploads);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'dateasy_local_cache');
  }
}

QueryExecutor inMemoryAppLocalDatabaseExecutor() => NativeDatabase.memory();
