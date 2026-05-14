// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_local_database.dart';

// ignore_for_file: type=lint
class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _namespaceMeta =
      const VerificationMeta('namespace');
  @override
  late final GeneratedColumn<String> namespace = GeneratedColumn<String>(
      'namespace', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _staleAtMeta =
      const VerificationMeta('staleAt');
  @override
  late final GeneratedColumn<DateTime> staleAt = GeneratedColumn<DateTime>(
      'stale_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
      'etag', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
      'last_modified', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        namespace,
        cacheKey,
        payloadJson,
        fetchedAt,
        staleAt,
        expiresAt,
        etag,
        lastModified
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('namespace')) {
      context.handle(_namespaceMeta,
          namespace.isAcceptableOrUnknown(data['namespace']!, _namespaceMeta));
    } else if (isInserting) {
      context.missing(_namespaceMeta);
    }
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('stale_at')) {
      context.handle(_staleAtMeta,
          staleAt.isAcceptableOrUnknown(data['stale_at']!, _staleAtMeta));
    } else if (isInserting) {
      context.missing(_staleAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
          _etagMeta, etag.isAcceptableOrUnknown(data['etag']!, _etagMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, namespace, cacheKey};
  @override
  CacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntry(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      namespace: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}namespace'])!,
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
      staleAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}stale_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
      etag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}etag']),
      lastModified: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_modified']),
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntry extends DataClass implements Insertable<CacheEntry> {
  final String userId;
  final String namespace;
  final String cacheKey;
  final String payloadJson;
  final DateTime fetchedAt;
  final DateTime staleAt;
  final DateTime expiresAt;
  final String? etag;
  final String? lastModified;
  const CacheEntry(
      {required this.userId,
      required this.namespace,
      required this.cacheKey,
      required this.payloadJson,
      required this.fetchedAt,
      required this.staleAt,
      required this.expiresAt,
      this.etag,
      this.lastModified});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['namespace'] = Variable<String>(namespace);
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload_json'] = Variable<String>(payloadJson);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['stale_at'] = Variable<DateTime>(staleAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      userId: Value(userId),
      namespace: Value(namespace),
      cacheKey: Value(cacheKey),
      payloadJson: Value(payloadJson),
      fetchedAt: Value(fetchedAt),
      staleAt: Value(staleAt),
      expiresAt: Value(expiresAt),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
    );
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntry(
      userId: serializer.fromJson<String>(json['userId']),
      namespace: serializer.fromJson<String>(json['namespace']),
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      staleAt: serializer.fromJson<DateTime>(json['staleAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'namespace': serializer.toJson<String>(namespace),
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'staleAt': serializer.toJson<DateTime>(staleAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
    };
  }

  CacheEntry copyWith(
          {String? userId,
          String? namespace,
          String? cacheKey,
          String? payloadJson,
          DateTime? fetchedAt,
          DateTime? staleAt,
          DateTime? expiresAt,
          Value<String?> etag = const Value.absent(),
          Value<String?> lastModified = const Value.absent()}) =>
      CacheEntry(
        userId: userId ?? this.userId,
        namespace: namespace ?? this.namespace,
        cacheKey: cacheKey ?? this.cacheKey,
        payloadJson: payloadJson ?? this.payloadJson,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        staleAt: staleAt ?? this.staleAt,
        expiresAt: expiresAt ?? this.expiresAt,
        etag: etag.present ? etag.value : this.etag,
        lastModified:
            lastModified.present ? lastModified.value : this.lastModified,
      );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      namespace: data.namespace.present ? data.namespace.value : this.namespace,
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      staleAt: data.staleAt.present ? data.staleAt.value : this.staleAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('userId: $userId, ')
          ..write('namespace: $namespace, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('staleAt: $staleAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, namespace, cacheKey, payloadJson,
      fetchedAt, staleAt, expiresAt, etag, lastModified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.userId == this.userId &&
          other.namespace == this.namespace &&
          other.cacheKey == this.cacheKey &&
          other.payloadJson == this.payloadJson &&
          other.fetchedAt == this.fetchedAt &&
          other.staleAt == this.staleAt &&
          other.expiresAt == this.expiresAt &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> userId;
  final Value<String> namespace;
  final Value<String> cacheKey;
  final Value<String> payloadJson;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> staleAt;
  final Value<DateTime> expiresAt;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.userId = const Value.absent(),
    this.namespace = const Value.absent(),
    this.cacheKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.staleAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String userId,
    required String namespace,
    required String cacheKey,
    required String payloadJson,
    required DateTime fetchedAt,
    required DateTime staleAt,
    required DateTime expiresAt,
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        namespace = Value(namespace),
        cacheKey = Value(cacheKey),
        payloadJson = Value(payloadJson),
        fetchedAt = Value(fetchedAt),
        staleAt = Value(staleAt),
        expiresAt = Value(expiresAt);
  static Insertable<CacheEntry> custom({
    Expression<String>? userId,
    Expression<String>? namespace,
    Expression<String>? cacheKey,
    Expression<String>? payloadJson,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? staleAt,
    Expression<DateTime>? expiresAt,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (namespace != null) 'namespace': namespace,
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (staleAt != null) 'stale_at': staleAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? namespace,
      Value<String>? cacheKey,
      Value<String>? payloadJson,
      Value<DateTime>? fetchedAt,
      Value<DateTime>? staleAt,
      Value<DateTime>? expiresAt,
      Value<String?>? etag,
      Value<String?>? lastModified,
      Value<int>? rowid}) {
    return CacheEntriesCompanion(
      userId: userId ?? this.userId,
      namespace: namespace ?? this.namespace,
      cacheKey: cacheKey ?? this.cacheKey,
      payloadJson: payloadJson ?? this.payloadJson,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      staleAt: staleAt ?? this.staleAt,
      expiresAt: expiresAt ?? this.expiresAt,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (namespace.present) {
      map['namespace'] = Variable<String>(namespace.value);
    }
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (staleAt.present) {
      map['stale_at'] = Variable<DateTime>(staleAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('userId: $userId, ')
          ..write('namespace: $namespace, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('staleAt: $staleAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatSummariesTable extends ChatSummaries
    with TableInfo<$ChatSummariesTable, ChatSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatKindMeta =
      const VerificationMeta('chatKind');
  @override
  late final GeneratedColumn<String> chatKind = GeneratedColumn<String>(
      'chat_kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _summaryJsonMeta =
      const VerificationMeta('summaryJson');
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
      'summary_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, chatId, chatKind, summaryJson, updatedAt, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_summaries';
  @override
  VerificationContext validateIntegrity(Insertable<ChatSummary> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('chat_kind')) {
      context.handle(_chatKindMeta,
          chatKind.isAcceptableOrUnknown(data['chat_kind']!, _chatKindMeta));
    } else if (isInserting) {
      context.missing(_chatKindMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
          _summaryJsonMeta,
          summaryJson.isAcceptableOrUnknown(
              data['summary_json']!, _summaryJsonMeta));
    } else if (isInserting) {
      context.missing(_summaryJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, chatId};
  @override
  ChatSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSummary(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      chatKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_kind'])!,
      summaryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $ChatSummariesTable createAlias(String alias) {
    return $ChatSummariesTable(attachedDatabase, alias);
  }
}

class ChatSummary extends DataClass implements Insertable<ChatSummary> {
  final String userId;
  final String chatId;
  final String chatKind;
  final String summaryJson;
  final DateTime updatedAt;
  final DateTime fetchedAt;
  const ChatSummary(
      {required this.userId,
      required this.chatId,
      required this.chatKind,
      required this.summaryJson,
      required this.updatedAt,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['chat_id'] = Variable<String>(chatId);
    map['chat_kind'] = Variable<String>(chatKind);
    map['summary_json'] = Variable<String>(summaryJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  ChatSummariesCompanion toCompanion(bool nullToAbsent) {
    return ChatSummariesCompanion(
      userId: Value(userId),
      chatId: Value(chatId),
      chatKind: Value(chatKind),
      summaryJson: Value(summaryJson),
      updatedAt: Value(updatedAt),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory ChatSummary.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSummary(
      userId: serializer.fromJson<String>(json['userId']),
      chatId: serializer.fromJson<String>(json['chatId']),
      chatKind: serializer.fromJson<String>(json['chatKind']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'chatId': serializer.toJson<String>(chatId),
      'chatKind': serializer.toJson<String>(chatKind),
      'summaryJson': serializer.toJson<String>(summaryJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  ChatSummary copyWith(
          {String? userId,
          String? chatId,
          String? chatKind,
          String? summaryJson,
          DateTime? updatedAt,
          DateTime? fetchedAt}) =>
      ChatSummary(
        userId: userId ?? this.userId,
        chatId: chatId ?? this.chatId,
        chatKind: chatKind ?? this.chatKind,
        summaryJson: summaryJson ?? this.summaryJson,
        updatedAt: updatedAt ?? this.updatedAt,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  ChatSummary copyWithCompanion(ChatSummariesCompanion data) {
    return ChatSummary(
      userId: data.userId.present ? data.userId.value : this.userId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      chatKind: data.chatKind.present ? data.chatKind.value : this.chatKind,
      summaryJson:
          data.summaryJson.present ? data.summaryJson.value : this.summaryJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSummary(')
          ..write('userId: $userId, ')
          ..write('chatId: $chatId, ')
          ..write('chatKind: $chatKind, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, chatId, chatKind, summaryJson, updatedAt, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSummary &&
          other.userId == this.userId &&
          other.chatId == this.chatId &&
          other.chatKind == this.chatKind &&
          other.summaryJson == this.summaryJson &&
          other.updatedAt == this.updatedAt &&
          other.fetchedAt == this.fetchedAt);
}

class ChatSummariesCompanion extends UpdateCompanion<ChatSummary> {
  final Value<String> userId;
  final Value<String> chatId;
  final Value<String> chatKind;
  final Value<String> summaryJson;
  final Value<DateTime> updatedAt;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const ChatSummariesCompanion({
    this.userId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.chatKind = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatSummariesCompanion.insert({
    required String userId,
    required String chatId,
    required String chatKind,
    required String summaryJson,
    required DateTime updatedAt,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        chatId = Value(chatId),
        chatKind = Value(chatKind),
        summaryJson = Value(summaryJson),
        updatedAt = Value(updatedAt),
        fetchedAt = Value(fetchedAt);
  static Insertable<ChatSummary> custom({
    Expression<String>? userId,
    Expression<String>? chatId,
    Expression<String>? chatKind,
    Expression<String>? summaryJson,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (chatId != null) 'chat_id': chatId,
      if (chatKind != null) 'chat_kind': chatKind,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatSummariesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? chatId,
      Value<String>? chatKind,
      Value<String>? summaryJson,
      Value<DateTime>? updatedAt,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return ChatSummariesCompanion(
      userId: userId ?? this.userId,
      chatId: chatId ?? this.chatId,
      chatKind: chatKind ?? this.chatKind,
      summaryJson: summaryJson ?? this.summaryJson,
      updatedAt: updatedAt ?? this.updatedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (chatKind.present) {
      map['chat_kind'] = Variable<String>(chatKind.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSummariesCompanion(')
          ..write('userId: $userId, ')
          ..write('chatId: $chatId, ')
          ..write('chatKind: $chatKind, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientMessageIdMeta =
      const VerificationMeta('clientMessageId');
  @override
  late final GeneratedColumn<String> clientMessageId = GeneratedColumn<String>(
      'client_message_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _messageJsonMeta =
      const VerificationMeta('messageJson');
  @override
  late final GeneratedColumn<String> messageJson = GeneratedColumn<String>(
      'message_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        chatId,
        messageId,
        clientMessageId,
        messageJson,
        createdAt,
        fetchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(Insertable<ChatMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('client_message_id')) {
      context.handle(
          _clientMessageIdMeta,
          clientMessageId.isAcceptableOrUnknown(
              data['client_message_id']!, _clientMessageIdMeta));
    }
    if (data.containsKey('message_json')) {
      context.handle(
          _messageJsonMeta,
          messageJson.isAcceptableOrUnknown(
              data['message_json']!, _messageJsonMeta));
    } else if (isInserting) {
      context.missing(_messageJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, chatId, messageId};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      clientMessageId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_message_id']),
      messageJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String userId;
  final String chatId;
  final String messageId;
  final String? clientMessageId;
  final String messageJson;
  final DateTime createdAt;
  final DateTime fetchedAt;
  const ChatMessage(
      {required this.userId,
      required this.chatId,
      required this.messageId,
      this.clientMessageId,
      required this.messageJson,
      required this.createdAt,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['chat_id'] = Variable<String>(chatId);
    map['message_id'] = Variable<String>(messageId);
    if (!nullToAbsent || clientMessageId != null) {
      map['client_message_id'] = Variable<String>(clientMessageId);
    }
    map['message_json'] = Variable<String>(messageJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      userId: Value(userId),
      chatId: Value(chatId),
      messageId: Value(messageId),
      clientMessageId: clientMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientMessageId),
      messageJson: Value(messageJson),
      createdAt: Value(createdAt),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      userId: serializer.fromJson<String>(json['userId']),
      chatId: serializer.fromJson<String>(json['chatId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      clientMessageId: serializer.fromJson<String?>(json['clientMessageId']),
      messageJson: serializer.fromJson<String>(json['messageJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'chatId': serializer.toJson<String>(chatId),
      'messageId': serializer.toJson<String>(messageId),
      'clientMessageId': serializer.toJson<String?>(clientMessageId),
      'messageJson': serializer.toJson<String>(messageJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  ChatMessage copyWith(
          {String? userId,
          String? chatId,
          String? messageId,
          Value<String?> clientMessageId = const Value.absent(),
          String? messageJson,
          DateTime? createdAt,
          DateTime? fetchedAt}) =>
      ChatMessage(
        userId: userId ?? this.userId,
        chatId: chatId ?? this.chatId,
        messageId: messageId ?? this.messageId,
        clientMessageId: clientMessageId.present
            ? clientMessageId.value
            : this.clientMessageId,
        messageJson: messageJson ?? this.messageJson,
        createdAt: createdAt ?? this.createdAt,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      userId: data.userId.present ? data.userId.value : this.userId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      clientMessageId: data.clientMessageId.present
          ? data.clientMessageId.value
          : this.clientMessageId,
      messageJson:
          data.messageJson.present ? data.messageJson.value : this.messageJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('userId: $userId, ')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('messageJson: $messageJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, chatId, messageId, clientMessageId,
      messageJson, createdAt, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.userId == this.userId &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.clientMessageId == this.clientMessageId &&
          other.messageJson == this.messageJson &&
          other.createdAt == this.createdAt &&
          other.fetchedAt == this.fetchedAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> userId;
  final Value<String> chatId;
  final Value<String> messageId;
  final Value<String?> clientMessageId;
  final Value<String> messageJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.userId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.clientMessageId = const Value.absent(),
    this.messageJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String userId,
    required String chatId,
    required String messageId,
    this.clientMessageId = const Value.absent(),
    required String messageJson,
    required DateTime createdAt,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        chatId = Value(chatId),
        messageId = Value(messageId),
        messageJson = Value(messageJson),
        createdAt = Value(createdAt),
        fetchedAt = Value(fetchedAt);
  static Insertable<ChatMessage> custom({
    Expression<String>? userId,
    Expression<String>? chatId,
    Expression<String>? messageId,
    Expression<String>? clientMessageId,
    Expression<String>? messageJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      if (messageJson != null) 'message_json': messageJson,
      if (createdAt != null) 'created_at': createdAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? chatId,
      Value<String>? messageId,
      Value<String?>? clientMessageId,
      Value<String>? messageJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return ChatMessagesCompanion(
      userId: userId ?? this.userId,
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      messageJson: messageJson ?? this.messageJson,
      createdAt: createdAt ?? this.createdAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (clientMessageId.present) {
      map['client_message_id'] = Variable<String>(clientMessageId.value);
    }
    if (messageJson.present) {
      map['message_json'] = Variable<String>(messageJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('userId: $userId, ')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('messageJson: $messageJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
      'cursor', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, chatId, cursor, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<SyncCursor> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(_cursorMeta,
          cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta));
    } else if (isInserting) {
      context.missing(_cursorMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, chatId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      cursor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cursor'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String userId;
  final String chatId;
  final String cursor;
  final DateTime updatedAt;
  const SyncCursor(
      {required this.userId,
      required this.chatId,
      required this.cursor,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['chat_id'] = Variable<String>(chatId);
    map['cursor'] = Variable<String>(cursor);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      userId: Value(userId),
      chatId: Value(chatId),
      cursor: Value(cursor),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncCursor.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      userId: serializer.fromJson<String>(json['userId']),
      chatId: serializer.fromJson<String>(json['chatId']),
      cursor: serializer.fromJson<String>(json['cursor']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'chatId': serializer.toJson<String>(chatId),
      'cursor': serializer.toJson<String>(cursor),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncCursor copyWith(
          {String? userId,
          String? chatId,
          String? cursor,
          DateTime? updatedAt}) =>
      SyncCursor(
        userId: userId ?? this.userId,
        chatId: chatId ?? this.chatId,
        cursor: cursor ?? this.cursor,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      userId: data.userId.present ? data.userId.value : this.userId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('userId: $userId, ')
          ..write('chatId: $chatId, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, chatId, cursor, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.userId == this.userId &&
          other.chatId == this.chatId &&
          other.cursor == this.cursor &&
          other.updatedAt == this.updatedAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> userId;
  final Value<String> chatId;
  final Value<String> cursor;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.userId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String userId,
    required String chatId,
    required String cursor,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        chatId = Value(chatId),
        cursor = Value(cursor),
        updatedAt = Value(updatedAt);
  static Insertable<SyncCursor> custom({
    Expression<String>? userId,
    Expression<String>? chatId,
    Expression<String>? cursor,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (chatId != null) 'chat_id': chatId,
      if (cursor != null) 'cursor': cursor,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? chatId,
      Value<String>? cursor,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SyncCursorsCompanion(
      userId: userId ?? this.userId,
      chatId: chatId ?? this.chatId,
      cursor: cursor ?? this.cursor,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('userId: $userId, ')
          ..write('chatId: $chatId, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingCommandsTable extends PendingCommands
    with TableInfo<$PendingCommandsTable, PendingCommand> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingCommandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _commandIdMeta =
      const VerificationMeta('commandId');
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
      'command_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commandTypeMeta =
      const VerificationMeta('commandType');
  @override
  late final GeneratedColumn<String> commandType = GeneratedColumn<String>(
      'command_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        commandId,
        chatId,
        commandType,
        payloadJson,
        createdAt,
        updatedAt,
        attempts,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_commands';
  @override
  VerificationContext validateIntegrity(Insertable<PendingCommand> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(_commandIdMeta,
          commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta));
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    }
    if (data.containsKey('command_type')) {
      context.handle(
          _commandTypeMeta,
          commandType.isAcceptableOrUnknown(
              data['command_type']!, _commandTypeMeta));
    } else if (isInserting) {
      context.missing(_commandTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, commandId};
  @override
  PendingCommand map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingCommand(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      commandId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}command_id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id']),
      commandType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}command_type'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $PendingCommandsTable createAlias(String alias) {
    return $PendingCommandsTable(attachedDatabase, alias);
  }
}

class PendingCommand extends DataClass implements Insertable<PendingCommand> {
  final String userId;
  final String commandId;
  final String? chatId;
  final String commandType;
  final String payloadJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attempts;
  final String? lastError;
  const PendingCommand(
      {required this.userId,
      required this.commandId,
      this.chatId,
      required this.commandType,
      required this.payloadJson,
      required this.createdAt,
      required this.updatedAt,
      required this.attempts,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['command_id'] = Variable<String>(commandId);
    if (!nullToAbsent || chatId != null) {
      map['chat_id'] = Variable<String>(chatId);
    }
    map['command_type'] = Variable<String>(commandType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingCommandsCompanion toCompanion(bool nullToAbsent) {
    return PendingCommandsCompanion(
      userId: Value(userId),
      commandId: Value(commandId),
      chatId:
          chatId == null && nullToAbsent ? const Value.absent() : Value(chatId),
      commandType: Value(commandType),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingCommand.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingCommand(
      userId: serializer.fromJson<String>(json['userId']),
      commandId: serializer.fromJson<String>(json['commandId']),
      chatId: serializer.fromJson<String?>(json['chatId']),
      commandType: serializer.fromJson<String>(json['commandType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'commandId': serializer.toJson<String>(commandId),
      'chatId': serializer.toJson<String?>(chatId),
      'commandType': serializer.toJson<String>(commandType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingCommand copyWith(
          {String? userId,
          String? commandId,
          Value<String?> chatId = const Value.absent(),
          String? commandType,
          String? payloadJson,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? attempts,
          Value<String?> lastError = const Value.absent()}) =>
      PendingCommand(
        userId: userId ?? this.userId,
        commandId: commandId ?? this.commandId,
        chatId: chatId.present ? chatId.value : this.chatId,
        commandType: commandType ?? this.commandType,
        payloadJson: payloadJson ?? this.payloadJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  PendingCommand copyWithCompanion(PendingCommandsCompanion data) {
    return PendingCommand(
      userId: data.userId.present ? data.userId.value : this.userId,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      commandType:
          data.commandType.present ? data.commandType.value : this.commandType,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingCommand(')
          ..write('userId: $userId, ')
          ..write('commandId: $commandId, ')
          ..write('chatId: $chatId, ')
          ..write('commandType: $commandType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, commandId, chatId, commandType,
      payloadJson, createdAt, updatedAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingCommand &&
          other.userId == this.userId &&
          other.commandId == this.commandId &&
          other.chatId == this.chatId &&
          other.commandType == this.commandType &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PendingCommandsCompanion extends UpdateCompanion<PendingCommand> {
  final Value<String> userId;
  final Value<String> commandId;
  final Value<String?> chatId;
  final Value<String> commandType;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int> rowid;
  const PendingCommandsCompanion({
    this.userId = const Value.absent(),
    this.commandId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.commandType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingCommandsCompanion.insert({
    required String userId,
    required String commandId,
    this.chatId = const Value.absent(),
    required String commandType,
    required String payloadJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        commandId = Value(commandId),
        commandType = Value(commandType),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PendingCommand> custom({
    Expression<String>? userId,
    Expression<String>? commandId,
    Expression<String>? chatId,
    Expression<String>? commandType,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (commandId != null) 'command_id': commandId,
      if (chatId != null) 'chat_id': chatId,
      if (commandType != null) 'command_type': commandType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingCommandsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? commandId,
      Value<String?>? chatId,
      Value<String>? commandType,
      Value<String>? payloadJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return PendingCommandsCompanion(
      userId: userId ?? this.userId,
      commandId: commandId ?? this.commandId,
      chatId: chatId ?? this.chatId,
      commandType: commandType ?? this.commandType,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (commandType.present) {
      map['command_type'] = Variable<String>(commandType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingCommandsCompanion(')
          ..write('userId: $userId, ')
          ..write('commandId: $commandId, ')
          ..write('chatId: $chatId, ')
          ..write('commandType: $commandType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppLocalDatabase extends GeneratedDatabase {
  _$AppLocalDatabase(QueryExecutor e) : super(e);
  $AppLocalDatabaseManager get managers => $AppLocalDatabaseManager(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  late final $ChatSummariesTable chatSummaries = $ChatSummariesTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $PendingCommandsTable pendingCommands =
      $PendingCommandsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [cacheEntries, chatSummaries, chatMessages, syncCursors, pendingCommands];
}

typedef $$CacheEntriesTableCreateCompanionBuilder = CacheEntriesCompanion
    Function({
  required String userId,
  required String namespace,
  required String cacheKey,
  required String payloadJson,
  required DateTime fetchedAt,
  required DateTime staleAt,
  required DateTime expiresAt,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<int> rowid,
});
typedef $$CacheEntriesTableUpdateCompanionBuilder = CacheEntriesCompanion
    Function({
  Value<String> userId,
  Value<String> namespace,
  Value<String> cacheKey,
  Value<String> payloadJson,
  Value<DateTime> fetchedAt,
  Value<DateTime> staleAt,
  Value<DateTime> expiresAt,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<int> rowid,
});

class $$CacheEntriesTableFilterComposer
    extends Composer<_$AppLocalDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get namespace => $composableBuilder(
      column: $table.namespace, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get staleAt => $composableBuilder(
      column: $table.staleAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get etag => $composableBuilder(
      column: $table.etag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));
}

class $$CacheEntriesTableOrderingComposer
    extends Composer<_$AppLocalDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get namespace => $composableBuilder(
      column: $table.namespace, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get staleAt => $composableBuilder(
      column: $table.staleAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get etag => $composableBuilder(
      column: $table.etag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));
}

class $$CacheEntriesTableAnnotationComposer
    extends Composer<_$AppLocalDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get namespace =>
      $composableBuilder(column: $table.namespace, builder: (column) => column);

  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get staleAt =>
      $composableBuilder(column: $table.staleAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);
}

class $$CacheEntriesTableTableManager extends RootTableManager<
    _$AppLocalDatabase,
    $CacheEntriesTable,
    CacheEntry,
    $$CacheEntriesTableFilterComposer,
    $$CacheEntriesTableOrderingComposer,
    $$CacheEntriesTableAnnotationComposer,
    $$CacheEntriesTableCreateCompanionBuilder,
    $$CacheEntriesTableUpdateCompanionBuilder,
    (
      CacheEntry,
      BaseReferences<_$AppLocalDatabase, $CacheEntriesTable, CacheEntry>
    ),
    CacheEntry,
    PrefetchHooks Function()> {
  $$CacheEntriesTableTableManager(
      _$AppLocalDatabase db, $CacheEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> namespace = const Value.absent(),
            Value<String> cacheKey = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<DateTime> staleAt = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<String?> etag = const Value.absent(),
            Value<String?> lastModified = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheEntriesCompanion(
            userId: userId,
            namespace: namespace,
            cacheKey: cacheKey,
            payloadJson: payloadJson,
            fetchedAt: fetchedAt,
            staleAt: staleAt,
            expiresAt: expiresAt,
            etag: etag,
            lastModified: lastModified,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String namespace,
            required String cacheKey,
            required String payloadJson,
            required DateTime fetchedAt,
            required DateTime staleAt,
            required DateTime expiresAt,
            Value<String?> etag = const Value.absent(),
            Value<String?> lastModified = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheEntriesCompanion.insert(
            userId: userId,
            namespace: namespace,
            cacheKey: cacheKey,
            payloadJson: payloadJson,
            fetchedAt: fetchedAt,
            staleAt: staleAt,
            expiresAt: expiresAt,
            etag: etag,
            lastModified: lastModified,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CacheEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppLocalDatabase,
    $CacheEntriesTable,
    CacheEntry,
    $$CacheEntriesTableFilterComposer,
    $$CacheEntriesTableOrderingComposer,
    $$CacheEntriesTableAnnotationComposer,
    $$CacheEntriesTableCreateCompanionBuilder,
    $$CacheEntriesTableUpdateCompanionBuilder,
    (
      CacheEntry,
      BaseReferences<_$AppLocalDatabase, $CacheEntriesTable, CacheEntry>
    ),
    CacheEntry,
    PrefetchHooks Function()>;
typedef $$ChatSummariesTableCreateCompanionBuilder = ChatSummariesCompanion
    Function({
  required String userId,
  required String chatId,
  required String chatKind,
  required String summaryJson,
  required DateTime updatedAt,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$ChatSummariesTableUpdateCompanionBuilder = ChatSummariesCompanion
    Function({
  Value<String> userId,
  Value<String> chatId,
  Value<String> chatKind,
  Value<String> summaryJson,
  Value<DateTime> updatedAt,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$ChatSummariesTableFilterComposer
    extends Composer<_$AppLocalDatabase, $ChatSummariesTable> {
  $$ChatSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatKind => $composableBuilder(
      column: $table.chatKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$ChatSummariesTableOrderingComposer
    extends Composer<_$AppLocalDatabase, $ChatSummariesTable> {
  $$ChatSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatKind => $composableBuilder(
      column: $table.chatKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$ChatSummariesTableAnnotationComposer
    extends Composer<_$AppLocalDatabase, $ChatSummariesTable> {
  $$ChatSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get chatKind =>
      $composableBuilder(column: $table.chatKind, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ChatSummariesTableTableManager extends RootTableManager<
    _$AppLocalDatabase,
    $ChatSummariesTable,
    ChatSummary,
    $$ChatSummariesTableFilterComposer,
    $$ChatSummariesTableOrderingComposer,
    $$ChatSummariesTableAnnotationComposer,
    $$ChatSummariesTableCreateCompanionBuilder,
    $$ChatSummariesTableUpdateCompanionBuilder,
    (
      ChatSummary,
      BaseReferences<_$AppLocalDatabase, $ChatSummariesTable, ChatSummary>
    ),
    ChatSummary,
    PrefetchHooks Function()> {
  $$ChatSummariesTableTableManager(
      _$AppLocalDatabase db, $ChatSummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> chatId = const Value.absent(),
            Value<String> chatKind = const Value.absent(),
            Value<String> summaryJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatSummariesCompanion(
            userId: userId,
            chatId: chatId,
            chatKind: chatKind,
            summaryJson: summaryJson,
            updatedAt: updatedAt,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String chatId,
            required String chatKind,
            required String summaryJson,
            required DateTime updatedAt,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatSummariesCompanion.insert(
            userId: userId,
            chatId: chatId,
            chatKind: chatKind,
            summaryJson: summaryJson,
            updatedAt: updatedAt,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatSummariesTableProcessedTableManager = ProcessedTableManager<
    _$AppLocalDatabase,
    $ChatSummariesTable,
    ChatSummary,
    $$ChatSummariesTableFilterComposer,
    $$ChatSummariesTableOrderingComposer,
    $$ChatSummariesTableAnnotationComposer,
    $$ChatSummariesTableCreateCompanionBuilder,
    $$ChatSummariesTableUpdateCompanionBuilder,
    (
      ChatSummary,
      BaseReferences<_$AppLocalDatabase, $ChatSummariesTable, ChatSummary>
    ),
    ChatSummary,
    PrefetchHooks Function()>;
typedef $$ChatMessagesTableCreateCompanionBuilder = ChatMessagesCompanion
    Function({
  required String userId,
  required String chatId,
  required String messageId,
  Value<String?> clientMessageId,
  required String messageJson,
  required DateTime createdAt,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$ChatMessagesTableUpdateCompanionBuilder = ChatMessagesCompanion
    Function({
  Value<String> userId,
  Value<String> chatId,
  Value<String> messageId,
  Value<String?> clientMessageId,
  Value<String> messageJson,
  Value<DateTime> createdAt,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppLocalDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientMessageId => $composableBuilder(
      column: $table.clientMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageJson => $composableBuilder(
      column: $table.messageJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppLocalDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientMessageId => $composableBuilder(
      column: $table.clientMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageJson => $composableBuilder(
      column: $table.messageJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppLocalDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get clientMessageId => $composableBuilder(
      column: $table.clientMessageId, builder: (column) => column);

  GeneratedColumn<String> get messageJson => $composableBuilder(
      column: $table.messageJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ChatMessagesTableTableManager extends RootTableManager<
    _$AppLocalDatabase,
    $ChatMessagesTable,
    ChatMessage,
    $$ChatMessagesTableFilterComposer,
    $$ChatMessagesTableOrderingComposer,
    $$ChatMessagesTableAnnotationComposer,
    $$ChatMessagesTableCreateCompanionBuilder,
    $$ChatMessagesTableUpdateCompanionBuilder,
    (
      ChatMessage,
      BaseReferences<_$AppLocalDatabase, $ChatMessagesTable, ChatMessage>
    ),
    ChatMessage,
    PrefetchHooks Function()> {
  $$ChatMessagesTableTableManager(
      _$AppLocalDatabase db, $ChatMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> chatId = const Value.absent(),
            Value<String> messageId = const Value.absent(),
            Value<String?> clientMessageId = const Value.absent(),
            Value<String> messageJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatMessagesCompanion(
            userId: userId,
            chatId: chatId,
            messageId: messageId,
            clientMessageId: clientMessageId,
            messageJson: messageJson,
            createdAt: createdAt,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String chatId,
            required String messageId,
            Value<String?> clientMessageId = const Value.absent(),
            required String messageJson,
            required DateTime createdAt,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatMessagesCompanion.insert(
            userId: userId,
            chatId: chatId,
            messageId: messageId,
            clientMessageId: clientMessageId,
            messageJson: messageJson,
            createdAt: createdAt,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppLocalDatabase,
    $ChatMessagesTable,
    ChatMessage,
    $$ChatMessagesTableFilterComposer,
    $$ChatMessagesTableOrderingComposer,
    $$ChatMessagesTableAnnotationComposer,
    $$ChatMessagesTableCreateCompanionBuilder,
    $$ChatMessagesTableUpdateCompanionBuilder,
    (
      ChatMessage,
      BaseReferences<_$AppLocalDatabase, $ChatMessagesTable, ChatMessage>
    ),
    ChatMessage,
    PrefetchHooks Function()>;
typedef $$SyncCursorsTableCreateCompanionBuilder = SyncCursorsCompanion
    Function({
  required String userId,
  required String chatId,
  required String cursor,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SyncCursorsTableUpdateCompanionBuilder = SyncCursorsCompanion
    Function({
  Value<String> userId,
  Value<String> chatId,
  Value<String> cursor,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppLocalDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppLocalDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppLocalDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncCursorsTableTableManager extends RootTableManager<
    _$AppLocalDatabase,
    $SyncCursorsTable,
    SyncCursor,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (
      SyncCursor,
      BaseReferences<_$AppLocalDatabase, $SyncCursorsTable, SyncCursor>
    ),
    SyncCursor,
    PrefetchHooks Function()> {
  $$SyncCursorsTableTableManager(_$AppLocalDatabase db, $SyncCursorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> chatId = const Value.absent(),
            Value<String> cursor = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncCursorsCompanion(
            userId: userId,
            chatId: chatId,
            cursor: cursor,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String chatId,
            required String cursor,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncCursorsCompanion.insert(
            userId: userId,
            chatId: chatId,
            cursor: cursor,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncCursorsTableProcessedTableManager = ProcessedTableManager<
    _$AppLocalDatabase,
    $SyncCursorsTable,
    SyncCursor,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (
      SyncCursor,
      BaseReferences<_$AppLocalDatabase, $SyncCursorsTable, SyncCursor>
    ),
    SyncCursor,
    PrefetchHooks Function()>;
typedef $$PendingCommandsTableCreateCompanionBuilder = PendingCommandsCompanion
    Function({
  required String userId,
  required String commandId,
  Value<String?> chatId,
  required String commandType,
  required String payloadJson,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$PendingCommandsTableUpdateCompanionBuilder = PendingCommandsCompanion
    Function({
  Value<String> userId,
  Value<String> commandId,
  Value<String?> chatId,
  Value<String> commandType,
  Value<String> payloadJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$PendingCommandsTableFilterComposer
    extends Composer<_$AppLocalDatabase, $PendingCommandsTable> {
  $$PendingCommandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get commandId => $composableBuilder(
      column: $table.commandId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get commandType => $composableBuilder(
      column: $table.commandType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$PendingCommandsTableOrderingComposer
    extends Composer<_$AppLocalDatabase, $PendingCommandsTable> {
  $$PendingCommandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get commandId => $composableBuilder(
      column: $table.commandId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get commandType => $composableBuilder(
      column: $table.commandType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$PendingCommandsTableAnnotationComposer
    extends Composer<_$AppLocalDatabase, $PendingCommandsTable> {
  $$PendingCommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get commandType => $composableBuilder(
      column: $table.commandType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingCommandsTableTableManager extends RootTableManager<
    _$AppLocalDatabase,
    $PendingCommandsTable,
    PendingCommand,
    $$PendingCommandsTableFilterComposer,
    $$PendingCommandsTableOrderingComposer,
    $$PendingCommandsTableAnnotationComposer,
    $$PendingCommandsTableCreateCompanionBuilder,
    $$PendingCommandsTableUpdateCompanionBuilder,
    (
      PendingCommand,
      BaseReferences<_$AppLocalDatabase, $PendingCommandsTable, PendingCommand>
    ),
    PendingCommand,
    PrefetchHooks Function()> {
  $$PendingCommandsTableTableManager(
      _$AppLocalDatabase db, $PendingCommandsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingCommandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingCommandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingCommandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> commandId = const Value.absent(),
            Value<String?> chatId = const Value.absent(),
            Value<String> commandType = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingCommandsCompanion(
            userId: userId,
            commandId: commandId,
            chatId: chatId,
            commandType: commandType,
            payloadJson: payloadJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String commandId,
            Value<String?> chatId = const Value.absent(),
            required String commandType,
            required String payloadJson,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingCommandsCompanion.insert(
            userId: userId,
            commandId: commandId,
            chatId: chatId,
            commandType: commandType,
            payloadJson: payloadJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingCommandsTableProcessedTableManager = ProcessedTableManager<
    _$AppLocalDatabase,
    $PendingCommandsTable,
    PendingCommand,
    $$PendingCommandsTableFilterComposer,
    $$PendingCommandsTableOrderingComposer,
    $$PendingCommandsTableAnnotationComposer,
    $$PendingCommandsTableCreateCompanionBuilder,
    $$PendingCommandsTableUpdateCompanionBuilder,
    (
      PendingCommand,
      BaseReferences<_$AppLocalDatabase, $PendingCommandsTable, PendingCommand>
    ),
    PendingCommand,
    PrefetchHooks Function()>;

class $AppLocalDatabaseManager {
  final _$AppLocalDatabase _db;
  $AppLocalDatabaseManager(this._db);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
  $$ChatSummariesTableTableManager get chatSummaries =>
      $$ChatSummariesTableTableManager(_db, _db.chatSummaries);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$PendingCommandsTableTableManager get pendingCommands =>
      $$PendingCommandsTableTableManager(_db, _db.pendingCommands);
}
