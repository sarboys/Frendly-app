import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

enum OnboardingPermissionRequestResult {
  granted,
  denied,
  permanentlyDenied,
  unavailable,
  error,
}

abstract class OnboardingPermissionService {
  Future<OnboardingPermissionRequestResult> requestLocation();
  Future<OnboardingPermissionRequestResult> requestPush();
  Future<OnboardingPermissionRequestResult> requestContacts();
}

final onboardingPermissionServiceProvider =
    Provider<OnboardingPermissionService>(
  (ref) => _DefaultOnboardingPermissionService(ref),
);

class _DefaultOnboardingPermissionService
    implements OnboardingPermissionService {
  const _DefaultOnboardingPermissionService(this._ref);

  final Ref _ref;

  bool get _isMobile {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
  }

  @override
  Future<OnboardingPermissionRequestResult> requestLocation() async {
    if (!_isMobile) {
      return OnboardingPermissionRequestResult.unavailable;
    }
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return OnboardingPermissionRequestResult.unavailable;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      return switch (permission) {
        geo.LocationPermission.always ||
        geo.LocationPermission.whileInUse =>
          OnboardingPermissionRequestResult.granted,
        geo.LocationPermission.denied =>
          OnboardingPermissionRequestResult.denied,
        geo.LocationPermission.deniedForever => await _openLocationSettings(),
        geo.LocationPermission.unableToDetermine =>
          OnboardingPermissionRequestResult.error,
      };
    } catch (_) {
      return OnboardingPermissionRequestResult.error;
    }
  }

  Future<OnboardingPermissionRequestResult> _openLocationSettings() async {
    try {
      await geo.Geolocator.openAppSettings();
    } catch (_) {}
    return OnboardingPermissionRequestResult.permanentlyDenied;
  }

  @override
  Future<OnboardingPermissionRequestResult> requestPush() async {
    if (!_isMobile) {
      return OnboardingPermissionRequestResult.unavailable;
    }
    try {
      await _ref.read(settingsActionsProvider).setPushEnabled(true);
      return OnboardingPermissionRequestResult.granted;
    } catch (error) {
      final message = error.toString();
      if (message.contains('push_unavailable')) {
        return OnboardingPermissionRequestResult.unavailable;
      }
      return OnboardingPermissionRequestResult.error;
    }
  }

  @override
  Future<OnboardingPermissionRequestResult> requestContacts() async {
    if (!_isMobile) {
      return OnboardingPermissionRequestResult.unavailable;
    }
    try {
      final status = await permissions.Permission.contacts.request();
      if (status.isGranted || status.isLimited) {
        return OnboardingPermissionRequestResult.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        try {
          await permissions.openAppSettings();
        } catch (_) {}
        return OnboardingPermissionRequestResult.permanentlyDenied;
      }
      return OnboardingPermissionRequestResult.denied;
    } catch (_) {
      return OnboardingPermissionRequestResult.error;
    }
  }
}
