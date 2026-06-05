import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:url_launcher/url_launcher.dart';

typedef DateasyMapChoiceUrls = ({Uri google, Uri yandex});

DateasyMapChoiceUrls? dateasyMapChoiceUrls({
  double? latitude,
  double? longitude,
  String? label,
  String? fallbackQuery,
}) {
  final cleanLabel = _stringOrNull(label);
  if (_validCoordinatePair(latitude, longitude)) {
    final query = '$latitude,$longitude';
    return (
      google: Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      ),
      yandex: Uri.parse(
        [
          'https://yandex.ru/maps/?pt=$longitude,$latitude&z=16&l=map',
          if (cleanLabel != null)
            '&text=${Uri.encodeQueryComponent(cleanLabel)}',
        ].join(),
      ),
    );
  }

  final query = _stringOrNull(fallbackQuery) ?? cleanLabel;
  if (query == null) {
    return null;
  }

  return (
    google: Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': query},
    ),
    yandex: Uri.https(
      'yandex.ru',
      '/maps/',
      {'text': query},
    ),
  );
}

Future<void> showDateasyMapChoiceSheet(
  BuildContext context, {
  double? latitude,
  double? longitude,
  String? label,
  String? fallbackQuery,
  String failureMessage = 'Не удалось открыть карту',
}) async {
  final urls = dateasyMapChoiceUrls(
    latitude: latitude,
    longitude: longitude,
    label: label,
    fallbackQuery: fallbackQuery,
  );
  if (urls == null) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: DateasyColors.background,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              _DateasyMapButton(
                icon: LucideIcons.map,
                label: 'Google Maps',
                onTap: () => _openDateasyExternalMap(
                  sheetContext,
                  context,
                  urls.google,
                  failureMessage,
                ),
              ),
              const SizedBox(height: 10),
              _DateasyMapButton(
                icon: LucideIcons.mapPinned,
                label: 'Yandex Maps',
                onTap: () => _openDateasyExternalMap(
                  sheetContext,
                  context,
                  urls.yandex,
                  failureMessage,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _openDateasyExternalMap(
  BuildContext sheetContext,
  BuildContext ownerContext,
  Uri uri,
  String failureMessage,
) async {
  Navigator.of(sheetContext).maybePop();
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && ownerContext.mounted) {
    ScaffoldMessenger.of(ownerContext).hideCurrentSnackBar();
    ScaffoldMessenger.of(ownerContext).showSnackBar(
      SnackBar(
        content: Text(failureMessage),
        behavior: SnackBarBehavior.floating,
        backgroundColor: DateasyColors.surface2,
      ),
    );
  }
}

class _DateasyMapButton extends StatelessWidget {
  const _DateasyMapButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DateasyColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: DateasyColors.lime),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DateasyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const Icon(LucideIcons.arrowUpRight, size: 16),
          ],
        ),
      ),
    );
  }
}

bool _validCoordinatePair(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
