import 'package:big_break_mobile/shared/widgets/bb_v5_promo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('promo badge renders gold top label with flame icon',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbV5PromoBadge(label: 'ТОП'),
          ),
        ),
      ),
    );

    expect(find.text('ТОП'), findsOneWidget);
    expect(find.byIcon(LucideIcons.flame), findsOneWidget);

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(BbV5PromoBadge),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
  });

  testWidgets('promo note can render compact promoted context', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BbV5PromoNote(text: 'Продвигается сегодня'),
          ),
        ),
      ),
    );

    expect(find.text('Продвигается сегодня'), findsOneWidget);
  });
}
