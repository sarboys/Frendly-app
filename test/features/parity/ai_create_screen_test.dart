import 'package:big_break_mobile/app/app.dart';
import 'package:big_break_mobile/features/ai_create/presentation/ai_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

Widget _wrapPhoneViewport(Widget child) {
  return MaterialApp(
    home: AppPhoneViewportMediaQuery(
      statusBarHeight: 44,
      child: child,
    ),
  );
}

void main() {
  testWidgets('ai create uses compact v5 mood tiles', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const AiCreateScreen()));
    await tester.pumpAndSettle();

    final wineTile = find.ancestor(
      of: find.text('Вино'),
      matching: find.byType(InkWell),
    );

    expect(wineTile, findsOneWidget);
    expect(tester.getSize(wineTile).height, lessThanOrEqualTo(76));
  });

  testWidgets('ai create scroll viewport fills the phone window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrapPhoneViewport(const AiCreateScreen()));
    await tester.pumpAndSettle();

    final scrollRect = tester.getRect(find.byType(CustomScrollView));

    expect(scrollRect.top, 44);
    expect(scrollRect.bottom, 820);
  });
}
