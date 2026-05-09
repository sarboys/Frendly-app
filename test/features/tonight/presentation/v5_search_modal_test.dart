import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/tonight/presentation/v5_search_modal.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/search_results.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('v5 search modal renders backend meetup results', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    _SearchBackendRepository? repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          backendRepositoryProvider.overrideWith((ref) {
            repository = _SearchBackendRepository(
              ref: ref,
              results: const GroupedSearchResults(
                meetups: [
                  Event(
                    id: 'event-1',
                    title: 'Кофе сегодня',
                    emoji: '☕',
                    time: 'Сегодня · 18:00',
                    place: 'Brix',
                    distance: '1 км',
                    attendees: [],
                    going: 2,
                    capacity: 6,
                    vibe: 'Спокойно',
                    tone: EventTone.warm,
                    joined: false,
                  ),
                ],
                routes: [],
                affiche: [],
              ),
            );
            return repository!;
          }),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showV5SearchModal(context),
                child: const Text('Открыть поиск'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть поиск'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'кофе');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();

    expect(repository?.lastQuery, 'кофе');
    expect(find.text('Кофе сегодня'), findsOneWidget);
    expect(find.text('Brix'), findsOneWidget);
    expect(find.text('Ничего не нашли'), findsNothing);
  });

  testWidgets('v5 search modal sends manual city to backend search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    _SearchBackendRepository? repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          backendRepositoryProvider.overrideWith((ref) {
            repository = _SearchBackendRepository(
              ref: ref,
              results: const GroupedSearchResults(
                meetups: [],
                routes: [],
                affiche: [],
              ),
            );
            return repository!;
          }),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showV5SearchModal(context),
                child: const Text('Открыть поиск'),
              );
            },
          ),
        ),
      ),
    );

    final buttonContext = tester.element(find.text('Открыть поиск'));
    ProviderScope.containerOf(buttonContext)
        .read(
          manualLocationProvider.notifier,
        )
        .setLocation(
          const ManualLocation(
            label: 'Санкт-Петербург',
            city: 'Санкт-Петербург',
            latitude: 59.9386,
            longitude: 30.3141,
          ),
        );

    await tester.tap(find.text('Открыть поиск'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'кофе');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();

    expect(repository?.lastQuery, 'кофе');
    expect(repository?.lastCity, 'Санкт-Петербург');
    expect(find.text('Ничего не нашли'), findsOneWidget);
  });

  testWidgets('v5 search modal does not render static fake results', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) {
                    return TextButton(
                      onPressed: () => showV5SearchModal(context),
                      child: const Text('Открыть поиск'),
                    );
                  },
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoute.tonight.path,
          name: AppRoute.tonight.name,
          builder: (context, state) => const Scaffold(body: Text('Tonight')),
        ),
        GoRoute(
          path: AppRoute.communities.path,
          name: AppRoute.communities.name,
          builder: (context, state) => const Scaffold(body: Text('Clubs')),
        ),
        GoRoute(
          path: AppRoute.dating.path,
          name: AppRoute.dating.name,
          builder: (context, state) => const Scaffold(body: Text('Dating')),
        ),
        GoRoute(
          path: AppRoute.eveningRoutes.path,
          name: AppRoute.eveningRoutes.name,
          builder: (context, state) => const Scaffold(body: Text('Routes')),
        ),
        GoRoute(
          path: AppRoute.affiche.path,
          name: AppRoute.affiche.name,
          builder: (context, state) => const Scaffold(body: Text('Affiche')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Открыть поиск'));
    await tester.pumpAndSettle();

    expect(find.text('Brix · вино после работы'), findsNothing);
    expect(find.text('Аня, 26'), findsNothing);
    expect(find.text('Тверская в огнях'), findsNothing);
    expect(find.text('Ничего не нашли'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
  });

  testWidgets('v5 search modal clips the horizontal filter rail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showV5SearchModal(context),
                child: const Text('Открыть поиск'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть поиск'));
    await tester.pumpAndSettle();

    final filterRail = tester
        .widgetList<ListView>(find.byType(ListView))
        .singleWhere((list) => list.scrollDirection == Axis.horizontal);

    expect(filterRail.clipBehavior, Clip.hardEdge);
  });
}

class _SearchBackendRepository extends BackendRepository {
  _SearchBackendRepository({
    required super.ref,
    required this.results,
  }) : super(dio: Dio());

  final GroupedSearchResults results;
  String? lastQuery;
  String? lastCity;

  @override
  Future<GroupedSearchResults> fetchGroupedSearch({
    required String q,
    String city = 'Москва',
    int limit = 5,
    CancelToken? cancelToken,
  }) async {
    lastQuery = q;
    lastCity = city;
    return results;
  }
}
