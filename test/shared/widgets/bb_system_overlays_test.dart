import 'package:big_break_mobile/shared/widgets/bb_system_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(AnnouncementPayload? announcement) {
  return ProviderScope(
    overrides: [
      announcementProvider.overrideWith((ref) => announcement),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: BbSystemOverlays(
          child: SizedBox.expand(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('announcement banner renders info content and CTA',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AnnouncementPayload(
          id: 'info',
          severity: AnnouncementSeverity.info,
          title: 'Доступно обновление 2.4',
          message: 'Новый ивнинг-билдер и быстрые отклики.',
          ctaLabel: 'Обновить',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ОБЪЯВЛЕНИЕ'), findsOneWidget);
    expect(find.text('Доступно обновление 2.4'), findsOneWidget);
    expect(find.text('Новый ивнинг-билдер и быстрые отклики.'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
    expect(find.byIcon(LucideIcons.megaphone), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrow_right), findsOneWidget);
  });

  testWidgets('critical force announcement cannot be dismissed',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AnnouncementPayload(
          id: 'critical',
          severity: AnnouncementSeverity.critical,
          title: 'Нужно обновить приложение',
          message: 'Старая версия скоро перестанет работать.',
          ctaLabel: 'Обновить',
          force: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ОБНОВЛЕНИЕ'), findsOneWidget);
    expect(find.byIcon(LucideIcons.download), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNothing);
  });

  testWidgets('warning announcement can be dismissed', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AnnouncementPayload(
          id: 'warning',
          severity: AnnouncementSeverity.warning,
          title: 'Технические работы',
          message: 'Чаты могут обновляться медленнее обычного.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ВАЖНО'), findsOneWidget);
    expect(find.byIcon(LucideIcons.triangle_alert), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();

    expect(find.text('Технические работы'), findsNothing);
  });
}
