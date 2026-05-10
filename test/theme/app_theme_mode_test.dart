import 'package:big_break_mobile/app/app.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_overrides.dart';

void main() {
  testWidgets('root uses dark theme from stored preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'ui.dark_mode': true});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      BigBreakRoot(
        overrides: [
          ...buildTestOverrides(),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
