import 'package:big_break_mobile/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone viewport injects fake status bar as top safe area', (
    tester,
  ) async {
    double? topPadding;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: AppPhoneViewportMediaQuery(
          statusBarHeight: 44,
          child: Builder(
            builder: (context) {
              topPadding = MediaQuery.of(context).padding.top;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(topPadding, 44);
  });
}
