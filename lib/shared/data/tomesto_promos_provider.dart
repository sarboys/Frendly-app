import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/utils/location_label.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class TomestoPromosQuery {
  const TomestoPromosQuery({
    required this.city,
    this.latitude,
    this.longitude,
    this.limit = 80,
    this.category,
  });

  final String city;
  final double? latitude;
  final double? longitude;
  final int limit;
  final String? category;

  factory TomestoPromosQuery.fromManualLocation(
    ManualLocation? location, {
    int limit = 80,
    String? category,
  }) {
    final supported = location != null && isSupportedManualLocation(location);
    final city = supported ? _cityFromManualLocation(location) : 'Москва';
    return TomestoPromosQuery(
      city: city,
      latitude: supported ? location.latitude : null,
      longitude: supported ? location.longitude : null,
      limit: limit,
      category: category,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TomestoPromosQuery &&
        other.city == city &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.limit == limit &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(city, latitude, longitude, limit, category);
}

final tomestoPromosProvider = FutureProvider.autoDispose
    .family<List<BackendPlacePromoListItem>, TomestoPromosQuery>(
  (ref, query) {
    return ref.read(backendRepositoryProvider).fetchPlacePromos(
          city: query.city,
          latitude: query.latitude,
          longitude: query.longitude,
          limit: query.limit,
          category: query.category,
        );
  },
);

String _cityFromManualLocation(ManualLocation location) {
  final city = normalizeCityLabel(location.city);
  if (city.isNotEmpty) {
    return city;
  }
  final label = normalizeCityLabel(location.label);
  return label.isEmpty ? 'Москва' : label;
}
