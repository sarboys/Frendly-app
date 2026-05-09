import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class AfficheEventCard extends StatelessWidget {
  const AfficheEventCard({
    required this.event,
    super.key,
    this.onTap,
    this.compact = false,
  });

  final AfficheEvent event;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(20);
    final contentPadding = EdgeInsets.symmetric(
      horizontal: compact ? 14 : AppSpacing.md,
      vertical: compact ? 12 : AppSpacing.md,
    );
    final providerTitleGap = compact ? AppSpacing.xs : AppSpacing.sm;
    final titleMetaGap = compact ? 6.0 : AppSpacing.xs;
    final metaGap = compact ? AppSpacing.xxs : 6.0;
    return SizedBox(
      width: compact ? 252 : null,
      height: compact ? 276 : null,
      child: Material(
        color: colors.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: radius,
              border: Border.all(color: colors.border),
              boxShadow: compact ? AppShadows.soft : AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AfficheImage(event: event, compact: compact),
                Padding(
                  padding: contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _PricePill(event: event),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              event.provider ?? event.sourceCode ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(
                                color: colors.inkMute,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: providerTitleGap),
                      Text(
                        event.title,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.itemTitle.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 15 : 17,
                        ),
                      ),
                      SizedBox(height: titleMetaGap),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.calendar_days,
                            size: 14,
                            color: colors.inkMute,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              [
                                event.dateLabel,
                                event.timeLabel,
                              ]
                                  .whereType<String>()
                                  .where((item) => item.trim().isNotEmpty)
                                  .join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(
                                color: colors.inkSoft,
                                fontSize: compact ? 12 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: metaGap),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.map_pin,
                            size: 14,
                            color: colors.inkMute,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.placeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(
                                color: colors.inkSoft,
                                fontSize: compact ? 12 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _AfficheImage extends StatelessWidget {
  const _AfficheImage({
    required this.event,
    required this.compact,
  });

  final AfficheEvent event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AspectRatio(
      aspectRatio: compact ? 1.75 : 2.2,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.secondarySoft),
        child: BbExternalEventImage(
          usage: compact
              ? BbExternalEventImageUsage.rail
              : BbExternalEventImageUsage.card,
          imageUrl: event.imageUrlFor(
            compact
                ? BbExternalEventImageUsage.rail
                : BbExternalEventImageUsage.card,
          ),
          fallbackIconSize: compact ? 32 : 40,
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.event});

  final AfficheEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: event.isFree
            ? colors.online.withValues(alpha: 0.12)
            : colors.foreground,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Text(
        event.compactPriceLabel,
        style: AppTextStyles.caption.copyWith(
          color: event.isFree ? colors.online : colors.background,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
