import 'package:big_break_mobile/app/core/config/backend_config.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local-first cache is enabled by default for release builds', () {
    expect(BackendConfig.localFirstCacheDefaultEnabled, isTrue);
    expect(BackendConfig.localFirstCacheEnabled, isTrue);
  });

  test('disabled local-first flag keeps cache providers off', () {
    final container = ProviderContainer(
      overrides: [
        localFirstCacheEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appLocalDatabaseProvider), isNull);
    expect(container.read(appLocalCacheStoreProvider), isNull);
    expect(container.read(localFirstRepositoryProvider), isNull);
  });

  test('database open failure disables local cache for the runtime', () async {
    final container = ProviderContainer(
      overrides: [
        localFirstCacheEnabledProvider.overrideWithValue(true),
        appLocalDatabaseFactoryProvider.overrideWithValue(
          () => throw StateError('db open failed'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appLocalDatabaseProvider), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appLocalCacheRuntimeDisabledProvider), isTrue);
    expect(container.read(localFirstRepositoryProvider), isNull);
  });
}
