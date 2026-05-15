import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BbV5LucideIcon renders as a centered icon glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: BbV5LucideIcon(
                LucideIcons.plus,
                size: 17,
                weight: 400,
              ),
            ),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));

    expect(icon.size, 17);
    expect(icon.icon?.codePoint, LucideIcons.plus.codePoint);
  });
}
