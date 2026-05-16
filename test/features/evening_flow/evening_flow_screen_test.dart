import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/evening_flow/presentation/evening_flow_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_overrides.dart';

void main() {
  testWidgets('evening flow shows participant hub without stage tabs',
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

    expect(find.text('Винный вечер на крыше'), findsWidgets);
    expect(find.text('Открыть чат'), findsOneWidget);
    expect(find.text('Чек-ин'), findsNothing);
    expect(find.text('Live'), findsNothing);
    expect(find.text('After'), findsNothing);
    expect(find.text('Итог'), findsNothing);
    expect(find.text('Финал'), findsNothing);
    expect(find.text('Начать чек-ин'), findsNothing);
  });

  testWidgets('evening flow opens meetup chat from participant hub',
      (tester) async {
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
          path: AppRoute.meetupChat.path,
          name: AppRoute.meetupChat.name,
          builder: (context, state) => const Scaffold(
            body: Text('chat-opened'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventDetailProvider.overrideWith(
            (ref, eventId) async => _eventDetail,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Открыть чат'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть чат'));
    await tester.pumpAndSettle();

    expect(find.text('chat-opened'), findsOneWidget);
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
