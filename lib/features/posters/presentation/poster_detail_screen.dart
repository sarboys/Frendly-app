import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/posters/presentation/widgets/poster_card.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class PosterDetailScreen extends ConsumerWidget {
  const PosterDetailScreen({
    required this.posterId,
    super.key,
  });

  final String posterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posterAsync = ref.watch(posterDetailProvider(posterId));

    return BbV5Scaffold(
      child: posterAsync.when(
        data: (poster) => _PosterDetailBody(poster: poster),
        loading: () => const _PosterDetailState(
          icon: LucideIcons.ticket,
          title: 'Загружаем событие',
          message: 'Проверяем билеты и площадку.',
          loading: true,
        ),
        error: (_, __) => _PosterDetailState(
          icon: LucideIcons.search_x,
          title: 'Событие не найдено',
          message: 'Постер мог пропасть из афиши.',
          onBack: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

class _PosterDetailBody extends StatelessWidget {
  const _PosterDetailBody({required this.poster});

  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _PosterDetailHeader(
                        poster: poster,
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 168),
                    sliver: SliverToBoxAdapter(
                      child: _PosterTicketPanel(poster: poster),
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
            child: _StickyActions(
              poster: poster,
              onOpenTickets: () => _openTickets(context, poster.ticketUrl),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTickets(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не получилось открыть сайт с билетами.')),
    );
  }
}

class _PosterDetailHeader extends StatelessWidget {
  const _PosterDetailHeader({
    required this.poster,
    required this.onBack,
  });

  final Poster poster;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker(poster.provider),
              const SizedBox(height: 2),
              Text(
                'Афиша · ${poster.displayDateLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.itemTitle.copyWith(
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

class _PosterTicketPanel extends StatelessWidget {
  const _PosterTicketPanel({required this.poster});

  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: EdgeInsets.zero,
      radius: BbV5Radii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: _PosterDetailStage(poster: poster),
          ),
          const PosterTicketPerforation(
            height: 16,
            backgroundColor: BbV5Colors.paper,
            cardColor: BbV5Colors.paperHi,
            borderColor: BbV5Colors.hair,
            inset: 20,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _InfoTile(
                            icon: LucideIcons.calendar_days,
                            label: 'Когда',
                            value: poster.displayDateLabel,
                            subtitle: poster.timeLabel,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _InfoTile(
                            icon: LucideIcons.map_pin,
                            label: 'Где',
                            value: poster.venue,
                            subtitle: poster.address,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _InfoTile(
                            icon: LucideIcons.clock_3,
                            label: 'От тебя',
                            value: poster.distance,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _InfoTile(
                            icon: LucideIcons.ticket,
                            label: 'Цена',
                            value: poster.priceLabel,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (poster.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: poster.tags
                        .map((tag) => _TagPill(label: tag))
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 22),
                const BbV5Kicker('О событии'),
                const SizedBox(height: 8),
                Text(
                  poster.description,
                  style: AppTextStyles.bodySoft.copyWith(
                    color: BbV5Colors.inkSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                const _CompanyPromptCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterDetailStage extends StatelessWidget {
  const _PosterDetailStage({required this.poster});

  final Poster poster;

  @override
  Widget build(BuildContext context) {
    final imageUrl = poster.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BbV5Colors.terraSoft, BbV5Colors.brandSoft],
        ),
      ),
      child: Stack(
        children: [
          if (hasImage)
            Positioned.fill(
              child: BbExternalEventImage(
                imageUrl: imageUrl,
                usage: BbExternalEventImageUsage.hero,
              ),
            )
          else
            Positioned(
              top: 20,
              right: 20,
              child: Text(
                poster.emoji,
                style: TextStyle(
                  fontSize: 118,
                  height: 1,
                  color: BbV5Colors.ink.withValues(alpha: 0.9),
                  shadows: [
                    Shadow(
                      color: BbV5Colors.ink.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
            ),
          if (hasImage)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.52),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 106,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BbV5Kicker(
                  '${poster.displayDateLabel} · ${poster.timeLabel}',
                  color: hasImage
                      ? Colors.white.withValues(alpha: 0.78)
                      : BbV5Colors.inkSoft,
                  maxLines: 1,
                ),
                const SizedBox(height: 7),
                Text(
                  poster.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5DisplayStyle(
                    fontSize: 24,
                    height: 1.12,
                    color: hasImage ? Colors.white : BbV5Colors.ink,
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.all(12),
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
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySoft.copyWith(
              fontFamily: 'Sora',
              fontSize: 13,
              color: BbV5Colors.ink,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: AppTextStyles.meta.copyWith(
                fontSize: 11,
                color: BbV5Colors.inkMute,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
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
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$label',
        style: AppTextStyles.meta.copyWith(
          fontSize: 10.5,
          color: BbV5Colors.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CompanyPromptCard extends StatelessWidget {
  const _CompanyPromptCard();

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
              const SizedBox(width: 7),
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
            'Собери компанию из этого события. Друзья присоединятся в один клик.',
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyActions extends StatelessWidget {
  const _StickyActions({
    required this.poster,
    required this.onOpenTickets,
  });

  final Poster poster;
  final VoidCallback onOpenTickets;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BbV5Colors.paper.withValues(alpha: 0),
            BbV5Colors.paper.withValues(alpha: 0.95),
          ],
          stops: const [0, 0.3],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: BbV5Colors.paperHi,
                      foregroundColor: BbV5Colors.ink,
                      shape: const StadiumBorder(
                        side: BorderSide(color: BbV5Colors.hair),
                      ),
                    ),
                    onPressed: () => context.pushRoute(
                      AppRoute.createMeetup,
                      queryParameters: {'posterId': poster.id},
                    ),
                    icon: const Icon(LucideIcons.users, size: 17),
                    label: Text(
                      'Собрать компанию',
                      style: AppTextStyles.button.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        color: BbV5Colors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: BbV5Colors.ink,
                      foregroundColor: BbV5Colors.paperHi,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onOpenTickets,
                    icon: const Icon(LucideIcons.ticket, size: 20),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Купить билет · ${poster.priceLabel}',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.button.copyWith(
                              fontFamily: 'Sora',
                              fontSize: 14,
                              color: BbV5Colors.paperHi,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.external_link, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Откроется сайт ${poster.provider}',
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterDetailState extends StatelessWidget {
  const _PosterDetailState({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.onBack,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BbV5Page(
      child: Column(
        children: [
          Row(
            children: [
              BbV5IconButton(
                icon: LucideIcons.arrow_left,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const Spacer(),
          BbV5Card(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BbV5Colors.ink,
                    ),
                  )
                else
                  Icon(icon, size: 28, color: BbV5Colors.inkSoft),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: bbV5DisplayStyle(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkMute,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
