import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('glass bottom bar shrink wraps in Scaffold bottomNavigationBar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BbV5GlassBottomBar(
            child: SizedBox(
              key: Key('glass-child'),
              height: 60,
              width: 320,
            ),
          ),
          body: SizedBox.expand(),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(const Key('glass-child')));

    expect(rect.center.dy, greaterThan(760));
    expect(rect.bottom, lessThanOrEqualTo(828));
  });
}
