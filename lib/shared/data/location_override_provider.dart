import 'dart:async';
import 'dart:convert';

import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _manualLocationStorageKey = 'location.manual.v1';

@immutable
class ManualLocation {
  const ManualLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.city,
  });

  final String label;
  final double latitude;
  final double longitude;
  final String? city;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      if (city != null) 'city': city,
    };
  }

  factory ManualLocation.fromJson(Map<String, dynamic> json) {
    return ManualLocation(
      label: json['label'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      city: json['city'] as String?,
    );
  }
}

bool isSupportedCityLocationLabel(String? value) {
  final normalized = _normalizeLocationText(value);
  if (normalized.isEmpty) {
    return false;
  }

  return RegExp(r'(^|\s)москва(\s|$)').hasMatch(normalized) ||
      RegExp(r'(^|\s)moscow(\s|$)').hasMatch(normalized) ||
      normalized.contains('санкт петербург') ||
      normalized.contains('saint petersburg') ||
      normalized.contains('st petersburg') ||
      RegExp(r'(^|\s)(спб|питер)(\s|$)').hasMatch(normalized);
}

bool isSupportedManualLocation(ManualLocation location) {
  return location.label.trim().isNotEmpty &&
      location.latitude.isFinite &&
      location.longitude.isFinite &&
      location.latitude >= -90 &&
      location.latitude <= 90 &&
      location.longitude >= -180 &&
      location.longitude <= 180 &&
      (location.latitude != 0 || location.longitude != 0);
}

String _normalizeLocationText(String? value) {
  return value
          ?.toLowerCase()
          .replaceAll('ё', 'е')
          .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
          .trim() ??
      '';
}

final manualLocationProvider =
    StateNotifierProvider<ManualLocationController, ManualLocation?>(
  (ref) => ManualLocationController(ref.read(sharedPreferencesProvider)),
);

class ManualLocationController extends StateNotifier<ManualLocation?> {
  ManualLocationController(this._preferences)
      : super(_restoreLocation(_preferences));

  final SharedPreferences? _preferences;

  void setLocation(ManualLocation location) {
    if (!isSupportedManualLocation(location)) {
      clear();
      return;
    }
    state = location;
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(
        preferences.setString(
          _manualLocationStorageKey,
          jsonEncode(location.toJson()),
        ),
      );
    }
  }

  void clear() {
    state = null;
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.remove(_manualLocationStorageKey));
    }
  }
}

ManualLocation? _restoreLocation(SharedPreferences? preferences) {
  final raw = preferences?.getString(_manualLocationStorageKey);
  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['latitude'] is! num || json['longitude'] is! num) {
      return null;
    }
    final location = ManualLocation.fromJson(
      json,
    );
    if (!isSupportedManualLocation(location)) {
      return null;
    }
    return location;
  } catch (_) {
    return null;
  }
}
