import 'dart:async';

import 'package:big_break_mobile/app/core/network/chat_socket_client.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_providers.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_edit_screen.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_edit_state.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'evening_test_routes.dart';

void main() {
  testWidgets('edit screen mirrors front edit structure and mini fields', (
    tester,
  ) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      _wrap(
        chat: _chat(phase: MeetupPhase.soon),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактировать вечер'), findsOneWidget);
    expect(find.text('Изменения уйдут в чат участников'), findsOneWidget);
    expect(find.text('ОСНОВНОЕ'), findsOneWidget);
    expect(find.text('КТО МОЖЕТ ВПИСАТЬСЯ'), findsOneWidget);
    expect(find.text('МАРШРУТ · 3 ОСТАНОВКИ'), findsOneWidget);
    expect(find.text('Сохранить и уведомить чат'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Аперитив в Brix Wine'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Аперитив в Brix Wine'));
    await tester.pumpAndSettle();

    expect(find.text('Старт'), findsOneWidget);
    expect(find.text('Конец'), findsOneWidget);
    expect(find.text('Название'), findsWidgets);
    expect(find.text('Место'), findsOneWidget);
    expect(find.text('Адрес'), findsOneWidget);
    expect(find.text('Перк'), findsOneWidget);
    expect(find.text('Билет, ₽'), findsOneWidget);
    expect(find.text('Эмодзи'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
  });

  testWidgets('live edit freezes meta and past route steps', (tester) async {
    _setMobileViewport(tester);

    await tester.pumpWidget(
      _wrap(
        chat: _chat(
          phase: MeetupPhase.live,
          currentStep: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Вечер уже идёт. Можно править только будущие шаги'),
      findsOneWidget,
    );
    expect(find.text('Live · правка только будущих шагов'), findsOneWidget);
    expect(find.text('заморожено'), findsAtLeastNWidgets(2));
    expect(find.text('пройден'), findsNWidgets(2));

    await tester.tap(find.text('Аперитив в Brix Wine'));
    await tester.pumpAndSettle();

    expect(find.text('Старт'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('After-chat в Кафе Заря'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('After-chat в Кафе Заря'));
    await tester.pumpAndSettle();

    expect(find.text('Старт'), findsOneWidget);
  });

  testWidgets('save keeps step place data and notifies meetup chat', (
    tester,
  ) async {
    _setMobileViewport(tester);

    final container = ProviderContainer(
      overrides: [
        eveningRouteOverridesProvider.overrideWith(
          (ref) => {testCozyEveningRoute.id: testCozyEveningRoute},
        ),
        meetupChatsProvider.overrideWith((ref) async => [
              _chat(phase: MeetupPhase.soon),
            ]),
        authBootstrapProvider.overrideWith((ref) async {}),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        backendRepositoryProvider.overrideWith(
          (ref) => _FakeChatThreadRepository(ref: ref, dio: Dio()),
        ),
        chatSocketClientProvider.overrideWith((ref) => _NoopChatSocketClient()),
      ],
    );
    var disposed = false;
    addTearDown(() {
      if (!disposed) {
        container.dispose();
      }
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EveningEditScreen(
            routeId: 'r-cozy-circle',
            chatId: 'chat-route',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Аперитив в Brix Wine'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Аперитив в Brix Wine'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(3), 'Brix обновлён');
    await tester.enterText(find.byType(TextFormField).at(5), 'Покровка 16');
    await tester.enterText(find.byType(TextFormField).at(6), '−20% на бокалы');

    await tester.tap(find.text('Сохранить и уведомить чат'));

    final route =
        container.read(eveningRouteOverridesProvider)['r-cozy-circle']!;
    expect(route.steps.first.venue, 'Brix обновлён');
    expect(route.steps.first.address, 'Покровка 16');
    expect(route.steps.first.perk, '−20% на бокалы');

    final chats = container.read(meetupChatsLocalStateProvider)!;
    expect(chats.single.lastAuthor, 'Frendly');
    expect(chats.single.lastMessage, contains('План обновлён'));

    final systemMessages =
        container.read(chatThreadProvider('chat-route')).valueOrNull;
    expect(systemMessages, isNotNull);
    expect(systemMessages!.single.isSystem, isTrue);
    expect(
      systemMessages.single.text,
      contains('адрес: Покровка 12 → Покровка 16'),
    );

    container.dispose();
    disposed = true;
  });
}

class _FakeChatThreadRepository extends BackendRepository {
  _FakeChatThreadRepository({
    required super.ref,
    required super.dio,
  });

  @override
  Future<PaginatedResponse<Message>> fetchMessages(
    String chatId, {
    String? cursor,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    return const PaginatedResponse(
      items: [],
      nextCursor: null,
      lastEventId: null,
    );
  }
}

class _NoopChatSocketClient extends ChatSocketClient {
  _NoopChatSocketClient()
      : super(
          accessTokenProvider: () async => 'token',
        );

  final _events = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect() async {}

  @override
  void subscribe(String chatId) {}

  @override
  void unsubscribe(String chatId) {}

  @override
  void requestSync({
    required String chatId,
    String? sinceEventId,
  }) {}

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

Widget _wrap({required MeetupChat chat}) {
  return ProviderScope(
    overrides: [
      eveningRouteOverridesProvider.overrideWith(
        (ref) => {testCozyEveningRoute.id: testCozyEveningRoute},
      ),
      meetupChatsProvider.overrideWith((ref) async => [chat]),
    ],
    child: const MaterialApp(
      home: EveningEditScreen(
        routeId: 'r-cozy-circle',
        chatId: 'chat-route',
      ),
    ),
  );
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

MeetupChat _chat({
  required MeetupPhase phase,
  int? currentStep,
}) {
  const route = testCozyEveningRoute;
  return MeetupChat(
    id: 'chat-route',
    eventId: null,
    title: route.title,
    emoji: route.steps.first.emoji,
    time: route.durationLabel,
    lastMessage: 'Собираем людей',
    lastAuthor: 'Frendly',
    lastTime: 'сейчас',
    unread: 0,
    members: const ['Ты', 'Аня'],
    phase: phase,
    currentStep: currentStep,
    totalSteps: route.steps.length,
    routeId: route.id,
    privacy: EveningPrivacy.open,
    maxGuests: 8,
    area: route.area,
  );
}
