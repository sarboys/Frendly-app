import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef AppOverlayFetcher = Future<AppOverlayResponse> Function(
  AppBuildInfo info,
);

typedef AppOverlayEventRecorder = Future<void> Function(
  AppOverlayEventInput input,
);

class AppOverlayEventInput {
  const AppOverlayEventInput({
    required this.overlayId,
    required this.source,
    required this.event,
  });

  final String overlayId;
  final String source;
  final String event;
}

class AppOverlayState {
  const AppOverlayState({
    this.overlay,
    this.loading = false,
  });

  final AppOverlay? overlay;
  final bool loading;

  AppOverlayState copyWith({
    AppOverlay? overlay,
    bool clearOverlay = false,
    bool? loading,
  }) {
    return AppOverlayState(
      overlay: clearOverlay ? null : overlay ?? this.overlay,
      loading: loading ?? this.loading,
    );
  }
}

class AppOverlayController extends StateNotifier<AppOverlayState> {
  AppOverlayController({
    required String? Function() readUserId,
    required Future<AppBuildInfo> Function() loadBuildInfo,
    required AppOverlayFetcher fetchOverlay,
    required AppOverlayEventRecorder recordEvent,
    DateTime Function()? now,
  })  : _readUserId = readUserId,
        _loadBuildInfo = loadBuildInfo,
        _fetchOverlay = fetchOverlay,
        _recordEvent = recordEvent,
        _now = now ?? DateTime.now,
        super(const AppOverlayState());

  final String? Function() _readUserId;
  final Future<AppBuildInfo> Function() _loadBuildInfo;
  final AppOverlayFetcher _fetchOverlay;
  final AppOverlayEventRecorder _recordEvent;
  final DateTime Function() _now;

  final Set<String> _dismissedCampaignIds = <String>{};
  final Set<String> _impressedOverlayIds = <String>{};
  DateTime? _nextCheckAt;
  bool _checking = false;

  Future<void> checkNow({bool force = false}) async {
    if (_readUserId() == null) {
      clear();
      return;
    }
    final now = _now();
    if (!force && _nextCheckAt != null && now.isBefore(_nextCheckAt!)) {
      return;
    }
    if (_checking) {
      return;
    }
    _checking = true;
    state = state.copyWith(loading: true);
    try {
      final buildInfo = await _loadBuildInfo();
      final response = await _fetchOverlay(buildInfo);
      _nextCheckAt = now.add(
        Duration(seconds: _normalizedCheckDelay(response.checkAfterSeconds)),
      );
      final overlay = response.overlay;
      if (overlay == null || _isDismissedForSession(overlay)) {
        state = state.copyWith(clearOverlay: true, loading: false);
        return;
      }
      state = AppOverlayState(overlay: overlay, loading: false);
      await _recordImpressionOnce(overlay);
    } catch (_) {
      _nextCheckAt = now.add(const Duration(seconds: 300));
      state = state.copyWith(clearOverlay: true, loading: false);
    } finally {
      _checking = false;
      state = state.copyWith(loading: false);
    }
  }

  Future<void> dismissCurrent() async {
    final overlay = state.overlay;
    if (overlay == null) {
      return;
    }
    await _safeRecordEvent(overlay, 'dismiss');
    if (!overlay.dismissible) {
      return;
    }
    if (overlay.isCampaign) {
      _dismissedCampaignIds.add(overlay.id);
    }
    state = state.copyWith(clearOverlay: true);
  }

  Future<void> recordCtaClick() async {
    final overlay = state.overlay;
    if (overlay == null) {
      return;
    }
    await _safeRecordEvent(overlay, 'cta_click');
  }

  void clear() {
    _nextCheckAt = null;
    state = state.copyWith(clearOverlay: true, loading: false);
  }

  bool _isDismissedForSession(AppOverlay overlay) {
    return overlay.isCampaign && _dismissedCampaignIds.contains(overlay.id);
  }

  Future<void> _recordImpressionOnce(AppOverlay overlay) async {
    if (!_impressedOverlayIds.add(overlay.id)) {
      return;
    }
    await _safeRecordEvent(overlay, 'impression');
  }

  Future<void> _safeRecordEvent(AppOverlay overlay, String event) async {
    try {
      await _recordEvent(
        AppOverlayEventInput(
          overlayId: overlay.id,
          source: overlay.source,
          event: event,
        ),
      );
    } catch (_) {}
  }

  int _normalizedCheckDelay(int seconds) {
    if (seconds <= 0) {
      return 300;
    }
    return seconds;
  }
}

final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return AppBuildInfo(
    platform: _currentAppPlatform(),
    buildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
  );
});

final appOverlayControllerProvider =
    StateNotifierProvider<AppOverlayController, AppOverlayState>((ref) {
  return AppOverlayController(
    readUserId: () => ref.read(currentUserIdProvider),
    loadBuildInfo: () => ref.read(appBuildInfoProvider.future),
    fetchOverlay: (info) {
      return ref.read(backendRepositoryProvider).fetchAppOverlay(
            platform: info.platform,
            buildNumber: info.buildNumber,
          );
    },
    recordEvent: (input) async {
      await ref.read(backendRepositoryProvider).recordAppOverlayEvent(
            overlayId: input.overlayId,
            source: input.source,
            event: input.event,
          );
    },
  );
});

String _currentAppPlatform() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'android',
  };
}
