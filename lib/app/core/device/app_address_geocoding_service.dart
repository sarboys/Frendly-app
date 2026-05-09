import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

final appAddressGeocodingServiceProvider = Provider<AppAddressGeocodingService>(
  (ref) => const NativeAppAddressGeocodingService(),
);

abstract class AppAddressGeocodingService {
  Future<ForwardGeocodedLocation?> geocodeAddress(String query);
}

class ForwardGeocodedLocation {
  const ForwardGeocodedLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class NativeAppAddressGeocodingService implements AppAddressGeocodingService {
  const NativeAppAddressGeocodingService();

  @override
  Future<ForwardGeocodedLocation?> geocodeAddress(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final locations = await locationFromAddress(
      trimmed,
    ).timeout(const Duration(seconds: 6));
    if (locations.isEmpty) {
      return null;
    }

    final location = locations.first;
    return ForwardGeocodedLocation(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }
}
