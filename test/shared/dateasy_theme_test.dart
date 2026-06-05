import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';

void main() {
  test('snack bar uses app purple background', () {
    expect(
      DateasyTheme.theme.snackBarTheme.backgroundColor,
      DateasyColors.surface2,
    );
  });

  test('snack bar content uses white text', () {
    expect(
      DateasyTheme.theme.snackBarTheme.contentTextStyle?.color,
      Colors.white,
    );
  });
}
