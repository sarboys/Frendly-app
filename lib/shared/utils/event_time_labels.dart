String eventDayLabel({
  required String time,
  String? startsAtIso,
  DateTime? now,
  String fallback = 'Сегодня',
}) {
  final prefix = _datePrefix(time);
  if (prefix != null) {
    return prefix;
  }

  final startsAt = DateTime.tryParse(startsAtIso ?? '')?.toLocal();
  if (startsAt == null) {
    return fallback;
  }

  final todaySource = now ?? DateTime.now();
  final day = DateTime(startsAt.year, startsAt.month, startsAt.day);
  final today = DateTime(
    todaySource.year,
    todaySource.month,
    todaySource.day,
  );
  final deltaDays = day.difference(today).inDays;
  if (deltaDays == 0) {
    return 'Сегодня';
  }
  if (deltaDays == 1) {
    return 'Завтра';
  }

  return '${startsAt.day} ${_monthName(startsAt.month)}';
}

String eventClockLabel(String time) {
  final parts = _labelParts(time);
  if (parts.length > 1 && !_isClock(parts.first)) {
    return parts.skip(1).join(' · ');
  }
  return time.trim();
}

String eventDateTimeLabel({
  required String time,
  String? status,
  String fallbackDay = 'Сегодня',
}) {
  final trimmedTime = time.trim();
  final trimmedStatus = status?.trim();

  if (trimmedTime.isEmpty) {
    return (trimmedStatus?.isNotEmpty ?? false) ? trimmedStatus! : fallbackDay;
  }
  if (_datePrefix(trimmedTime) != null) {
    return trimmedTime;
  }
  if (trimmedStatus != null && trimmedStatus.isNotEmpty) {
    return '$trimmedStatus · $trimmedTime';
  }
  return '$fallbackDay · $trimmedTime';
}

String? _datePrefix(String value) {
  final parts = _labelParts(value);
  if (parts.length < 2) {
    return null;
  }
  final first = parts.first;
  if (first.isEmpty || _isClock(first)) {
    return null;
  }
  return first;
}

List<String> _labelParts(String value) {
  return value
      .split('·')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

bool _isClock(String value) {
  return RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value.trim());
}

String _monthName(int month) {
  return switch (month) {
    1 => 'янв',
    2 => 'фев',
    3 => 'мар',
    4 => 'апр',
    5 => 'мая',
    6 => 'июн',
    7 => 'июл',
    8 => 'авг',
    9 => 'сен',
    10 => 'окт',
    11 => 'ноя',
    12 => 'дек',
    _ => '',
  };
}
