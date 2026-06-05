class RussianCity {
  const RussianCity({
    required this.label,
    required this.city,
    required this.area,
    required this.latitude,
    required this.longitude,
    this.aliases = const [],
  });

  final String label;
  final String city;
  final String area;
  final double latitude;
  final double longitude;
  final List<String> aliases;
}

class CityCoordinates {
  const CityCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

const defaultRussianCities = [
  RussianCity(
    label: 'Москва',
    city: 'Москва',
    area: 'Москва',
    latitude: 55.7558,
    longitude: 37.6173,
  ),
  RussianCity(
    label: 'Санкт-Петербург',
    city: 'Санкт-Петербург',
    area: 'Санкт-Петербург',
    latitude: 59.9343,
    longitude: 30.3351,
    aliases: ['СПб', 'Санкт Петербург', 'Питер'],
  ),
  RussianCity(
    label: 'Казань',
    city: 'Казань',
    area: 'Республика Татарстан',
    latitude: 55.7961,
    longitude: 49.1064,
  ),
  RussianCity(
    label: 'Сочи',
    city: 'Сочи',
    area: 'Краснодарский край',
    latitude: 43.5855,
    longitude: 39.7231,
  ),
  RussianCity(
    label: 'Новосибирск',
    city: 'Новосибирск',
    area: 'Новосибирская область',
    latitude: 55.0084,
    longitude: 82.9357,
  ),
  RussianCity(
    label: 'Омск',
    city: 'Омск',
    area: 'Омская область',
    latitude: 54.9885,
    longitude: 73.3242,
  ),
  RussianCity(
    label: 'Калининград',
    city: 'Калининград',
    area: 'Калининградская область',
    latitude: 54.7104,
    longitude: 20.4522,
  ),
  RussianCity(
    label: 'Ростов-на-Дону',
    city: 'Ростов-на-Дону',
    area: 'Ростовская область',
    latitude: 47.2357,
    longitude: 39.7015,
    aliases: ['Ростов на Дону'],
  ),
  RussianCity(
    label: 'Нижний Новгород',
    city: 'Нижний Новгород',
    area: 'Нижегородская область',
    latitude: 56.3269,
    longitude: 44.0059,
  ),
  RussianCity(
    label: 'Екатеринбург',
    city: 'Екатеринбург',
    area: 'Свердловская область',
    latitude: 56.8389,
    longitude: 60.6057,
  ),
  RussianCity(
    label: 'Краснодар',
    city: 'Краснодар',
    area: 'Краснодарский край',
    latitude: 45.0355,
    longitude: 38.9753,
  ),
  RussianCity(
    label: 'Нижневартовск',
    city: 'Нижневартовск',
    area: 'Ханты-Мансийский автономный округ',
    latitude: 60.9397,
    longitude: 76.5696,
  ),
];

const allRussianCities = [
  ...defaultRussianCities,
  RussianCity(
    label: 'Тверь',
    city: 'Тверь',
    area: 'Тверская область',
    latitude: 56.8587,
    longitude: 35.9176,
  ),
];

String citySearchToken(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[\s-]+'), ' ');
}

Iterable<String> citySearchValues(RussianCity city) sync* {
  yield city.label;
  yield city.city;
  yield city.area;
  yield* city.aliases;
}

List<RussianCity> cityMatchesFor(
  String query, {
  List<RussianCity> cities = allRussianCities,
}) {
  final token = citySearchToken(query);
  if (token.length < 2) {
    return const [];
  }
  return cities
      .where(
        (city) => citySearchValues(city).any(
          (value) => citySearchToken(value).contains(token),
        ),
      )
      .toList(growable: false);
}

RussianCity? cityForQuery(
  String query, {
  List<RussianCity> cities = allRussianCities,
}) {
  final token = citySearchToken(query);
  for (final city in cities) {
    final matches = citySearchValues(city).any(
      (value) => citySearchToken(value) == token,
    );
    if (matches) {
      return city;
    }
  }
  return null;
}

CityCoordinates? cityPointForQuery(String? query) {
  final trimmed = query?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final city = cityForQuery(trimmed);
  if (city == null) {
    return null;
  }
  return CityCoordinates(
    latitude: city.latitude,
    longitude: city.longitude,
  );
}
