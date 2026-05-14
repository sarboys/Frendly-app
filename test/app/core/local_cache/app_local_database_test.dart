import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalDatabase db;

  setUp(() {
    db = AppLocalDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('cache entries are unique per user namespace and key', () async {
    final now = DateTime.utc(2026, 5, 14, 10);
    final entry = CacheEntriesCompanion.insert(
      userId: 'user-a',
      namespace: 'tonight',
      cacheKey: 'GET /events?limit=10',
      payloadJson: '{"items":[]}',
      fetchedAt: now,
      staleAt: now.add(const Duration(minutes: 2)),
      expiresAt: now.add(const Duration(minutes: 20)),
    );

    await db.into(db.cacheEntries).insert(entry);

    await expectLater(
      db.into(db.cacheEntries).insert(entry),
      throwsA(isA<Object>()),
    );
  });

  test('same cache key can be stored for separate users', () async {
    final now = DateTime.utc(2026, 5, 14, 10);

    for (final userId in ['user-a', 'user-b']) {
      await db.into(db.cacheEntries).insert(
            CacheEntriesCompanion.insert(
              userId: userId,
              namespace: 'chat_list',
              cacheKey: 'meetup',
              payloadJson: '{"items":[]}',
              fetchedAt: now,
              staleAt: now.add(const Duration(minutes: 1)),
              expiresAt: now.add(const Duration(minutes: 10)),
            ),
          );
    }

    final rows = await db.select(db.cacheEntries).get();

    expect(rows.map((row) => row.userId), containsAll(['user-a', 'user-b']));
    expect(rows, hasLength(2));
  });

  test('cache keys sort query params and skip null values', () {
    final first = AppCacheKey.build(
      path: '/events',
      query: {
        'limit': 20,
        'cursor': null,
        'city': 'Moscow',
        'tags': ['music', 'food'],
      },
    );
    final second = AppCacheKey.build(
      path: '/events',
      query: {
        'tags': ['music', 'food'],
        'city': 'Moscow',
        'limit': 20,
      },
    );

    expect(first, second);
    expect(first, '/events?city=Moscow&limit=20&tags=music&tags=food');
  });

  test('cache policy calculates stale and expiry timestamps', () {
    final fetchedAt = DateTime.utc(2026, 5, 14, 10);
    const policy = AppCachePolicy(
      staleAfter: Duration(minutes: 3),
      expiresAfter: Duration(hours: 1),
    );

    expect(policy.staleAt(fetchedAt), DateTime.utc(2026, 5, 14, 10, 3));
    expect(policy.expiresAt(fetchedAt), DateTime.utc(2026, 5, 14, 11));
  });

  test('user scopes use stable storage ids', () {
    expect(AppCacheUserScope.user('u-1').storageId, 'user:u-1');
    expect(AppCacheUserScope.public.storageId, 'public');
    expect(AppCacheUserScope.guest.storageId, 'guest');
  });
}
