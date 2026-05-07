import 'package:big_break_mobile/features/evening_plan/presentation/evening_edit_screen.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('Основное'), findsOneWidget);
    expect(find.text('Кто может вписаться'), findsOneWidget);
    expect(find.text('Маршрут'), findsOneWidget);
    expect(find.text('Сохранить и уведомить чат'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Аперитив в Brix Wine'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Аперитив в Brix Wine'));
    await tester.pumpAndSettle();

    expect(find.text('СТАРТ'), findsOneWidget);
    expect(find.text('КОНЕЦ'), findsOneWidget);
    expect(find.text('НАЗВАНИЕ'), findsOneWidget);
    expect(find.text('МЕСТО'), findsOneWidget);
    expect(find.text('АДРЕС'), findsOneWidget);
    expect(find.text('ПЕРК'), findsOneWidget);
    expect(find.text('БИЛЕТ, ₽'), findsOneWidget);
    expect(find.text('ЭМОДЗИ'), findsOneWidget);
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

    expect(find.text('СТАРТ'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('After-chat в Кафе Заря'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('After-chat в Кафе Заря'));
    await tester.pumpAndSettle();

    expect(find.text('СТАРТ'), findsOneWidget);
  });
}

Widget _wrap({required MeetupChat chat}) {
  return ProviderScope(
    overrides: [
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
  final route = eveningRoutes.first;
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
