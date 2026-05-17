import 'dart:async';

import 'package:big_break_mobile/features/settings/presentation/settings_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/user_settings.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_overrides.dart';

class _RecordingBackendRepository extends BackendRepository {
  _RecordingBackendRepository({
    required super.ref,
    this.onUpdate,
  }) : super(dio: Dio());

  final void Function(UserSettingsData settings)? onUpdate;

  @override
  Future<UserSettingsData> updateSettings(UserSettingsData settings) async {
    onUpdate?.call(settings);
    return settings;
  }
}

Widget _wrap() {
  return ProviderScope(
    overrides: buildTestOverrides(),
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('settings removes noisy profile settings rows', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Управление'), findsOneWidget);
    expect(find.text('Настройки аккаунта'), findsOneWidget);
    expect(find.text('Никита М'), findsOneWidget);
    expect(find.text('Frendly+'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Верификация'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Вечера и поиск'), findsNothing);
    expect(find.text('Радар рядом'), findsNothing);
    expect(find.text('AI compass'), findsNothing);
    expect(find.text('Авто-вечер'), findsNothing);
    expect(find.text('After Dark'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('Доступ к контактам'), findsNothing);
    expect(find.text('Приглашения'), findsNothing);
    expect(find.text('Чаты'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Удаление аккаунта'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Внешний вид'), findsNothing);
    expect(find.text('Тёмная тема'), findsNothing);
    expect(find.text('Опасная зона'), findsOneWidget);
    expect(find.text('Поддержка и условия'), findsOneWidget);
    expect(find.text('Удаление аккаунта'), findsOneWidget);
    expect(find.text('Frendly+ доступ'), findsNothing);
    expect(find.text('After Dark доступ'), findsNothing);
  });

  testWidgets('settings active toggles use v5 accent color', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final animatedContainerColors = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color);

    expect(animatedContainerColors, contains(BbV5Colors.accent));
  });

  testWidgets('settings screen keeps content visible while request is loading',
      (tester) async {
    final completer = Completer<UserSettingsData>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...buildTestOverrides(),
          settingsProvider.overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Настройки аккаунта'), findsOneWidget);
    expect(find.text('Приватность'), findsOneWidget);
  });

  testWidgets('settings language row opens selector sheet', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Язык'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Язык'));
    await tester.pumpAndSettle();

    expect(find.text('Выбери язык'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Выбери язык'), findsNothing);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('settings notification row can save from row tap',
      (tester) async {
    UserSettingsData? capturedSettings;
    final container = ProviderContainer(
      overrides: [
        ...buildTestOverrides(),
        backendRepositoryProvider.overrideWith(
          (ref) => _RecordingBackendRepository(
            ref: ref,
            onUpdate: (settings) {
              capturedSettings = settings;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Push-уведомления'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Push-уведомления'));
    await tester.pump();

    expect(capturedSettings, isNotNull);
    expect(capturedSettings!.allowPush, isFalse);
    expect(container.read(settingsLocalStateProvider)!.allowPush, isFalse);
  });

  testWidgets('settings hides internal testing access controls',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Frendly+ доступ'), findsNothing);
    expect(find.text('After Dark доступ'), findsNothing);
  });
}
