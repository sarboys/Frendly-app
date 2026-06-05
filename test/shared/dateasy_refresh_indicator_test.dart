import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_refresh_indicator.dart';

void main() {
  testWidgets('DateasyRefreshIndicator uses shared styling and refresh action',
      (tester) async {
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: DateasyTheme.theme,
        home: Scaffold(
          body: DateasyRefreshIndicator(
            onRefresh: () async {
              refreshes += 1;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 600, child: Text('Wallet')),
              ],
            ),
          ),
        ),
      ),
    );

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(indicator.color, DateasyColors.lime);
    expect(indicator.backgroundColor, DateasyColors.surface);

    await tester.drag(find.text('Wallet'), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshes, 1);
  });

  testWidgets('DateasyRefreshIndicator is transparent without refresh action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DateasyRefreshIndicator(
          child: ListView(
            children: const [
              Text('Plain'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.text('Plain'), findsOneWidget);
  });
}
