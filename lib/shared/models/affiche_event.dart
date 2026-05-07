import 'package:big_break_mobile/shared/models/backend_url.dart';

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
      startsAt: _parseDate(json['startsAt'] as String?),
      endsAt: _parseDate(json['endsAt'] as String?),
      dateLabel: json['dateLabel'] as String?,
      timeLabel: json['timeLabel'] as String?,
      category: json['category'] as String? ?? 'culture',
      priceFrom: (json['priceFrom'] as num?)?.toInt(),
      priceMode: _parsePriceMode(json['priceMode'] as String?),
      currency: json['currency'] as String?,
      imageUrl: resolveBackendUrl(json['imageUrl'] as String?),
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
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
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
