import 'package:big_break_mobile/features/perks/presentation/perks_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import '../../../test_overrides.dart';

class _FakePromoRepository extends BackendRepository {
  _FakePromoRepository({
    required super.ref,
    required super.dio,
  });

  String? lastCity;

  @override
  Future<List<BackendPlacePromoListItem>> fetchPlacePromos({
    String city = 'Москва',
    double? latitude,
    double? longitude,
    int limit = 80,
    String? category,
    CancelToken? cancelToken,
  }) async {
    lastCity = city;
    return const [
      BackendPlacePromoListItem(
        id: 'promo-spb-1',
        title: 'Скидка на сет',
        description: 'Для компании от 3 человек',
        city: 'Санкт-Петербург',
        venueName: 'Бар СПБ',
        placeName: 'Бар СПБ',
        address: 'Невский 1',
        placeCategory: 'bar',
        placeKind: 'bar',
        provider: 'ТоМесто',
        distanceKm: 1.2,
      ),
    ];
  }
}

void main() {
  testWidgets('perks screen shows Tomesto promo for the user city', (
    tester,
  ) async {
    _FakePromoRepository? repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          manualLocationProvider.overrideWith((ref) {
            return ManualLocationController(null)
              ..setLocation(
                const ManualLocation(
                  label: 'Санкт-Петербург',
                  city: 'Санкт-Петербург',
                  latitude: 59.94,
                  longitude: 30.32,
                ),
              );
          }),
          backendRepositoryProvider.overrideWith((ref) {
            repository = _FakePromoRepository(ref: ref, dio: Dio());
            return repository!;
          }),
        ],
        child: const MaterialApp(
          home: PerksScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Промо'), findsOneWidget);
    expect(find.text('Перки'), findsNothing);
    expect(find.text('Перков пока нет.'), findsNothing);
    expect(find.text('Скидка на сет'), findsOneWidget);
    expect(find.text('БАР СПБ'), findsOneWidget);
    expect(find.text('Бары'), findsWidgets);
    expect(repository?.lastCity, 'Санкт-Петербург');
  });
}
