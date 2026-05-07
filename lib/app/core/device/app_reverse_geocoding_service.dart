import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

final appReverseGeocodingServiceProvider = Provider<AppReverseGeocodingService>(
  (ref) => const NativeAppReverseGeocodingService(),
);

abstract class AppReverseGeocodingService {
  Future<ReverseGeocodedLocation?> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}

class ReverseGeocodedLocation {
  const ReverseGeocodedLocation({
    required this.city,
    required this.street,
  });

  final String? city;
  final String? street;
}

class NativeAppReverseGeocodingService implements AppReverseGeocodingService {
  const NativeAppReverseGeocodingService();

  @override
  Future<ReverseGeocodedLocation?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final placemarks = await placemarkFromCoordinates(
      latitude,
      longitude,
    ).timeout(const Duration(seconds: 6));
    if (placemarks.isEmpty) {
      return null;
    }

    return _locationFromPlacemark(placemarks.first);
  }

  ReverseGeocodedLocation? _locationFromPlacemark(Placemark placemark) {
    final city = _firstNotEmpty([
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
      placemark.subLocality,
    ]);
    final street = _firstNotEmpty([
      placemark.thoroughfare,
      placemark.street,
      placemark.name,
    ]);
    if (city == null && street == null) {
      return null;
    }

    return ReverseGeocodedLocation(
      city: city,
      street: street,
    );
  }

  String? _firstNotEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return null;
  }
}
