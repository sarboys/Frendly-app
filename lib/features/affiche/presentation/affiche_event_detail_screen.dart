import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AfficheEventDetailScreen extends ConsumerWidget {
  const AfficheEventDetailScreen({
    required this.eventId,
    super.key,
  });

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(afficheEventDetailProvider(eventId));
    return BbV5Scaffold(
      child: eventAsync.when(
        data: (event) => _AfficheEventDetailBody(event: event),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(LucideIcons.chevron_left, size: 24),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('Событие не найдено', style: AppTextStyles.body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AfficheEventDetailBody extends StatelessWidget {
  const _AfficheEventDetailBody({required this.event});

  final AfficheEvent event;

  @override
  Widget build(BuildContext context) {
    final actionUrl = event.actionUrl;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _AfficheDetailHeader(event: event),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 180),
                    sliver: SliverList.list(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [BbV5Colors.paperHi, BbV5Colors.paper],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: BbV5Colors.hair),
                            boxShadow: BbV5Shadows.card,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AfficheHeroTicket(event: event),
                              const _TicketPerforation(),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _InfoTile(
                                            icon: LucideIcons.calendar,
                                            label: 'Когда',
                                            value: event.dateLabel ?? '',
                                            subtitle: event.timeLabel,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: _InfoTile(
                                            icon: LucideIcons.map_pin,
                                            label: 'Где',
                                            value: event.venue ?? event.city,
                                            subtitle: event.address,
                                            onTap: () =>
                                                _showMapOptions(context, event),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: _InfoTile(
                                            icon: LucideIcons.clock,
                                            label: 'От тебя',
                                            value: 'Рядом',
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: _InfoTile(
                                            icon: LucideIcons.ticket,
                                            label: 'Цена',
                                            value: event.priceLabel,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (event.tags.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: event.tags
                                            .map((tag) => _TagPill(label: tag))
                                            .toList(growable: false),
                                      ),
                                    ],
                                    if ((event.description ?? '')
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      const BbV5Kicker('О событии'),
                                      const SizedBox(height: 8),
                                      Text(
                                        event.description!,
                                        style: AppTextStyles.bodySoft.copyWith(
                                          color: BbV5Colors.inkSoft,
                                          fontSize: 13,
                                          height: 1.625,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    const _TogetherCallout(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00F1E6D6),
                    Color(0xF2F1E6D6),
                    BbV5Colors.paper,
                  ],
                  stops: [0, 0.30, 1],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BbV5PillButton(
                            label: 'Собрать компанию',
                            icon: LucideIcons.users,
                            onPressed: () => context.pushRoute(
                              AppRoute.createMeetup,
                              queryParameters: {'afficheEventId': event.id},
                            ),
                            height: 48,
                            fontSize: 13,
                            expanded: true,
                          ),
                          if (actionUrl != null && actionUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            BbV5PillButton(
                              label: '${event.ctaLabel} · ${event.priceLabel}',
                              icon: event.isPaid
                                  ? LucideIcons.ticket
                                  : LucideIcons.external_link,
                              dark: true,
                              onPressed: () => _openAction(context, actionUrl),
                              height: 56,
                              fontSize: 14,
                              expanded: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAction(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка недоступна.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не получилось открыть сайт.')),
    );
  }

  Future<void> _showMapOptions(BuildContext context, AfficheEvent event) async {
    final query = event.address?.trim().isNotEmpty == true
        ? '${event.venue ?? ''} ${event.address}'.trim()
        : event.placeLabel;
    if (query.trim().isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = AppColors.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Открыть адрес',
                  style: AppTextStyles.itemTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MapOption(
                  icon: LucideIcons.map,
                  title: 'Google Карты',
                  subtitle: query,
                  onTap: () => _openMapUrl(
                    context,
                    sheetContext,
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': query,
                    }),
                  ),
                ),
                _MapOption(
                  icon: LucideIcons.navigation,
                  title: 'Яндекс Карты',
                  subtitle: query,
                  onTap: () => _openMapUrl(
                    context,
                    sheetContext,
                    Uri.https('yandex.ru', '/maps/', {'text': query}),
                  ),
                ),
                Text(
                  'Откроется внешнее приложение или браузер.',
                  style: AppTextStyles.meta.copyWith(color: colors.inkMute),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMapUrl(
    BuildContext rootContext,
    BuildContext sheetContext,
    Uri uri,
  ) async {
    sheetContext.pop();
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !rootContext.mounted) {
      return;
    }
    ScaffoldMessenger.of(rootContext).showSnackBar(
      const SnackBar(content: Text('Не получилось открыть карты.')),
    );
  }
}

class _AfficheDetailHeader extends StatelessWidget {
  const _AfficheDetailHeader({required this.event});

  final AfficheEvent event;

  @override
  Widget build(BuildContext context) {
    final provider = event.provider ?? event.sourceCode ?? 'Афиша';
    final meta = [
      'Афиша',
      if ((event.dateLabel ?? '').trim().isNotEmpty) event.dateLabel!.trim(),
    ].join(' · ');

    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker(provider),
              const SizedBox(height: 2),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.meta.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BbV5Colors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        BbV5IconButton(
          icon: LucideIcons.share_2,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ссылка скопирована')),
            );
          },
        ),
      ],
    );
  }
}

class _AfficheHeroTicket extends StatelessWidget {
  const _AfficheHeroTicket({required this.event});

  final AfficheEvent event;

  @override
  Widget build(BuildContext context) {
    final time = [
      if ((event.dateLabel ?? '').trim().isNotEmpty) event.dateLabel!.trim(),
      if ((event.timeLabel ?? '').trim().isNotEmpty) event.timeLabel!.trim(),
    ].join(' · ');

    return AspectRatio(
      aspectRatio: 1.4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BbV5Colors.terraSoft, BbV5Colors.brandSoft],
              ),
            ),
          ),
          _HeroImage(event: event),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  BbV5Colors.ink.withValues(alpha: 0.02),
                  BbV5Colors.ink.withValues(alpha: 0.42),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (time.isNotEmpty) ...[
                  BbV5Kicker(
                    time,
                    color: Colors.white.withValues(alpha: 0.80),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  event.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.screenTitle.copyWith(
                    fontFamily: 'Sora',
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketPerforation extends StatelessWidget {
  const _TicketPerforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: BbV5Colors.paperHi),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 7.5,
            child: CustomPaint(
              painter: _DashedLinePainter(),
            ),
          ),
          const Positioned(
            left: -8,
            top: 0,
            child: _PerforationCutout(),
          ),
          const Positioned(
            right: -8,
            top: 0,
            child: _PerforationCutout(),
          ),
        ],
      ),
    );
  }
}

class _PerforationCutout extends StatelessWidget {
  const _PerforationCutout();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BbV5Colors.paper,
        border: Border.all(color: BbV5Colors.hair),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BbV5Colors.hair
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, 0), Offset((x + 6).clamp(0, size.width), 0), paint);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TogetherCallout extends StatelessWidget {
  const _TogetherCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.users,
                size: 16,
                color: BbV5Colors.brand,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Идти веселее вместе',
                  style: AppTextStyles.itemTitle.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Собери компанию из этого события, друзья присоединятся в один клик.',
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkSoft,
              fontSize: 12,
              height: 1.625,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.event});

  final AfficheEvent event;

  @override
  Widget build(BuildContext context) {
    return BbExternalEventImage(
      imageUrl: event.imageUrlFor(BbExternalEventImageUsage.hero),
      usage: BbExternalEventImageUsage.hero,
      fallbackIconSize: 48,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: BbV5Colors.inkMute),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
              if (onTap != null) ...[
                const Spacer(),
                const Icon(
                  LucideIcons.external_link,
                  size: 13,
                  color: BbV5Colors.inkMute,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? 'Не указано' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.itemTitle.copyWith(
              fontFamily: 'Sora',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: BbV5Colors.ink,
            ),
          ),
          if ((subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.meta.copyWith(
                color: BbV5Colors.inkMute,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

class _MapOption extends StatelessWidget {
  const _MapOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: colors.foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.itemTitle.copyWith(
                        fontSize: 13.5,
                        height: 1.25,
                        letterSpacing: -0.27,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: AppRadii.pillBorder,
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Text(
        '#$label',
        style: AppTextStyles.meta.copyWith(
          color: BbV5Colors.inkSoft,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
