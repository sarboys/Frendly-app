import 'package:big_break_mobile/features/streak/presentation/streak_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('streak screen keeps header and bottom CTA tight',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: StreakScreen()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    final titleTop = tester.getTopLeft(find.text('Геймификация')).dy;
    expect(titleTop, greaterThanOrEqualTo(0));
    expect(titleTop, lessThan(120));

    final buttonBottom =
        tester.getBottomLeft(find.text('Посмотреть перки заведений')).dy;
    final bottomGap = 844 - buttonBottom;
    expect(bottomGap, lessThanOrEqualTo(48));
  });
}
