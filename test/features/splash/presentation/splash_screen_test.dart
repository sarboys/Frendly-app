import 'package:big_break_mobile/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_overrides.dart';

Widget _wrap() {
  return ProviderScope(
    overrides: buildTestOverrides(),
    child: const MaterialApp(
      home: SplashScreen(),
    ),
  );
}

void main() {
  testWidgets('splash runs the v5 Frendly intro', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('F'), findsOneWidget);
    expect(find.text('r'), findsAtLeastNWidgets(1));

    expect(find.text('Fr'), findsNothing);
  });
}
