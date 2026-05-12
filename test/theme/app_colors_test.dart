import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary color matches design token', () {
    expect(AppColors.primary.toARGB32(), 0xFFD08A63);
  });

  test('background color matches design token', () {
    expect(AppColors.background.toARGB32(), 0xFFF1E6D6);
  });

  test('dark background color matches design token', () {
    expect(AppColors.darkBackground.toARGB32(), 0xFF121217);
  });
}
