import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/data/app_providers.dart';

void main() {
  test('event list query includes requirement filters in cache key', () {
    const query = EventListQuery(
      limit: 20,
      requiresVerification: true,
      requiresFrendlyPlus: true,
    );

    expect(query.cacheValue(), contains('requiresVerification=true'));
    expect(query.cacheValue(), contains('requiresFrendlyPlus=true'));
    expect(
      query,
      isNot(
        const EventListQuery(
          limit: 20,
          requiresVerification: true,
        ),
      ),
    );
  });
}
