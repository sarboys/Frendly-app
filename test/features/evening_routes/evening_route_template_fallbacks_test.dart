import 'package:big_break_mobile/features/evening_routes/data/evening_route_template_fallbacks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local route template fallback mirrors front route data', () {
    final routes = fallbackEveningRouteTemplateSummaries('Москва');

    expect(routes.length, 5);
    expect(routes.first.id, 'r-cozy-circle');
    expect(routes.first.routeId, 'r-cozy-circle');
    expect(routes.first.title, 'Тёплый круг на Покровке');
    expect(routes.first.totalPriceFrom, 1400);
    expect(routes.first.totalSavings, 650);
    expect(routes.first.mood, 'chill');
    expect(routes.first.hostsCount, 8);
    expect(routes.first.stepsPreview.map((step) => step.venue), [
      'Brix Wine',
      'Standup Store',
      'Кафе Заря',
      'Frendly чат',
    ]);
  });

  test('local route template detail resolves by template id or route id', () {
    final byTemplateId = fallbackEveningRouteTemplateDetail('r-date-noir');
    final byRouteId = fallbackEveningRouteTemplateDetail('r-date-noir');

    expect(byTemplateId.id, 'r-date-noir');
    expect(byTemplateId.routeId, 'r-date-noir');
    expect(byTemplateId.premium, isTrue);
    expect(byRouteId.steps.length, 3);
    expect(byRouteId.steps.first.venue, 'Garage Screen');
  });
}
