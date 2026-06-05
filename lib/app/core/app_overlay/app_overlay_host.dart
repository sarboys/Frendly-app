import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/app/core/app_overlay/app_overlay_controller.dart';
import 'package:mobile2/app/core/app_overlay/app_overlay_dialog.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:url_launcher/url_launcher.dart';

class AppOverlayHost extends ConsumerStatefulWidget {
  const AppOverlayHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AppOverlayHost> createState() => _AppOverlayHostState();
}

class _AppOverlayHostState extends ConsumerState<AppOverlayHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(appOverlayControllerProvider.notifier).checkNow(force: true),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    unawaited(ref.read(appOverlayControllerProvider.notifier).checkNow());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      final controller = ref.read(appOverlayControllerProvider.notifier);
      if (next == null) {
        controller.clear();
        return;
      }
      unawaited(controller.checkNow(force: true));
    });

    final overlay = ref.watch(
      appOverlayControllerProvider.select((state) => state.overlay),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (overlay != null)
          AppOverlayDialog(
            overlay: overlay,
            onDismiss: () {
              unawaited(
                ref
                    .read(appOverlayControllerProvider.notifier)
                    .dismissCurrent(),
              );
            },
            onCta: () {
              unawaited(_handleCta(context, overlay));
            },
          ),
      ],
    );
  }

  Future<void> _handleCta(BuildContext context, AppOverlay overlay) async {
    await ref.read(appOverlayControllerProvider.notifier).recordCtaClick();
    if (!context.mounted) {
      return;
    }
    final cta = overlay.cta;
    if (cta == null || cta.value.trim().isEmpty) {
      return;
    }
    if (cta.action == 'app_route') {
      context.go(cta.value);
      return;
    }
    final uri = Uri.tryParse(cta.value);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
