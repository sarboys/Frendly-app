import 'package:big_break_mobile/features/evening_routes/data/evening_route_template_fallbacks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local route template fallback does not provide static routes', () {
    final routes = fallbackEveningRouteTemplateSummaries('Москва');

    expect(routes, isEmpty);
  });

  test('local route template detail returns an empty shell', () {
    final detail = fallbackEveningRouteTemplateDetail('missing-route');

    expect(detail.id, 'missing-route');
    expect(detail.routeId, 'missing-route');
    expect(detail.steps, isEmpty);
  });
}
