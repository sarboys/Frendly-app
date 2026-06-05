import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/data/city_search_service.dart';

void main() {
  test('city search merges catalog matches with remote city results', () {
    final results = mergeCitySearchResults(
      catalogCitySearchResults('нижн'),
      const [
        CitySearchResult(
          label: 'Нижнекамск',
          city: 'Нижнекамск',
          area: 'Республика Татарстан',
          source: CitySearchSource.yandex,
        ),
      ],
    );

    expect(results.map((item) => item.city), contains('Нижний Новгород'));
    expect(results.map((item) => item.city), contains('Нижнекамск'));
  });
}
