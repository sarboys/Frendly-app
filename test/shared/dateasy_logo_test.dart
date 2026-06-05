import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/widgets/dateasy_logo.dart';

void main() {
  testWidgets('logo shows wordmark without year label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DateasyLogo(size: DateasyLogoSize.md),
        ),
      ),
    );

    expect(find.text('frendly'), findsOneWidget);
    expect(find.text('EST. MMXXVI'), findsNothing);
  });

  testWidgets('logo mark uses app icon rounded corners', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DateasyLogoMark(size: 64),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    final borderRadius = clip.borderRadius as BorderRadius;

    expect(borderRadius.topLeft.x, greaterThan(0));
    expect(borderRadius.topRight.x, borderRadius.topLeft.x);
  });
}
