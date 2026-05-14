import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_events_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/media_variant.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../test_overrides.dart';

class _ExternalPrewarmCall {
  const _ExternalPrewarmCall({
    required this.urls,
    required this.usage,
    required this.limit,
    required this.concurrency,
  });

  final List<String?> urls;
  final BbExternalEventImageUsage usage;
  final int limit;
  final int concurrency;
}

class _RecordingMediaPrewarmService extends AppMediaPrewarmService {
  final externalCalls = <_ExternalPrewarmCall>[];

  @override
  Future<void> warmExternalEventImages(
    Iterable<String?> urls, {
    required BbExternalEventImageUsage usage,
    int limit = 6,
    int concurrency = 2,
  }) async {
    externalCalls.add(
      _ExternalPrewarmCall(
        urls: urls.toList(growable: false),
        usage: usage,
        limit: limit,
        concurrency: concurrency,
      ),
    );
  }
}

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
      'external-event-image-v4-card-https://cdn.example.com/affiche-0.jpg',
    );

    await _dragUntil(
      tester,
      () => repository.calls.length >= 2,
      step: 420,
    );

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last.cursor, '18');
  });

  testWidgets('affiche screen prewarms first eight card variants', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState(withImageVariants: true);
    final prewarm = _RecordingMediaPrewarmService();

    await tester.pumpWidget(
      _afficheApp(
        repository,
        extraOverrides: [
          appMediaPrewarmServiceProvider.overrideWithValue(prewarm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final call = prewarm.externalCalls.last;
    expect(call.usage, BbExternalEventImageUsage.card);
    expect(call.limit, 8);
    expect(call.concurrency, 2);
    expect(
      call.urls,
      List<String>.generate(
        8,
        (index) => 'https://cdn.example.com/affiche-$index-card.jpg',
      ),
    );
  });

  testWidgets('affiche screen keeps previous page during filter refresh', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState(delayPaidPage: true);

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Афиша 0'), findsOneWidget);

    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-price'),
      'Платные',
    );

    expect(find.text('Афиша 0'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(repository.calls.last.priceMode, 'paid');

    repository.completePaidPage();
    await tester.pumpAndSettle();

    expect(find.text('Платная афиша 0'), findsOneWidget);
    expect(find.text('Афиша 0'), findsNothing);
  });

  testWidgets('affiche screen exposes pull refresh without hiding the page', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Афиша 0'), findsOneWidget);
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

    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
    );
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last.category, 'concert');

    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
    );
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

    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-date'),
      'Завтра',
    );
    await tester.pumpAndSettle();

    expect(repository.calls.last.date, tomorrowIso);

    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
    );
    await tester.pumpAndSettle();

    expect(repository.calls.last.date, tomorrowIso);
    expect(repository.calls.last.category, 'concert');
  });

  testWidgets('affiche category filters keep a single selection', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
    );
    await tester.pumpAndSettle();

    expect(repository.calls.last.category, 'concert');

    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎭 Театр',
    );
    await tester.pumpAndSettle();

    expect(repository.calls.last.category, 'theatre');

    await _dragQuickFilterRowUntilVisible(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
      dragOffset: const Offset(260, 0),
    );
    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
    );

    await _dragQuickFilterRowUntilVisible(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
      dragOffset: const Offset(260, 0),
    );
    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎧 Концерты',
    );
    await tester.pumpAndSettle();

    expect(find.text('Афиша 0'), findsOneWidget);
    expect(find.text('Концертная афиша 0'), findsNothing);
  });

  testWidgets('affiche standup category sends standup filter', (tester) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    await _dragQuickFilterRowUntilVisible(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎤 Стендап',
    );
    await _tapQuickFilterChip(
      tester,
      const Key('affiche-v5-filter-row-category'),
      '🎤 Стендап',
    );
    await tester.pumpAndSettle();

    expect(repository.calls.last.category, 'standup');
  });

  testWidgets('affiche common surface uses only inline quick filters', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PagedAfficheRepositoryState();

    await tester.pumpWidget(_afficheApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('affiche-filter-summary')), findsNothing);
    expect(find.byTooltip('Фильтры'), findsNothing);
    expect(find.byKey(const Key('affiche-v5-filter-sheet')), findsNothing);
    expect(find.byKey(const Key('affiche-v5-filter-row-date')), findsOneWidget);
    expect(
      find.byKey(const Key('affiche-v5-filter-row-price')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('affiche-v5-filter-row-category')),
      findsOneWidget,
    );
    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('Бесплатные'), findsOneWidget);
    expect(find.text('🎭 Театр'), findsOneWidget);
  });
}

Future<void> _tapQuickFilterChip(
  WidgetTester tester,
  Key rowKey,
  String label,
) async {
  final rowFinder = find.byKey(rowKey);
  final labelFinder = find.descendant(
    of: rowFinder,
    matching: find.text(label),
  );
  await tester.ensureVisible(labelFinder);
  await tester.pumpAndSettle();
  await tester.tap(labelFinder);
  await tester.pump();
}

Future<void> _dragQuickFilterRowUntilVisible(
  WidgetTester tester,
  Key rowKey,
  String label, {
  Offset dragOffset = const Offset(-260, 0),
}) async {
  final rowFinder = find.byKey(rowKey);
  for (var i = 0; i < 8; i += 1) {
    final labelFinder = find.descendant(
      of: rowFinder,
      matching: find.text(label),
    );
    if (labelFinder.evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(rowFinder, dragOffset);
    await tester.pumpAndSettle();
  }
}

Future<void> _dragUntil(
  WidgetTester tester,
  bool Function() done, {
  required double step,
  int maxScrolls = 12,
}) async {
  for (var i = 0; i < maxScrolls && !done(); i++) {
    await tester.drag(find.byType(Scrollable).last, Offset(0, -step));
    await tester.pumpAndSettle();
  }
}

Widget _afficheApp(
  _PagedAfficheRepositoryState repository, {
  List<Override> extraOverrides = const [],
}) {
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
      ...extraOverrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _PagedAfficheRepositoryState {
  _PagedAfficheRepositoryState({
    this.delayPaidPage = false,
    this.withImageVariants = false,
  });

  final bool delayPaidPage;
  final bool withImageVariants;
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
    final titlePrefix = switch (category) {
      'concert' => 'Концертная афиша',
      'theatre' => 'Театральная афиша',
      'standup' => 'Стендап афиша',
      _ => 'Афиша',
    };
    return PaginatedResponse<AfficheEvent>(
      items: List.generate(
        limit,
        (index) => _event(
          start + index,
          titlePrefix: titlePrefix,
          withImageVariants: state.withImageVariants,
        ),
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

AfficheEvent _event(
  int index, {
  String titlePrefix = 'Афиша',
  bool withImageVariants = false,
}) {
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
    imageVariants: withImageVariants
        ? {
            'card': MediaVariantData(
              url: 'https://cdn.example.com/affiche-$index-card.jpg',
            ),
          }
        : const {},
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
