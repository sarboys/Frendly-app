import 'package:big_break_mobile/features/profile/presentation/profile_screen.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_overrides.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: buildTestOverrides(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('profile quick action cards have matching sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pumpAndSettle();

    Size cardSizeFor(String title) {
      final cardFinder = find.ancestor(
        of: find.text(title),
        matching: find.byType(BbV5Card),
      );
      expect(cardFinder, findsOneWidget);
      return tester.getSize(cardFinder);
    }

    final sizes = [
      cardSizeFor('Frendly+'),
      cardSizeFor('Wallet'),
      cardSizeFor('Верификация'),
      cardSizeFor('SOS'),
    ];

    final first = sizes.first;
    for (final size in sizes.skip(1)) {
      expect(size.width, first.width);
      expect(size.height, first.height);
    }
  });
}
