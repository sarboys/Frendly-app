import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile2/shared/models/backend_models.dart';

const Map<String, int> _cityUtcOffsets = {
  'москва': 3,
  'санкт-петербург': 3,
  'казань': 3,
  'нижний новгород': 3,
  'ростов-на-дону': 3,
  'краснодар': 3,
  'воронеж': 3,
  'волгоград': 3,
  'самара': 4,
  'екатеринбург': 5,
  'уфа': 5,
  'пермь': 5,
  'челябинск': 5,
  'омск': 6,
  'новосибирск': 7,
  'красноярск': 7,
};

DateTime? parseNewMeetingStartsAt({
  required String date,
  required String time,
  String? city,
}) {
  final cleanDate = date.trim();
  final cleanTime = time.trim();
  if (cleanDate.isEmpty || cleanTime.isEmpty) {
    return null;
  }

  final dateParts = cleanDate.split('-');
  final timeParts = cleanTime.split(':');
  if (dateParts.length != 3 || timeParts.length < 2) {
    return null;
  }

  final year = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final day = int.tryParse(dateParts[2]);
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }

  final wallTime = DateTime.utc(year, month, day, hour, minute);
  if (wallTime.year != year ||
      wallTime.month != month ||
      wallTime.day != day ||
      wallTime.hour != hour ||
      wallTime.minute != minute) {
    return null;
  }

  final offset = _cityUtcOffset(city);
  if (offset == null) {
    return DateTime.tryParse('${cleanDate}T$cleanTime:00');
  }

  return wallTime.subtract(Duration(hours: offset));
}

