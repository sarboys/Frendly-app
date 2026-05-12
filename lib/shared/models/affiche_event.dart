import 'package:big_break_mobile/shared/models/backend_url.dart';
import 'package:big_break_mobile/shared/models/media_variant.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';

enum AffichePriceMode { free, paid, unknown }

class AfficheEvent {
  const AfficheEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    required this.venue,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.dateLabel,
    required this.timeLabel,
    required this.category,
    required this.priceFrom,
    required this.priceMode,
    required this.currency,
    required this.imageUrl,
    this.imageVariants = const {},
    required this.provider,
    required this.sourceCode,
    required this.actionUrl,
    required this.actionKind,
    required this.isAffiliate,
    required this.tags,
  });

  final String id;
  final String title;
  final String? description;
  final String city;
  final String? venue;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? dateLabel;
  final String? timeLabel;
  final String category;
  final int? priceFrom;
  final AffichePriceMode priceMode;
  final String? currency;
  final String? imageUrl;
  final Map<String, MediaVariantData> imageVariants;
  final String? provider;
  final String? sourceCode;
  final String? actionUrl;
  final String? actionKind;
  final bool isAffiliate;
  final List<String> tags;

  bool get isPaid => priceMode == AffichePriceMode.paid;
  bool get isFree => priceMode == AffichePriceMode.free;
  bool get hasCoords => latitude != null && longitude != null;

  String get priceLabel {
    if (isFree) {
      return 'Бесплатно';
    }
    if (isPaid && priceFrom != null) {
      return 'от ${_formatRubles(priceFrom!)} ₽';
    }
    return 'Цена не указана';
  }

  String get compactPriceLabel {
    return priceLabel;
  }

  String get ctaLabel {
    if (isPaid && isAffiliate) {
      return 'Купить билет';
    }
    return 'Подробнее';
  }

  String get placeLabel {
    final parts = [
      if ((venue ?? '').trim().isNotEmpty) venue!.trim(),
      if ((address ?? '').trim().isNotEmpty) address!.trim(),
    ];
    return parts.isEmpty ? city : parts.join(', ');
  }

  factory AfficheEvent.fromJson(Map<String, dynamic> json) {
    return AfficheEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: _cleanExternalText(json['description'] as String?),
      city: json['city'] as String? ?? 'Москва',
      venue: json['venue'] as String?,
      address: json['address'] as String?,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble(),
      startsAt: _parseStartsAt(
        json['startsAt'] as String?,
        json['timeLabel'] as String?,
      ),
      endsAt: _parseDate(json['endsAt'] as String?),
      dateLabel: json['dateLabel'] as String?,
      timeLabel: json['timeLabel'] as String?,
      category: json['category'] as String? ?? 'culture',
      priceFrom: (json['priceFrom'] as num?)?.toInt(),
      priceMode: _parsePriceMode(json['priceMode'] as String?),
      currency: json['currency'] as String?,
      imageUrl: resolveBackendUrl(json['imageUrl'] as String?),
      imageVariants: parseMediaVariants(json['imageVariants']),
      provider: json['provider'] as String?,
      sourceCode: json['sourceCode'] as String?,
      actionUrl: json['actionUrl'] as String?,
      actionKind: json['actionKind'] as String?,
      isAffiliate: (json['isAffiliate'] as bool?) ?? false,
      tags: ((json['tags'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  String? imageUrlFor(BbExternalEventImageUsage usage) {
    return imageVariants[usage.name]?.url ?? imageUrl;
  }
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

DateTime? _parseStartsAt(String? value, String? timeLabel) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) {
    return null;
  }

  final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeLabel ?? '');
  if (timeMatch == null) {
    return parsed.toLocal();
  }

  final hour = int.tryParse(timeMatch.group(1)!);
  final minute = int.tryParse(timeMatch.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return parsed.toLocal();
  }

  final utc = parsed.toUtc();
  var offsetMinutes = (hour * 60 + minute) - (utc.hour * 60 + utc.minute);
  if (offsetMinutes < -12 * 60) {
    offsetMinutes += 24 * 60;
  } else if (offsetMinutes > 14 * 60) {
    offsetMinutes -= 24 * 60;
  }
  final shiftedDate = utc.add(Duration(minutes: offsetMinutes));
  return DateTime(
    shiftedDate.year,
    shiftedDate.month,
    shiftedDate.day,
    hour,
    minute,
  );
}

AffichePriceMode _parsePriceMode(String? value) {
  switch (value) {
    case 'free':
      return AffichePriceMode.free;
    case 'paid':
      return AffichePriceMode.paid;
    default:
      return AffichePriceMode.unknown;
  }
}

String _formatRubles(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i += 1) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(raw[i]);
  }
  return buffer.toString();
}

String? _cleanExternalText(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return raw;
  }
  final decoded = _decodeHtmlEntities(raw);
  final cleaned = decoded
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

String _decodeHtmlEntities(String value) {
  var decoded = value;
  for (var index = 0; index < 3; index += 1) {
    final next = decoded
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');
    if (next == decoded) {
      break;
    }
    decoded = next;
  }
  return decoded;
}
