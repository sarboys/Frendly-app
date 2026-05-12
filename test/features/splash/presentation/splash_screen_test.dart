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
  testWidgets('splash runs the v5 circle intro', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('❤'), findsOneWidget);
    expect(find.text('👋'), findsOneWidget);
    expect(find.text('✨'), findsOneWidget);
    expect(find.text('🍷'), findsOneWidget);
    expect(find.text('💛'), findsOneWidget);
    expect(find.text('🎷'), findsOneWidget);
    expect(find.text('☕'), findsOneWidget);

    expect(find.text('Fr'), findsNothing);

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('ГОРОД · ЛЮДИ · ВЕЧЕР'), findsOneWidget);
  });
}
