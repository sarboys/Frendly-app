import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/data/backend_repository.dart';

void main() {
  test('map events query uses backend geo parameter names', () {
    final query = buildMapEventsQueryParameters(
      centerLatitude: 55.75,
      centerLongitude: 37.61,
      radiusKm: 42,
      southWestLatitude: 55.7,
      southWestLongitude: 37.5,
      northEastLatitude: 55.8,
      northEastLongitude: 37.7,
      limit: 80,
    );

    expect(query['filter'], 'nearby');
    expect(query['latitude'], 55.75);
    expect(query['longitude'], 37.61);
    expect(query['radiusKm'], 42);
    expect(query['southWestLatitude'], 55.7);
    expect(query['southWestLongitude'], 37.5);
    expect(query['northEastLatitude'], 55.8);
    expect(query['northEastLongitude'], 37.7);
    expect(query.containsKey('north'), isFalse);
    expect(query.containsKey('south'), isFalse);
    expect(query.containsKey('east'), isFalse);
    expect(query.containsKey('west'), isFalse);
  });
}
