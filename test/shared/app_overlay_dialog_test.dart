import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/app_overlay/app_overlay_dialog.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  testWidgets('dismissible overlay shows close action', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppOverlayDialog(
          overlay: const AppOverlay(
            id: 'campaign-1',
            source: 'campaign',
            kind: 'announcement',
            title: 'Новость',
            body: 'Текст для пользователя',
            dismissible: true,
            cta: null,
          ),
          onDismiss: () => dismissed = true,
          onCta: () {},
        ),
      ),
    );

    expect(find.text('Новость'), findsOneWidget);
    expect(find.text('Текст для пользователя'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Закрыть'));
    expect(dismissed, true);
  });

  testWidgets('blocking overlay hides close action and shows CTA',
      (tester) async {
    var ctaPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppOverlayDialog(
          overlay: const AppOverlay(
            id: 'policy-ios',
            source: 'version_policy',
            kind: 'force_update',
            title: 'Обновите Frendly',
            body: 'Старая версия больше не поддерживается.',
            dismissible: false,
            cta: AppOverlayCta(
              label: 'Обновить',
              action: 'store_update',
              value: 'https://apps.apple.com/app/frendly',
            ),
          ),
          onDismiss: () {},
          onCta: () => ctaPressed = true,
        ),
      ),
    );

    expect(find.bySemanticsLabel('Закрыть'), findsNothing);
    expect(find.text('Обновить'), findsOneWidget);

    await tester.tap(find.text('Обновить'));
    expect(ctaPressed, true);
  });
}
