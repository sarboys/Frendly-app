import 'package:flutter/services.dart';

class PhoneNumberTextInputFormatter extends TextInputFormatter {
  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String formatDigits(String value) {
    final digits = digitsOnly(value);
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    if (limited.length <= 3) {
      return limited;
    }
    if (limited.length <= 6) {
      return '${limited.substring(0, 3)} ${limited.substring(3)}';
    }
    if (limited.length <= 8) {
      return '${limited.substring(0, 3)} ${limited.substring(3, 6)}-${limited.substring(6)}';
    }
    return '${limited.substring(0, 3)} ${limited.substring(3, 6)}-${limited.substring(6, 8)}-${limited.substring(8)}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatDigits(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
