import 'dart:async';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_events_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../test_overrides.dart';

void main() {
  testWidgets('affiche screen builds a lazy page and loads the next page', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.limit, 18);
    expect(repository.calls.single.cursor, isNull);
    expect(find.text('Афиша 0'), findsOneWidget);
    expect(find.text('Афиша 17'), findsNothing);
    final builtImages = find.byType(CachedNetworkImage).evaluate();
    expect(builtImages.length, lessThan(repository.calls.single.limit));
    final firstImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(firstImage.memCacheWidth, 900);
    expect(
      firstImage.cacheKey,
      'external-event-image-v3-card-https://cdn.example.com/affiche-0.jpg',
    );

    await tester.scrollUntilVisible(
      find.text('Афиша 16'),
      420,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last.cursor, '18');
  });

  testWidgets('affiche screen keeps previous page during filter refresh', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState(delayPaidPage: true);

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Афиша 0'), findsOneWidget);

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Платные'));
    await tester.tap(find.text('Показать события'));
    await tester.pump();

    expect(find.text('Афиша 0'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(repository.calls.last.priceMode, 'paid');

    repository.completePaidPage();
    await tester.pumpAndSettle();

    expect(find.text('Платная афиша 0'), findsOneWidget);
    expect(find.text('Афиша 0'), findsNothing);
  });

  testWidgets('affiche screen reuses recently loaded filter pages', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(1));
    expect(repository.calls.last.category, isNull);

    await tester.tap(find.text('🎧 Концерты'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last.category, 'concert');

    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(find.text('Афиша 0'), findsOneWidget);
  });

  testWidgets('affiche screen sends date and category filters', (tester) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowIso =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завтра'));
    await tester.tap(find.text('Показать события'));
    await tester.pumpAndSettle();

    expect(repository.calls.last.date, tomorrowIso);

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Концерты'));
    await tester.tap(find.text('Показать события'));
    await tester.pumpAndSettle();

    expect(repository.calls.last.date, tomorrowIso);
    expect(repository.calls.last.category, 'concert');
  });

  testWidgets('affiche keeps filter chrome compact until sheet opens', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('affiche-filter-summary')), findsOneWidget);
    expect(find.byTooltip('Фильтры'), findsOneWidget);
    expect(find.text('Завтра'), findsNothing);
    expect(find.text('Бесплатные'), findsNothing);
    expect(find.text('Стендап'), findsNothing);

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();

    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('Бесплатные'), findsOneWidget);
    expect(find.text('Стендап'), findsOneWidget);
  });

  testWidgets('affiche filter sheet exposes range, time, category and radius', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('Выходные'), findsOneWidget);
    expect(find.text('Неделя'), findsOneWidget);
    expect(find.text('Время суток'), findsOneWidget);
    expect(find.text('Вечер'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Радиус · 30 км'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Радиус · 30 км'), findsOneWidget);
  });
}

Widget _afficheApp(_PagedAfficheRepositoryState repository) {
  final router = GoRouter(
    initialLocation: AppRoute.affiche.path,
    routes: [
      GoRoute(
        path: AppRoute.affiche.path,
        name: AppRoute.affiche.name,
        builder: (context, state) => const AfficheEventsScreen(),
      ),
      GoRoute(
        path: AppRoute.afficheEvent.path,
        name: AppRoute.afficheEvent.name,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('detail:${state.pathParameters['eventId']}'),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      backendRepositoryProvider.overrideWith(
        (ref) => _PagedAfficheRepository(ref: ref, state: repository),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _PagedAfficheRepositoryState {
  _PagedAfficheRepositoryState({
    this.delayPaidPage = false,
  });

  final bool delayPaidPage;
  final calls = <_AfficheCall>[];
  Completer<PaginatedResponse<AfficheEvent>>? _paidCompleter;

  void completePaidPage() {
    _paidCompleter?.complete(
      PaginatedResponse<AfficheEvent>(
        items: List.generate(
          4,
          (index) => _event(index, titlePrefix: 'Платная афиша'),
        ),
        nextCursor: null,
      ),
    );
  }
}

class _PagedAfficheRepository extends BackendRepository {
  _PagedAfficheRepository({
    required super.ref,
    required this.state,
  }) : super(dio: Dio());

  final _PagedAfficheRepositoryState state;

  @override
  Future<PaginatedResponse<AfficheEvent>> fetchAfficheEvents({
    String? city,
    String? q,
    String? date,
    String? priceMode,
    String? source,
    String? category,
    bool? featured,
    String? cursor,
    int limit = 24,
    CancelToken? cancelToken,
  }) async {
    state.calls.add(
      _AfficheCall(
        cursor: cursor,
        date: date,
        limit: limit,
        priceMode: priceMode,
        category: category,
      ),
    );

    if (state.delayPaidPage && priceMode == 'paid') {
      state._paidCompleter ??= Completer<PaginatedResponse<AfficheEvent>>();
      return state._paidCompleter!.future;
    }

    final start = int.tryParse(cursor ?? '') ?? 0;
    return PaginatedResponse<AfficheEvent>(
      items: List.generate(
        limit,
        (index) => _event(start + index),
      ),
      nextCursor: cursor == null ? '$limit' : null,
    );
  }
}

class _AfficheCall {
  const _AfficheCall({
    required this.cursor,
    required this.date,
    required this.limit,
    required this.priceMode,
    required this.category,
  });

  final String? cursor;
  final String? date;
  final int limit;
  final String? priceMode;
  final String? category;
}

AfficheEvent _event(int index, {String titlePrefix = 'Афиша'}) {
  return AfficheEvent(
    id: 'affiche-$index',
    title: '$titlePrefix $index',
    description: null,
    city: 'Москва',
    venue: 'Сцена $index',
    address: 'Покровка $index',
    latitude: null,
    longitude: null,
    startsAt: DateTime(2026, 5, 10, 19),
    endsAt: null,
    dateLabel: '10 мая',
    timeLabel: '19:00',
    category: 'concert',
    priceFrom: 1200,
    priceMode: AffichePriceMode.paid,
    currency: 'RUB',
    imageUrl: 'https://cdn.example.com/affiche-$index.jpg',
    provider: 'Ticketland',
    sourceCode: 'advcake_ticketland',
    actionUrl: 'https://tickets.example.com/$index',
    actionKind: 'affiliate_ticket',
    isAffiliate: true,
    tags: const [],
  );
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
