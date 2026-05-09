import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/tonight/presentation/v5_search_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
