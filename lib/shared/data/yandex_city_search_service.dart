import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile2/shared/data/city_search_service.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

final yandexCitySearchServiceProvider =
    Provider<YandexCitySearchService>((ref) => const YandexCitySearchService());

class YandexCitySearchService {
  const YandexCitySearchService();

  Future<List<CitySearchResult>> search(String query, {int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const [];
    }
    final search = await ym.YandexSearch.searchByText(
      searchText: trimmed,
      geometry: ym.Geometry.fromBoundingBox(
        const ym.BoundingBox(
          northEast: ym.Point(latitude: 85, longitude: 180),
          southWest: ym.Point(latitude: -85, longitude: -180),
        ),
      ),
      searchOptions: ym.SearchOptions(
        searchType: ym.SearchType.geo,
        geometry: true,
        resultPageSize: limit,
      ),
    );
    final result = await search.$2;
    final items = result.items ?? const <ym.SearchItem>[];
    return items
        .map(_cityFromSearchItem)
        .whereType<CitySearchResult>()
        .toList(growable: false);
  }

  CitySearchResult? _cityFromSearchItem(ym.SearchItem item) {
    final address = item.toponymMetadata?.address;
    if (address == null) {
      return null;
    }
    final components = address.addressComponents;
    final locality = components[ym.SearchComponentKind.locality]?.trim();
    if (locality == null || locality.isEmpty) {
      return null;
    }
    final area = _areaFromComponents(components, locality) ??
        _areaFromAddress(address.formattedAddress, locality);
    final point =
        item.toponymMetadata?.balloonPoint ?? _pointFromGeometry(item);
    return CitySearchResult(
      label: locality,
      city: locality,
      area: area,
      source: CitySearchSource.yandex,
      latitude: point?.latitude,
      longitude: point?.longitude,
    );
  }

  ym.Point? _pointFromGeometry(ym.SearchItem item) {
    for (final geometry in item.geometry) {
      final point = geometry.point;
      if (point != null) {
        return point;
      }
      final box = geometry.boundingBox;
      if (box != null) {
        return ym.Point(
          latitude: (box.northEast.latitude + box.southWest.latitude) / 2,
          longitude: (box.northEast.longitude + box.southWest.longitude) / 2,
        );
      }
    }
    return null;
  }

  String? _areaFromComponents(
    Map<ym.SearchComponentKind, String> components,
    String city,
  ) {
    for (final kind in const [
      ym.SearchComponentKind.province,
      ym.SearchComponentKind.region,
      ym.SearchComponentKind.country,
    ]) {
      final value = components[kind]?.trim();
      if (value != null && value.isNotEmpty && value != city) {
        return value;
      }
    }
    return null;
  }

  String? _areaFromAddress(String? address, String city) {
    if (address == null || address.isEmpty) {
      return null;
    }
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part != city)
        .toList(growable: false);
    return parts.isEmpty ? null : parts.first;
  }
}
