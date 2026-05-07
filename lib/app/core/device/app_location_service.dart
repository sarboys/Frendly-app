import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:big_break_mobile/app/core/device/app_permission_service.dart';

final appLocationServiceProvider = Provider<AppLocationService>(
  (ref) => NativeAppLocationService(
    permissionService: ref.watch(appPermissionServiceProvider),
  ),
);

abstract class AppLocationService {
  Future<Position?> getCurrentPosition();
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  });
}

class NativeAppLocationService implements AppLocationService {
  const NativeAppLocationService({
    required AppPermissionService permissionService,
  }) : _permissionService = permissionService;

  final AppPermissionService _permissionService;

  @override
  Future<Position?> getCurrentPosition() async {
    final granted = await _permissionService.requestLocation();
    if (!granted) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return _lastKnownPosition();
    }
  }

  Future<Position?> _lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
