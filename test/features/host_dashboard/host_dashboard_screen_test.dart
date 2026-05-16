import 'package:big_break_mobile/features/host_dashboard/presentation/host_dashboard_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/host_dashboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

void main() {
  testWidgets('host finish sheet sends only selected attendee ids',
      (tester) async {
    late _RecordingHostRepository repository;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          backendRepositoryProvider.overrideWith((ref) {
            repository = _RecordingHostRepository(ref);
            return repository;
          }),
          hostDashboardProvider.overrideWith((ref) async => _dashboard),
          hostEventProvider.overrideWith((ref, eventId) async => _hostEvent),
        ],
        child: const MaterialApp(home: HostDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -620));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить вечер'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Аня К'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить вечер').last);
    await tester.pumpAndSettle();

    expect(repository.finishedEventId, 'event-finished');
    expect(repository.attendedUserIds, ['user-anya']);
  });
}

const _dashboard = HostDashboardData(
  stats: HostDashboardStats(
    meetupsCount: 1,
    rating: 4.9,
    fillRate: 50,
  ),
  pendingRequestsCount: 0,
  requests: [],
  events: [_event],
);

const _hostEvent = HostEventData(
  event: _event,
  chatId: 'chat-1',
  liveStatus: EventLiveStatus.idle,
  requests: [],
  attendees: [
    HostEventAttendee(
      userId: 'user-me',
      displayName: 'Никита М',
      avatarUrl: null,
      verified: true,
      online: true,
      attendanceStatus: EventAttendanceStatus.checkedIn,
      checkedInAt: null,
    ),
    HostEventAttendee(
      userId: 'user-anya',
      displayName: 'Аня К',
      avatarUrl: null,
      verified: true,
      online: false,
      attendanceStatus: EventAttendanceStatus.notCheckedIn,
      checkedInAt: null,
    ),
  ],
);

const _event = Event(
  id: 'event-finished',
  title: 'Винный вечер на крыше',
  emoji: '🍷',
  time: 'Сегодня · 20:00',
  startsAtIso: '2099-04-19T20:00:00.000Z',
  place: 'Brix Wine',
  distance: '1.2 км',
  attendees: ['Никита М', 'Аня К'],
  going: 2,
  capacity: 8,
  vibe: 'Спокойно',
  tone: EventTone.evening,
  joined: true,
  isHost: true,
  liveStatus: EventLiveStatus.live,
);

class _RecordingHostRepository extends BackendRepository {
  _RecordingHostRepository(Ref ref) : super(ref: ref, dio: Dio());

  String? finishedEventId;
  List<String>? attendedUserIds;

  @override
  Future<void> finishLiveMeetup(
    String eventId, {
    List<String> attendedUserIds = const [],
  }) async {
    finishedEventId = eventId;
    this.attendedUserIds = attendedUserIds;
  }
}
