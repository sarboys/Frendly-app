import 'dart:convert';

import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _customRoutesKey = 'frendly_v5_custom_routes';

final customEveningRoutesProvider = StateNotifierProvider<
    CustomEveningRoutesController, List<CustomEveningRoute>>(
  (ref) => CustomEveningRoutesController(ref.watch(sharedPreferencesProvider)),
);

class CustomEveningRoute {
  const CustomEveningRoute({
    required this.id,
    required this.title,
    required this.mood,
    required this.duration,
    required this.steps,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String mood;
  final String duration;
  final List<CustomEveningRouteStep> steps;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mood': mood,
        'duration': duration,
        'createdAt': createdAt.toIso8601String(),
        'steps': steps.map((step) => step.toJson()).toList(growable: false),
      };

  static CustomEveningRoute? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(value);
    final id = json['id'] as String?;
    final title = json['title'] as String?;
    final mood = json['mood'] as String?;
    final duration = json['duration'] as String?;
    final createdAtRaw = json['createdAt'] as String?;
    if (id == null ||
        title == null ||
        mood == null ||
        duration == null ||
        createdAtRaw == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      return null;
    }
    final steps = ((json['steps'] as List?) ?? const [])
        .map(CustomEveningRouteStep.fromJson)
        .whereType<CustomEveningRouteStep>()
        .toList(growable: false);
    if (steps.length < 2) {
      return null;
    }
    return CustomEveningRoute(
      id: id,
      title: title,
      mood: mood,
      duration: duration,
      steps: steps,
      createdAt: createdAt,
    );
  }
}

class CustomEveningRouteStep {
  const CustomEveningRouteStep({
    required this.iconKey,
    required this.place,
    required this.subtitle,
  });

  final String iconKey;
  final String place;
  final String subtitle;

  Map<String, dynamic> toJson() => {
        'iconKey': iconKey,
        'place': place,
        'subtitle': subtitle,
      };

  static CustomEveningRouteStep? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(value);
    final iconKey = json['iconKey'] as String?;
    final place = json['place'] as String?;
    final subtitle = json['subtitle'] as String?;
    if (iconKey == null || place == null || subtitle == null) {
      return null;
    }
    return CustomEveningRouteStep(
      iconKey: iconKey,
      place: place,
      subtitle: subtitle,
    );
  }
}

class CustomEveningRoutesController
    extends StateNotifier<List<CustomEveningRoute>> {
  CustomEveningRoutesController(this._preferences)
      : super(_restore(_preferences));

  final SharedPreferences? _preferences;

  Future<void> save(CustomEveningRoute route) async {
    state = [route, ...state.where((item) => item.id != route.id)]
        .take(20)
        .toList(growable: false);
    await _persist();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(
      state.map((route) => route.toJson()).toList(growable: false),
    );
    await _preferences?.setString(_customRoutesKey, encoded);
  }

  static List<CustomEveningRoute> _restore(SharedPreferences? preferences) {
    final raw = preferences?.getString(_customRoutesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecodeSafe(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .map(CustomEveningRoute.fromJson)
        .whereType<CustomEveningRoute>()
        .toList(growable: false);
  }
}

Object? jsonDecodeSafe(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}
