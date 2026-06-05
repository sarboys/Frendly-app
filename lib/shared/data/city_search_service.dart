import 'package:mobile2/shared/data/city_catalog.dart';

enum CitySearchSource { catalog, yandex }

class CitySearchResult {
  const CitySearchResult({
    required this.label,
    required this.city,
    required this.area,
    required this.source,
    this.latitude,
    this.longitude,
  });

  final String label;
  final String city;
  final String? area;
  final CitySearchSource source;
  final double? latitude;
  final double? longitude;
}

List<CitySearchResult> catalogCitySearchResults(String query) {
  return cityMatchesFor(query)
      .map(
        (city) => CitySearchResult(
          label: city.label,
          city: city.city,
          area: city.area,
          source: CitySearchSource.catalog,
          latitude: city.latitude,
          longitude: city.longitude,
        ),
      )
      .toList(growable: false);
}

List<CitySearchResult> mergeCitySearchResults(
  List<CitySearchResult> catalog,
  List<CitySearchResult> remote,
) {
  final seen = <String>{};
  final results = <CitySearchResult>[];
  for (final item in [...catalog, ...remote]) {
    final key = citySearchToken(item.city);
    if (key.isEmpty || !seen.add(key)) {
      continue;
    }
    results.add(item);
  }
  return results;
}
