import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/evening_flow/presentation/evening_flow_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/after_party_state.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_overrides.dart';

void main() {
  testWidgets('evening flow renders v5 stage tabs and route stage',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildTestOverrides(),
        child: const MaterialApp(
          home: EveningFlowScreen(eventId: 'e1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Маршрут'), findsWidgets);
    expect(find.text('Чек-ин'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.text('Итог'), findsOneWidget);
    expect(find.text('Финал'), findsOneWidget);
    expect(find.text('Винный вечер на крыше'), findsWidgets);
    expect(find.text('Начать чек-ин'), findsOneWidget);
  });

  testWidgets('evening flow keeps saved after-party feedback on done',
      (tester) async {
    late _RecordingEveningFlowRepository repository;
    final router = GoRouter(
      initialLocation: '/evening/e1',
      routes: [
        GoRoute(
          path: AppRoute.eveningFlow.path,
          name: AppRoute.eveningFlow.name,
          builder: (context, state) => EveningFlowScreen(
            eventId: state.pathParameters['eventId']!,
          ),
        ),
        GoRoute(
          path: AppRoute.tonight.path,
          name: AppRoute.tonight.name,
          builder: (context, state) => const Scaffold(
            body: Text('tonight'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWith((ref) {
            repository = _RecordingEveningFlowRepository(ref);
            return repository;
          }),
          eventDetailProvider.overrideWith(
            (ref, eventId) async => _eventDetail,
          ),
          afterPartyProvider.overrideWith(
            (ref, eventId) async => _afterPartyWithSavedFeedback,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      const Offset(-420, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Финал'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(repository.savedVibe, 'warm');
    expect(repository.savedHostRating, 4);
    expect(repository.savedFavoriteUserIds, ['user-anya']);
    expect(find.text('tonight'), findsOneWidget);
  });
}

const _eventDetail = EventDetail(
  id: 'e1',
  title: 'Винный вечер на крыше',
  emoji: '🍷',
  time: 'Сегодня · 20:00',
  place: 'Brix Wine, Покровка 12',
  distance: '1.2 км',
  vibe: 'Спокойно',
  description: 'Камерный вечер на крыше.',
  hostNote: 'Знакомимся за бокалом, без спешки.',
  joined: true,
  partnerName: 'Brix Wine',
  partnerOffer: null,
  capacity: 10,
  going: 6,
  chatId: 'mc1',
  host: EventHost(
    id: 'user-anya',
    displayName: 'Аня К',
    verified: true,
    rating: 4.9,
    meetupCount: 23,
    avatarUrl: null,
  ),
  attendees: [
    EventAttendee(
      id: 'user-me',
      displayName: 'Никита М',
      avatarUrl: null,
    ),
  ],
);

const _afterPartyWithSavedFeedback = AfterPartyData(
  eventId: 'e1',
  title: 'Винный вечер на крыше',
  emoji: '🍷',
  saved: true,
  vibe: 'warm',
  hostRating: 4,
  note: null,
  favoriteUserIds: ['user-anya'],
  attendees: [
    AfterPartyAttendee(
      userId: 'user-anya',
      displayName: 'Аня К',
      avatarUrl: null,
    ),
  ],
);

class _RecordingEveningFlowRepository extends BackendRepository {
  _RecordingEveningFlowRepository(Ref ref) : super(ref: ref, dio: Dio());

  String? savedVibe;
  int? savedHostRating;
  List<String>? savedFavoriteUserIds;

  @override
  Future<void> saveAfterParty(
    String eventId, {
    required String vibe,
    required int hostRating,
    required List<String> favoriteUserIds,
    String? note,
  }) async {
    savedVibe = vibe;
    savedHostRating = hostRating;
    savedFavoriteUserIds = favoriteUserIds;
  }
}
