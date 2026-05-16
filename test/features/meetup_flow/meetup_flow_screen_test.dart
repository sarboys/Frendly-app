import 'package:big_break_mobile/features/host_dashboard/presentation/host_dashboard_screen.dart';
import 'package:big_break_mobile/features/join_request/presentation/join_request_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

class _RecordingJoinRequestRepository extends BackendRepository {
  _RecordingJoinRequestRepository({
    required super.ref,
    required super.dio,
  });

  int joinRequestCalls = 0;

  @override
  Future<void> createJoinRequest(String eventId, {required String note}) async {
    joinRequestCalls += 1;
  }
}

Widget _wrap(Widget child, {List<Override> extraOverrides = const []}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      ...extraOverrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('join request screen renders submit CTA', (tester) async {
    await tester.pumpWidget(_wrap(const JoinRequestScreen(eventId: 'e5')));
    await tester.pumpAndSettle();

    expect(find.text('Отправить заявку'), findsOneWidget);
    expect(find.byType(BbV5Scaffold), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Обычно отвечают'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Обычно отвечают'), findsOneWidget);
  });

  testWidgets('join request screen blocks form when requirements are missing',
      (tester) async {
    _RecordingJoinRequestRepository? repository;
    await tester.pumpWidget(
      _wrap(
        const JoinRequestScreen(eventId: 'e-locked'),
        extraOverrides: [
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-locked',
              title: 'Закрытый ужин',
              emoji: '🍷',
              time: 'Сегодня · 20:00',
              place: 'Brix Wine',
              distance: '1.2 км',
              vibe: 'Спокойно',
              description: 'Только для гостей с доступом.',
              hostNote: null,
              joined: false,
              partnerName: null,
              partnerOffer: null,
              capacity: 8,
              going: 2,
              chatId: null,
              requiresVerification: true,
              requiresFrendlyPlus: true,
              entryRequirements: EventEntryRequirements(
                canJoin: false,
                missing: [
                  EventEntryRequirement.verification,
                  EventEntryRequirement.frendlyPlus,
                ],
              ),
              host: EventHost(
                id: 'host-1',
                displayName: 'Мира',
                verified: true,
                rating: 4.9,
                meetupCount: 10,
                avatarUrl: null,
              ),
              attendees: [],
            );
          }),
          backendRepositoryProvider.overrideWith((ref) {
            repository = _RecordingJoinRequestRepository(ref: ref, dio: Dio());
            return repository!;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пройти верификацию'), findsOneWidget);
    expect(find.text('Оформить Frendly+'), findsOneWidget);
    expect(find.text('Сообщение хосту'), findsNothing);
    expect(find.text('Отправить заявку'), findsNothing);
    expect(repository?.joinRequestCalls ?? 0, 0);
  });

  testWidgets('host dashboard renders title', (tester) async {
    await tester.pumpWidget(_wrap(const HostDashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Хост-панель'), findsOneWidget);
    expect(find.text('Этот месяц'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Предстоящие'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Предстоящие'), findsOneWidget);
  });

  testWidgets('host dashboard renders past tab from startsAtIso',
      (tester) async {
    await tester.pumpWidget(_wrap(const HostDashboardScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Прошедшие'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Прошедшие'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Винный вечер на крыше'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Винный вечер на крыше'), findsOneWidget);
  });
}
