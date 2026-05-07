import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';

String routeIdFromTemplate(EveningRouteTemplateDetail route) {
  final routeId = route.routeId.trim();
  if (routeId.isNotEmpty) {
    return routeId;
  }

  return route.id;
}

EveningRouteData routeDataFromTemplate(EveningRouteTemplateDetail route) {
  return eveningRouteFromJson({
    'id': routeIdFromTemplate(route),
    'title': route.title,
    'vibe': route.vibe,
    'blurb': route.blurb,
    'totalPriceFrom': route.totalPriceFrom,
    'totalSavings': route.totalSavings,
    'durationLabel': route.durationLabel,
    'area': route.area,
    'goal': route.goal,
    'mood': route.mood,
    'budget': route.budget,
    'premium': route.premium,
    'recommendedFor': route.recommendedFor,
    'hostsCount': route.hostsCount,
    'steps': route.steps.map(_stepJsonFromTemplate).toList(growable: false),
  });
}

Map<String, dynamic> _stepJsonFromTemplate(EveningRouteTemplateStep step) {
  return {
    'id': step.id,
    'time': step.time,
    'endTime': step.endTime,
    'kind': step.kind,
    'title': step.title,
    'venue': step.venue,
    'address': step.address,
    'emoji': step.emoji,
    'distance': step.distance,
    'walkMin': step.walkMin,
    'perk': step.perk,
    'perkShort': step.perkShort,
    'ticketPrice': step.ticketPrice,
    'ticketCommission': step.ticketCommission,
    'sponsored': step.sponsored,
    'premium': step.premium,
    'partnerId': step.partnerId,
    'venueId': step.venueId,
    'partnerOfferId': step.partnerOfferId,
    'offerTitle': step.offerTitle,
    'offerDescription': step.offerDescription,
    'offerTerms': step.offerTerms,
    'offerShortLabel': step.offerShortLabel,
    'description': step.description,
    'vibeTag': step.vibeTag,
    'lat': step.lat,
    'lng': step.lng,
  };
}
