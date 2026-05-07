import 'package:big_break_mobile/shared/models/backend_url.dart';
import 'package:big_break_mobile/shared/models/event.dart';

enum PosterCategory {
  concert,
  sport,
  exhibition,
  theatre,
  standup,
  festival,
  cinema,
}

class Poster {
  const Poster({
    required this.id,
    required this.title,
    required this.category,
    required this.emoji,
    required this.startsAt,
    required this.dateLabel,
    required this.timeLabel,
    required this.venue,
    required this.address,
    required this.distance,
    required this.priceFrom,
    required this.ticketUrl,
    required this.provider,
    required this.tone,
    required this.tags,
    required this.description,
    required this.isFeatured,
    this.imageUrl,
  });

  final String id;
  final String title;
  final PosterCategory category;
  final String emoji;
  final DateTime startsAt;
  final String dateLabel;
  final String timeLabel;
  final String venue;
  final String address;
  final String distance;
  final int priceFrom;
  final String ticketUrl;
  final String provider;
  final EventTone tone;
  final List<String> tags;
  final String description;
  final bool isFeatured;
  final String? imageUrl;

  String get priceLabel =>
      priceFrom == 0 ? 'Бесплатно' : 'от ${_formatRubles(priceFrom)} ₽';

  String get compactPriceLabel {
    if (priceFrom == 0) {
      return 'Free';
    }

    final shortValue = priceFrom / 1000;
    final formatted = shortValue == shortValue.roundToDouble()
        ? shortValue.toStringAsFixed(0)
        : shortValue.toStringAsFixed(1);
    return 'от ${formatted}k ₽';
  }

  String get displayDateLabel {
    final raw = dateLabel.trim();
    if (raw.toLowerCase() == 'каждый день') {
      return _formatShortDate(startsAt);
    }
    return raw;
  }

  PosterDateStamp get dateStamp {
    final parsed = _parseDateStamp(displayDateLabel);
    if (parsed != null) {
      return parsed;
    }

    final fallback = _formatShortDate(startsAt);
    return _parseDateStamp(fallback) ??
        PosterDateStamp(
          dow: '',
          day: startsAt.day.toString(),
          month: '',
        );
  }

  String get meetupTitle => 'Идём на «$title»';

  String get placeLabel => '$venue, $address';

  factory Poster.fromJson(Map<String, dynamic> json) {
    return Poster(
      id: json['id'] as String,
      title: json['title'] as String,
      category: _parseCategory(json['category'] as String?),
      emoji: json['emoji'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      dateLabel: json['date'] as String,
      timeLabel: json['time'] as String,
      venue: json['venue'] as String,
      address: json['address'] as String,
      distance: json['distance'] as String,
      priceFrom: (json['priceFrom'] as num?)?.toInt() ?? 0,
      ticketUrl: json['ticketUrl'] as String,
      provider: json['provider'] as String,
      tone: Event.parseTone(json['tone'] as String?),
      tags: ((json['tags'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      description: json['description'] as String,
      isFeatured: (json['isFeatured'] as bool?) ?? false,
      imageUrl: resolveBackendUrl(_readPosterImageUrl(json)),
    );
  }

  static PosterCategory _parseCategory(String? raw) {
    switch (raw) {
      case 'sport':
        return PosterCategory.sport;
      case 'exhibition':
        return PosterCategory.exhibition;
      case 'theatre':
        return PosterCategory.theatre;
      case 'standup':
        return PosterCategory.standup;
      case 'festival':
        return PosterCategory.festival;
      case 'cinema':
        return PosterCategory.cinema;
      case 'concert':
      default:
        return PosterCategory.concert;
    }
  }
}

String? _readPosterImageUrl(Map<String, dynamic> json) {
  final direct = _readNonEmptyString(json['imageUrl']) ??
      _readNonEmptyString(json['coverUrl']);
  if (direct != null) {
    return direct;
  }

  final cover = json['cover'];
  if (cover is Map) {
    return _readNonEmptyString(cover['url']) ??
        _readNonEmptyString(cover['downloadUrl']);
  }

  return null;
}

String? _readNonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class PosterDateStamp {
  const PosterDateStamp({
    required this.dow,
    required this.day,
    required this.month,
  });

  final String dow;
  final String day;
  final String month;
}

PosterDateStamp? _parseDateStamp(String value) {
  final match = RegExp(r'^([^,]+),\s*(\d{1,2})(?:[–-]\d{1,2})?\s+(\S+)')
      .firstMatch(value.trim());
  if (match == null) {
    return null;
  }

  return PosterDateStamp(
    dow: match.group(1)!.trim(),
    day: match.group(2)!.trim(),
    month: match.group(3)!.trim(),
  );
}

String _formatShortDate(DateTime value) {
  const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  const months = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  return '${weekdays[value.weekday - 1]}, ${value.day} ${months[value.month - 1]}';
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

extension PosterCategoryPresentation on PosterCategory {
  String get label {
    switch (this) {
      case PosterCategory.concert:
        return 'Концерты';
      case PosterCategory.sport:
        return 'Спорт';
      case PosterCategory.exhibition:
        return 'Выставки';
      case PosterCategory.theatre:
        return 'Театр';
      case PosterCategory.standup:
        return 'Стендап';
      case PosterCategory.festival:
        return 'Фестивали';
      case PosterCategory.cinema:
        return 'Кино';
    }
  }

  String get emoji {
    switch (this) {
      case PosterCategory.concert:
        return '🎸';
      case PosterCategory.sport:
        return '⚽';
      case PosterCategory.exhibition:
        return '🎨';
      case PosterCategory.theatre:
        return '🎭';
      case PosterCategory.standup:
        return '🎤';
      case PosterCategory.festival:
        return '🎡';
      case PosterCategory.cinema:
        return '🎬';
    }
  }
}
