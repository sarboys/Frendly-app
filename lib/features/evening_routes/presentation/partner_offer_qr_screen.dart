import 'dart:async';
import 'dart:math' as math;

import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/partner_offer_code.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PartnerOfferQrScreen extends ConsumerStatefulWidget {
  const PartnerOfferQrScreen({
    required this.codeId,
    super.key,
  });

  final String codeId;

  @override
  ConsumerState<PartnerOfferQrScreen> createState() =>
      _PartnerOfferQrScreenState();
}

class _PartnerOfferQrScreenState extends ConsumerState<PartnerOfferQrScreen> {
  Timer? _pollTimer;
  PartnerOfferCode? _code;
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;
  CancelToken? _loadCancelToken;

  @override
  void initState() {
    super.initState();
    unawaited(_load(initial: true));
  }

  @override
  void dispose() {
    _stopPolling();
    _cancelLoad('partner_offer_qr_disposed');
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (_refreshing) {
      return;
    }
    _cancelLoad('partner_offer_qr_load_replaced');
    final cancelToken = CancelToken();
    _loadCancelToken = cancelToken;
    _refreshing = true;
    if (initial && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repository = ref.read(backendRepositoryProvider);
      final code = await repository.fetchPartnerOfferCode(
        widget.codeId,
        cancelToken: cancelToken,
      );
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_loadCancelToken, cancelToken)) {
        return;
      }
      setState(() {
        _code = code;
        _error = null;
        _loading = false;
      });
      if (code.status == PartnerOfferCodeStatus.issued) {
        _startPolling();
      } else {
        _stopPolling();
      }
    } catch (error) {
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_loadCancelToken, cancelToken)) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
      _stopPolling();
    } finally {
      if (identical(_loadCancelToken, cancelToken)) {
        _loadCancelToken = null;
      }
      _refreshing = false;
    }
  }

  void _startPolling() {
    if (_pollTimer != null) {
      return;
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_load()),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _cancelLoad(String reason) {
    final cancelToken = _loadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BbV5Scaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  BbV5TopBar(
                    kicker: 'ОФФЕР',
                    title: 'QR код',
                    onBack: () => context.pop(),
                    right: BbV5IconButton(
                      icon: LucideIcons.rotate_cw,
                      onPressed: _refreshing
                          ? null
                          : () => unawaited(_load(initial: true)),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _content(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const CircularProgressIndicator(color: BbV5Colors.accent);
    }
    if (_error != null || _code == null) {
      return _MessageState(
        icon: LucideIcons.triangle_alert,
        title: 'Не получилось загрузить QR',
        text: 'Проверь соединение и попробуй снова',
        actionLabel: 'Повторить',
        onAction: () => unawaited(_load(initial: true)),
      );
    }

    final code = _code!;
    final status = _statusMeta(code.status);
    final qrSize = math.min(MediaQuery.sizeOf(context).width - 88, 300.0);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: qrSize + 28,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(BbV5Radii.lg),
              border: Border.all(color: BbV5Colors.hair),
              boxShadow: BbV5Shadows.card,
            ),
            child: QrImageView(
              data: code.codeUrl,
              version: QrVersions.auto,
              size: qrSize,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: status.background,
              borderRadius: BorderRadius.circular(BbV5Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 15, color: status.foreground),
                const SizedBox(width: 6),
                Text(
                  status.label,
                  style: AppTextStyles.caption.copyWith(
                    color: status.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            code.offerTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: bbV5DisplayStyle(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            code.venueName.isNotEmpty ? code.venueName : code.partnerName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: BbV5Colors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Действует до ${_timeLabel(context, code.expiresAt)}',
            style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: BbV5Colors.inkMute),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: bbV5DisplayStyle(fontSize: 20)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: BbV5Colors.inkSoft),
        ),
        const SizedBox(height: AppSpacing.md),
        BbV5PillButton(
          label: actionLabel,
          onPressed: onAction,
        ),
      ],
    );
  }
}

class _StatusMeta {
  const _StatusMeta({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
}

_StatusMeta _statusMeta(PartnerOfferCodeStatus status) {
  switch (status) {
    case PartnerOfferCodeStatus.activated:
      return const _StatusMeta(
        label: 'Использован',
        icon: LucideIcons.circle_check,
        foreground: BbV5Colors.sage,
        background: BbV5Colors.brandSoft,
      );
    case PartnerOfferCodeStatus.expired:
      return const _StatusMeta(
        label: 'Истек',
        icon: LucideIcons.clock_3,
        foreground: BbV5Colors.accentDeep,
        background: BbV5Colors.terraSoft,
      );
    case PartnerOfferCodeStatus.issued:
      return const _StatusMeta(
        label: 'Активен',
        icon: LucideIcons.badge_percent,
        foreground: BbV5Colors.accent,
        background: BbV5Colors.paperHi,
      );
  }
}

String _timeLabel(BuildContext context, DateTime value) {
  return TimeOfDay.fromDateTime(value.toLocal()).format(context);
}
