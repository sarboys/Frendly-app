import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/app_overlay/app_overlay_controller.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('does not request overlay without authenticated user', () async {
    var fetchCount = 0;
    final controller = AppOverlayController(
      readUserId: () => null,
      loadBuildInfo: () async => const AppBuildInfo(
        platform: 'ios',
        buildNumber: 10,
      ),
      fetchOverlay: (_) async {
        fetchCount += 1;
        return const AppOverlayResponse(overlay: null, checkAfterSeconds: 300);
      },
      recordEvent: (_) async {},
    );

    await controller.checkNow(force: true);

    expect(fetchCount, 0);
    expect(controller.state.overlay, isNull);
  });

  test('keeps dismissed campaign hidden during current app session', () async {
    var fetchCount = 0;
    final controller = AppOverlayController(
      readUserId: () => 'user-1',
      loadBuildInfo: () async => const AppBuildInfo(
        platform: 'android',
        buildNumber: 12,
      ),
      fetchOverlay: (_) async {
        fetchCount += 1;
        return const AppOverlayResponse(
          checkAfterSeconds: 300,
          overlay: AppOverlay(
            id: 'campaign-1',
            source: 'campaign',
            kind: 'announcement',
            title: 'Новость',
            body: 'Текст',
            dismissible: true,
            cta: null,
          ),
        );
      },
      recordEvent: (_) async {},
    );

    await controller.checkNow(force: true);
    expect(controller.state.overlay?.id, 'campaign-1');

    await controller.dismissCurrent();
    expect(controller.state.overlay, isNull);

    await controller.checkNow(force: true);
    expect(fetchCount, 2);
    expect(controller.state.overlay, isNull);
  });

  test('throttles repeated checks and allows forced checks', () async {
    var now = DateTime(2026, 5, 23, 10);
    var fetchCount = 0;
    final controller = AppOverlayController(
      readUserId: () => 'user-1',
      now: () => now,
      loadBuildInfo: () async => const AppBuildInfo(
        platform: 'ios',
        buildNumber: 50,
      ),
      fetchOverlay: (_) async {
        fetchCount += 1;
        return const AppOverlayResponse(overlay: null, checkAfterSeconds: 300);
      },
      recordEvent: (_) async {},
    );

    await controller.checkNow();
    await controller.checkNow();
    expect(fetchCount, 1);

    now = now.add(const Duration(minutes: 6));
    await controller.checkNow();
    expect(fetchCount, 2);

    await controller.checkNow(force: true);
    expect(fetchCount, 3);
  });

  test('keeps app usable when overlay request fails', () async {
    var fetchCount = 0;
    final controller = AppOverlayController(
      readUserId: () => 'user-1',
      loadBuildInfo: () async => const AppBuildInfo(
        platform: 'ios',
        buildNumber: 50,
      ),
      fetchOverlay: (_) async {
        fetchCount += 1;
        throw StateError('network failed');
      },
      recordEvent: (_) async {},
    );

    await controller.checkNow(force: true);

    expect(fetchCount, 1);
    expect(controller.state.overlay, isNull);
    expect(controller.state.loading, false);
  });
}
