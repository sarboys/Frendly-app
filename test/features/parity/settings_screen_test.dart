import 'package:big_break_mobile/features/settings/presentation/settings_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/user_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

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
  testWidgets('settings matches v5 user-facing groups', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Управление'), findsOneWidget);
    expect(find.text('Настройки аккаунта'), findsOneWidget);
    expect(find.text('Никита М'), findsOneWidget);
    expect(find.text('Frendly+'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Верификация'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Вечера и поиск'), findsOneWidget);
    expect(find.text('Радар рядом'), findsOneWidget);
    expect(find.text('AI compass'), findsOneWidget);
    expect(find.text('Авто-вечер'), findsOneWidget);
    expect(find.text('After Dark'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Удаление аккаунта'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Опасная зона'), findsOneWidget);
    expect(find.text('Поддержка и условия'), findsOneWidget);
    expect(find.text('Удаление аккаунта'), findsOneWidget);
    expect(find.text('Frendly+ доступ'), findsNothing);
    expect(find.text('After Dark доступ'), findsNothing);
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
    expect(find.text('Вечера и поиск'), findsOneWidget);
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

    await tester.pumpWidget(
      ProviderScope(
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
  });

  testWidgets('settings hides internal testing access controls',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Frendly+ доступ'), findsNothing);
    expect(find.text('After Dark доступ'), findsNothing);
  });
}
