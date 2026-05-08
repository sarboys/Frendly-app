import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BbPhoneCountry {
  const BbPhoneCountry({
    required this.key,
    required this.label,
    required this.flag,
    required this.dialCode,
    required this.localLength,
    required this.placeholder,
    required this.initialDigits,
    required this.groups,
  });

  final String key;
  final String label;
  final String flag;
  final String dialCode;
  final int localLength;
  final String placeholder;
  final String initialDigits;
  final List<int> groups;

  int get formattedLength => placeholder.length;

  String formatDigits(String digits) {
    final sanitized =
        digits.length > localLength ? digits.substring(0, localLength) : digits;
    final buffer = StringBuffer();
    var offset = 0;

    for (final group in groups) {
      if (offset >= sanitized.length) {
        break;
      }
      final end = (offset + group).clamp(0, sanitized.length);
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(sanitized.substring(offset, end));
      offset = end;
    }

    return buffer.toString();
  }
}

const bbPhoneCountries = [
  BbPhoneCountry(
    key: 'ru',
    label: 'Россия',
    flag: '🇷🇺',
    dialCode: '+7',
    localLength: 10,
    placeholder: '912 345 67 89',
    initialDigits: '9123456789',
    groups: [3, 3, 2, 2],
  ),
  BbPhoneCountry(
    key: 'by',
    label: 'Беларусь',
    flag: '🇧🇾',
    dialCode: '+375',
    localLength: 9,
    placeholder: '29 123 45 67',
    initialDigits: '291234567',
    groups: [2, 3, 2, 2],
  ),
  BbPhoneCountry(
    key: 'kz',
    label: 'Казахстан',
    flag: '🇰🇿',
    dialCode: '+7',
    localLength: 10,
    placeholder: '700 123 45 67',
    initialDigits: '7001234567',
    groups: [3, 3, 2, 2],
  ),
];

String bbPhoneDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String bbFormatPhoneInput(String value, BbPhoneCountry country) {
  final digits = bbPhoneDigits(value);
  final sanitized = digits.length > country.localLength
      ? digits.substring(0, country.localLength)
      : digits;
  return country.formatDigits(sanitized);
}

String? bbFullPhoneNumber(String value, BbPhoneCountry country) {
  final digits = bbPhoneDigits(value);
  if (digits.length != country.localLength) {
    return null;
  }
  return '${country.dialCode}$digits';
}

BbPhoneCountry bbCountryForPhoneNumber(String? phoneNumber) {
  final normalized = phoneNumber?.replaceAll(RegExp(r'\s'), '') ?? '';
  if (normalized.startsWith('+375')) {
    return bbPhoneCountries.firstWhere((item) => item.key == 'by');
  }
  if (normalized.startsWith('+7')) {
    final local = normalized.substring(2);
    if (local.startsWith('7')) {
      return bbPhoneCountries.firstWhere((item) => item.key == 'kz');
    }
  }
  return bbPhoneCountries.first;
}

String bbLocalDigitsForPhoneNumber(
    String? phoneNumber, BbPhoneCountry country) {
  final digits = bbPhoneDigits(phoneNumber ?? '');
  final dialDigits = bbPhoneDigits(country.dialCode);
  final local = digits.startsWith(dialDigits)
      ? digits.substring(dialDigits.length)
      : digits;
  return local.length > country.localLength
      ? local.substring(0, country.localLength)
      : local;
}

Future<BbPhoneCountry?> showBbPhoneCountryPicker({
  required BuildContext context,
  required BbPhoneCountry selected,
}) {
  return showModalBottomSheet<BbPhoneCountry>(
    context: context,
    builder: (context) {
      final colors = AppColors.of(context);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выбери страну',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 20,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final item in bbPhoneCountries)
                InkWell(
                  onTap: () => Navigator.of(context).pop(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Text(
                          item.flag,
                          style: const TextStyle(fontSize: 18, height: 1.1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: AppTextStyles.meta.copyWith(
                              color: colors.foreground,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Text(
                          item.dialCode,
                          style: AppTextStyles.meta.copyWith(
                            color: colors.inkMute,
                            fontFamily: 'Sora',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        if (item == selected) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class BbPhoneNumberField extends StatelessWidget {
  const BbPhoneNumberField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryTap,
    required this.onChanged,
    this.fieldKey,
  });

  final TextEditingController controller;
  final BbPhoneCountry country;
  final VoidCallback onCountryTap;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        SizedBox(
          height: 56,
          child: InkWell(
            onTap: onCountryTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                '${country.flag} ${country.dialCode}',
                style: AppTextStyles.body.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            alignment: Alignment.center,
            child: TextField(
              key: fieldKey,
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                LengthLimitingTextInputFormatter(country.formattedLength),
              ],
              onChanged: onChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: country.placeholder,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 16,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
