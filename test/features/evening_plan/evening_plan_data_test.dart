import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evening plan has no local static route data', () {
    final fallback = findEveningRoute('missing-route');

    expect(eveningRoutes, isEmpty);
    expect(fallback.id, 'missing-route');
    expect(fallback.steps, isEmpty);
    expect(eveningBudgets[1].blurb, '500–1500 ₽');
    expect(eveningBudgets[2].blurb, '1500–3000 ₽');
  });
}