int? _cityUtcOffset(String? city) {
  final normalized = city?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final exact = _cityUtcOffsets[normalized];
  if (exact != null) {
    return exact;
  }
  for (final entry in _cityUtcOffsets.entries) {
    if (normalized.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

Map<String, Object?> buildNewMeetingSourcePayload({
  String? inviteeUserId,
  String? sourceChatId,
  String? communityId,
  String? routeId,
  String? attachedRouteId,
}) {
  String? clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  final attachedRoute = clean(attachedRouteId);
  return {
    if (clean(inviteeUserId) case final value?) 'inviteeUserId': value,
    if (clean(sourceChatId) case final value?) 'sourceChatId': value,
    if (clean(communityId) case final value?) 'communityId': value,
    if (attachedRoute ?? clean(routeId) case final value?) 'routeId': value,
  };
}

Map<String, Object?> buildNewMeetingBasePayload({
  required String title,
  required String description,
  required String vibe,
  required String place,
  required String address,
  required DateTime startsAt,
  required int capacity,
  required String gender,
  required String visibility,
  String? city,
  String joinPolicy = 'open',
  bool requiresVerification = false,
  bool requiresFrendlyPlus = false,
}) {
  final cleanAddress = address.trim();
  final cleanCity = city?.trim();
  final privateVisibility = visibility == 'private' || visibility == 'link';
  final requestJoin = joinPolicy == 'request';
  return {
    'title': title,
    'description': description,
    'emoji': _emojiForVibe(vibe),
    'vibe': vibe,
    'place': [
      place,
      if (cleanAddress.isNotEmpty) cleanAddress,
    ].join(', '),
    if (cleanAddress.isNotEmpty) 'address': cleanAddress,
    if (cleanCity != null && cleanCity.isNotEmpty) 'city': cleanCity,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'capacity': capacity,
    'genderMode': gender == 'any' ? 'all' : gender,
    'visibilityMode': privateVisibility ? 'friends' : 'public',
    'visibility': privateVisibility ? 'private' : 'public',
    'accessMode': requestJoin || privateVisibility ? 'request' : 'open',
    'joinMode': requestJoin || privateVisibility ? 'request' : 'open',
    'priceMode': 'free',
    if (requiresVerification) 'requiresVerification': true,
    if (requiresFrendlyPlus) 'requiresFrendlyPlus': true,
  };
}

String newMeetingCreateFailureMessage({
  String? code,
  String? message,
  Map<String, Object?>? details,
}) {
  final cleanMessage = message?.trim().toLowerCase();
  return switch (code) {
    'event_coordinates_required' =>
      'Не нашли точку на карте. Укажи адрес точнее',
    'event_source_coordinates_missing' =>
      'У выбранного места нет точки на карте. Выбери другое',
    'event_weekly_limit_reached' => _weeklyLimitMessage(details),
    'content_moderation_rejected' =>
      'Текст не прошел проверку. Измени формулировку',
    'route_not_found' => 'Маршрут уже недоступен. Выбери другой',
    'invalid_event_payload' when cleanMessage?.contains('startsat') == true =>
      'Время уже прошло. Выбери будущее',
    'invalid_event_payload' => 'Проверь поля встречи',
    _ => 'Backend не создал встречу',
  };
}

String _weeklyLimitMessage(Map<String, Object?>? details) {
  final limit = details?['limit'];
  if (limit is int && limit > 0) {
    return 'Лимит встреч на неделю: $limit. Нужен Frendly+ или новая неделя';
  }
  return 'Лимит встреч на неделю исчерпан';
}

String _emojiForVibe(String vibe) {
  return switch (vibe) {
    'Кофе' => '☕',
    'Музыка' => '🎵',
    'Спорт' => '🏃',
    'Свидание' => '💘',
    _ => '🍷',
  };
}

enum NewMeetingDraftValidation {
  valid(''),
  missingRequired('Заполни название, описание и место'),
  invalidDateTime('Укажи дату и время в формате YYYY-MM-DD и HH:mm');

  const NewMeetingDraftValidation(this.message);

  final String message;
}

NewMeetingDraftValidation validateNewMeetingDraft({
  required String title,
  required String description,
  required String place,
  required DateTime? startsAt,
}) {
  if (title.isEmpty || description.isEmpty || place.isEmpty) {
    return NewMeetingDraftValidation.missingRequired;
  }
  if (startsAt == null) {
    return NewMeetingDraftValidation.invalidDateTime;
  }
  return NewMeetingDraftValidation.valid;
}

bool canPublishMeetingWithBoost({
  required int? boostPrice,
  required int walletBalance,
}) {
  if (boostPrice == null) {
    return true;
  }
  return walletBalance >= boostPrice;
}

class NewMeetingRoutePrefill {
  const NewMeetingRoutePrefill({
    required this.id,
    required this.attachedTitle,
    required this.attachedSubtitle,
    required this.title,
    required this.description,
    required this.place,
    required this.address,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String attachedTitle;
  final String attachedSubtitle;
  final String title;
  final String description;
  final String place;
  final String address;
  final String? city;
  final double? latitude;
  final double? longitude;
}

class NewMeetingAffichePrefill {
  const NewMeetingAffichePrefill({
    required this.id,
    required this.attachedTitle,
    required this.attachedSubtitle,
    required this.title,
    required this.description,
    required this.dateInput,
    required this.timeInput,
    required this.place,
    required this.address,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String attachedTitle;
  final String attachedSubtitle;
  final String title;
  final String description;
  final String dateInput;
  final String timeInput;
  final String place;
  final String address;
  final String? city;
  final double? latitude;
  final double? longitude;
}

typedef NewMeetingTimerFactory = Timer Function(
  Duration delay,
  void Function() callback,
);

class NewMeetingPlaceSearchDebouncer extends ChangeNotifier {
  NewMeetingPlaceSearchDebouncer({
    this.delay = const Duration(milliseconds: 300),
    NewMeetingTimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? Timer.new;

  final Duration delay;
  final NewMeetingTimerFactory _timerFactory;
  Timer? _timer;
  String _query = '';

  String get query => _query;

  void update(String value) {
    final nextQuery = value.trim();
    _timer?.cancel();
    _timer = _timerFactory(delay, () {
      if (_query == nextQuery) {
        return;
      }
      _query = nextQuery;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class NewMeetingCreateIdempotency {
  NewMeetingCreateIdempotency({
    int Function()? timestampFactory,
  }) : _timestampFactory =
            timestampFactory ?? (() => DateTime.now().microsecondsSinceEpoch);

  final int Function() _timestampFactory;
  String? _key;

  String currentKey() {
    return _key ??= 'mobile2-${_timestampFactory()}';
  }
}

NewMeetingAffichePrefill buildNewMeetingAffichePrefill(
  BackendCardItem event,
) {
  final title = event.title.trim();
  final startsAt = event.startsAt?.toLocal();
  final place = _affichePlace(event);
  final address = _afficheAddress(event);

  return NewMeetingAffichePrefill(
    id: event.id,
    attachedTitle: title.isEmpty ? 'Афиша' : title,
    attachedSubtitle: [
      _formatAttachDate(startsAt),
      place.isEmpty ? null : place,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
    title: title.isEmpty ? '' : 'Идем на $title',
    description: _afficheDescription(event),
    dateInput: startsAt == null ? '' : _formatDateInput(startsAt),
    timeInput: startsAt == null ? '' : _formatTimeInput(startsAt),
    place: place,
    address: address,
    city: event.city,
    latitude: event.latitude,
    longitude: event.longitude,
  );
}

NewMeetingRoutePrefill buildNewMeetingRoutePrefill(BackendCardItem route) {
  final title = route.title.trim().isEmpty ? 'Маршрут' : route.title.trim();
  final raw = route.raw;
  final routeId =
      _rawString(raw, const ['routeId', 'currentRouteId']) ?? route.id;
  final firstStep = _firstRouteStep(raw);
  final attachedSubtitle = [
    raw['area']?.toString(),
    raw['durationLabel']?.toString(),
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
  final stepPlace =
      _rawString(firstStep, const ['venue', 'place', 'venueName', 'title']);
  final stepAddress = _rawString(firstStep, const ['address']);

  return NewMeetingRoutePrefill(
    id: routeId,
    attachedTitle: title,
    attachedSubtitle: attachedSubtitle,
    title: title,
    description: _rawString(raw, const ['blurb', 'description']) ??
        'Маршрут для встречи',
    place: stepPlace ?? title,
    address: stepAddress ?? route.subtitle ?? route.city ?? '',
    city: _rawString(raw, const ['city']) ?? route.city,
    latitude: _rawDouble(firstStep['lat'] ?? firstStep['latitude']),
    longitude: _rawDouble(firstStep['lng'] ?? firstStep['longitude']),
  );
}

Map<String, Object?> _firstRouteStep(Map<String, Object?> raw) {
  for (final key in ['steps', 'routePoints', 'stepsPreview']) {
    final steps = raw[key];
    if (steps is! List || steps.isEmpty) {
      continue;
    }
    final first = steps.first;
    if (first is Map) {
      return first.map((key, value) => MapEntry('$key', value));
    }
  }
  return const {};
}

String _formatAttachDate(DateTime? value) {
  if (value == null) {
    return 'Время уточняется';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}.${local.month} · $hour:$minute';
}

String _formatDateInput(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _formatTimeInput(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String? _rawString(Map<String, Object?> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _affichePlace(BackendCardItem event) {
  return _rawString(event.raw, const ['venue', 'venueName', 'placeName']) ??
      _nestedRawString(event.raw, 'place', const ['name', 'title']) ??
      event.subtitle ??
      '';
}

String _afficheAddress(BackendCardItem event) {
  return _rawString(event.raw, const ['address', 'locationAddress']) ??
      _nestedRawString(event.raw, 'place', const ['address']) ??
      event.city ??
      '';
}

String _afficheDescription(BackendCardItem event) {
  return _rawString(event.raw, const ['description', 'body', 'details']) ?? '';
}

String? _nestedRawString(
  Map<String, Object?> raw,
  String key,
  List<String> fields,
) {
  final nested = raw[key];
  if (nested is! Map) {
    return null;
  }
  return _rawString(
    nested.map((key, value) => MapEntry('$key', value)),
    fields,
  );
}

double? _rawDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
