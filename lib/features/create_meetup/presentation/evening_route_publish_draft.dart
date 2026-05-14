import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

CreateMeetupDraft publishDraftFromEveningRoute(EveningRouteData route) {
  final rawTitle = route.title.trim();
  final title = rawTitle.isEmpty ? 'Маршрут вечера' : rawTitle;
  final rawVibe = route.vibe.trim();
  final firstStep = route.steps.isEmpty ? null : route.steps.first;
  final duration = route.durationLabel.trim();
  final stepsLabel = _stepsLabel(route.steps.length);

  return CreateMeetupDraft(
    title: title,
    description: route.blurb,
    emoji: firstStep?.emoji ?? '🗺️',
    vibe: rawVibe.isEmpty ? 'Спокойно' : rawVibe,
    place: 'Маршрут: $title',
    startsAt: _startsAtFromRoute(route),
    capacity: 8,
    mode: 'default',
    lifestyle: 'neutral',
    priceMode: 'free',
    accessMode: 'open',
    genderMode: 'all',
    visibilityMode: 'public',
    joinMode: EventJoinMode.open,
    routeId: route.id.trim().isEmpty ? null : route.id.trim(),
    idempotencyKey:
        'mobile-ai-route-publish-${route.id}-${DateTime.now().microsecondsSinceEpoch}',
    attachmentTitle: 'Маршрут · $title',
    attachmentSubtitle: duration.isEmpty ? stepsLabel : duration,
    attachmentIcon: LucideIcons.route,
  );
}

DateTime _startsAtFromRoute(EveningRouteData route) {
  final now = DateTime.now();
  if (route.steps.isEmpty) {
    return now.add(const Duration(hours: 2));
  }

  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(
    route.steps.first.time,
  );
  if (match == null) {
    return now.add(const Duration(hours: 2));
  }

  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return now.add(const Duration(hours: 2));
  }

  final candidate = DateTime(now.year, now.month, now.day, hour, minute);
  if (candidate.isBefore(now.add(const Duration(minutes: 15)))) {
    return candidate.add(const Duration(days: 1));
  }
  return candidate;
}

String _stepsLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) {
    return '$count шаг';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$count шага';
  }
  return '$count шагов';
}
