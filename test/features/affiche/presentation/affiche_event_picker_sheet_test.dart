import 'package:big_break_mobile/features/affiche/presentation/affiche_event_picker_sheet.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_overrides.dart';

void main() {
  testWidgets('affiche picker opens the common v5 browser and returns event', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final repository = _PickerAfficheRepositoryState();
    AfficheEvent? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          backendRepositoryProvider.overrideWith(
            (ref) => _PickerAfficheRepository(ref: ref, state: repository),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      selected = await showAfficheEventPickerSheet(context);
                    },
                    child: const Text('open picker'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open picker'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('affiche-v5-browser')), findsOneWidget);
    expect(find.byKey(const Key('affiche-v5-filter-row-date')), findsOneWidget);
    expect(
      find.byKey(const Key('affiche-v5-filter-row-price')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('affiche-v5-filter-row-category')),
      findsOneWidget,
    );

    await tester.tap(find.text('Афиша 0'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'affiche-0');
  });
}

class _PickerAfficheRepositoryState {
  final calls = <_AfficheCall>[];
}

class _PickerAfficheRepository extends BackendRepository {
  _PickerAfficheRepository({
    required super.ref,
    required this.state,
  }) : super(dio: Dio());

  final _PickerAfficheRepositoryState state;

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

    return PaginatedResponse<AfficheEvent>(
      items: List.generate(limit, _event),
      nextCursor: null,
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

AfficheEvent _event(int index) {
  return AfficheEvent(
    id: 'affiche-$index',
    title: 'Афиша $index',
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
