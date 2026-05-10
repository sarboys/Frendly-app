import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/publish_meetup_screen.dart';
import 'package:big_break_mobile/features/evening_routes/presentation/evening_route_template_plan_mapper.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateEveningSessionScreen extends ConsumerWidget {
  const CreateEveningSessionScreen({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(eveningRouteTemplateProvider(templateId));

    return detailAsync.when(
      data: (route) => PublishMeetupScreen(
        initialDraft: _draftFromTemplate(route),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => PublishMeetupScreen(
        initialDraft: _fallbackDraft(templateId),
      ),
    );
  }
}

CreateMeetupDraft _draftFromTemplate(EveningRouteTemplateDetail route) {
  final rawTitle = route.title.trim();
  final title = rawTitle.isEmpty ? 'Маршрут вечера' : rawTitle;
  final rawVibe = route.vibe.trim();
  final firstEmoji = route.steps.isEmpty ? '🗺️' : route.steps.first.emoji;
  final duration = route.durationLabel.trim();
  final stepsLabel = _stepsLabel(route.steps.length);

  return CreateMeetupDraft(
    title: title,
    description: route.blurb,
    emoji: firstEmoji,
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
    routeId: routeIdFromTemplate(route),
    idempotencyKey:
        'mobile-route-publish-${route.id}-${DateTime.now().microsecondsSinceEpoch}',
    attachmentTitle: 'Маршрут · $title',
    attachmentSubtitle: duration.isEmpty ? stepsLabel : duration,
    attachmentIcon: LucideIcons.route,
  );
}

CreateMeetupDraft _fallbackDraft(String templateId) {
  return CreateMeetupDraft(
    title: 'Маршрут вечера',
    description: '',
    emoji: '🗺️',
    vibe: 'Спокойно',
    place: 'Маршрут: Маршрут вечера',
    startsAt: DateTime.now().add(const Duration(hours: 2)),
    capacity: 8,
    mode: 'default',
    lifestyle: 'neutral',
    priceMode: 'free',
    accessMode: 'open',
    genderMode: 'all',
    visibilityMode: 'public',
    joinMode: EventJoinMode.open,
    routeId: templateId,
    idempotencyKey:
        'mobile-route-publish-$templateId-${DateTime.now().microsecondsSinceEpoch}',
    attachmentTitle: 'Маршрут · Маршрут вечера',
    attachmentSubtitle: '0 шагов',
    attachmentIcon: LucideIcons.route,
  );
}

DateTime _startsAtFromRoute(EveningRouteTemplateDetail route) {
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
  if (count == 1) {
    return '1 шаг';
  }
  if (count >= 2 && count <= 4) {
    return '$count шага';
  }
  return '$count шагов';
}
