import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';

List<EveningRouteTemplateSummary> fallbackEveningRouteTemplateSummaries(
  String city,
) {
  return eveningRoutes
      .map((route) => route.toTemplateSummary(city))
      .toList(growable: false);
}

EveningRouteTemplateDetail fallbackEveningRouteTemplateDetail(String id) {
  final route = findEveningRoute(id);
  return route.toTemplateDetail('Москва');
}

extension EveningRouteTemplateFallbackX on EveningRouteData {
  EveningRouteTemplateSummary toTemplateSummary(String city) {
    return EveningRouteTemplateSummary(
      id: id,
      routeId: id,
      title: title,
      blurb: blurb,
      city: city,
      area: area,
      vibe: vibe,
      budget: _budgetKey(budget),
      durationLabel: durationLabel,
      totalPriceFrom: totalPriceFrom,
      totalSavings: totalSavings,
      mood: _moodKey(mood),
      premium: premium,
      hostsCount: hostsCount,
      stepsPreview: steps
          .map(
            (step) => EveningRouteTemplateStepPreview(
              title: step.title,
              venue: step.venue,
              emoji: step.emoji,
              time: step.time,
              kind: _stepKindKey(step.kind),
            ),
          )
          .toList(growable: false),
      partnerOffersPreview: steps
          .where((step) => (step.partnerId ?? '').isNotEmpty)
          .map(
            (step) => EveningPartnerOfferPreview(
              partnerId: step.partnerId!,
              title: step.perk ?? step.perkShort ?? step.title,
              shortLabel: step.perkShort,
            ),
          )
          .toList(growable: false),
      nearestSessions: const [],
    );
  }

  EveningRouteTemplateDetail toTemplateDetail(String city) {
    final summary = toTemplateSummary(city);
    return EveningRouteTemplateDetail(
      id: summary.id,
      routeId: summary.routeId,
      title: summary.title,
      blurb: summary.blurb,
      city: summary.city,
      vibe: summary.vibe,
      budget: summary.budget,
      durationLabel: summary.durationLabel,
      totalPriceFrom: summary.totalPriceFrom,
      stepsPreview: summary.stepsPreview,
      partnerOffersPreview: summary.partnerOffersPreview,
      nearestSessions: summary.nearestSessions,
      area: summary.area,
      badgeLabel: summary.badgeLabel,
      coverUrl: summary.coverUrl,
      goal: _goalKey(goal),
      totalSavings: summary.totalSavings,
      mood: summary.mood,
      premium: summary.premium,
      hostsCount: summary.hostsCount,
      recommendedFor: recommendedFor,
      steps: steps
          .map(
            (step) => EveningRouteTemplateStep(
              id: step.id,
              time: step.time,
              endTime: step.endTime,
              kind: _stepKindKey(step.kind),
              title: step.title,
              venue: step.venue,
              address: step.address,
              emoji: step.emoji,
              distance: step.distance,
              walkMin: step.walkMin,
              perk: step.perk,
              perkShort: step.perkShort,
              ticketPrice: step.ticketPrice,
              ticketCommission: step.ticketCommission,
              sponsored: step.sponsored,
              premium: step.premium,
              partnerId: step.partnerId,
              description: step.description,
              vibeTag: step.vibeTag,
              lat: step.lat,
              lng: step.lng,
              venueId: step.venueId,
              partnerOfferId: step.partnerOfferId,
              offerTitle: step.offerTitle,
              offerDescription: step.offerDescription,
              offerTerms: step.offerTerms,
              offerShortLabel: step.offerShortLabel,
            ),
          )
          .toList(growable: false),
    );
  }
}

String _moodKey(EveningMood value) {
  switch (value) {
    case EveningMood.chill:
      return 'chill';
    case EveningMood.social:
      return 'social';
    case EveningMood.date:
      return 'date';
    case EveningMood.wild:
      return 'wild';
    case EveningMood.afterdark:
      return 'afterdark';
  }
}

String _budgetKey(EveningBudget value) {
  switch (value) {
    case EveningBudget.free:
      return 'free';
    case EveningBudget.low:
      return 'low';
    case EveningBudget.mid:
      return 'mid';
    case EveningBudget.high:
      return 'high';
  }
}

String _goalKey(EveningGoal value) {
  switch (value) {
    case EveningGoal.newfriends:
      return 'newfriends';
    case EveningGoal.date:
      return 'date';
    case EveningGoal.company:
      return 'company';
    case EveningGoal.quiet:
      return 'quiet';
    case EveningGoal.afterdark:
      return 'afterdark';
  }
}

String _stepKindKey(EveningStepKind value) {
  switch (value) {
    case EveningStepKind.bar:
      return 'bar';
    case EveningStepKind.show:
      return 'show';
    case EveningStepKind.afterparty:
      return 'afterparty';
    case EveningStepKind.followup:
      return 'followup';
    case EveningStepKind.dinner:
      return 'dinner';
    case EveningStepKind.wellness:
      return 'wellness';
    case EveningStepKind.active:
      return 'active';
  }
}
