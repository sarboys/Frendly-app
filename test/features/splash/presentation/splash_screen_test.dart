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
  testWidgets('splash runs the V5 circle of friends intro', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('👋'), findsOneWidget);
    expect(find.text('✨'), findsOneWidget);
    expect(find.text('🍷'), findsOneWidget);
    expect(find.text('Fr'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('❤'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('e'), findsOneWidget);
    expect(find.text('ГОРОД · ЛЮДИ · ВЕЧЕР'), findsOneWidget);
  });
}
