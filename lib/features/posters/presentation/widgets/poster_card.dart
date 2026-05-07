import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

enum PosterCardVariant { feed, compact }

class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.poster,
    super.key,
    this.onTap,
    this.variant = PosterCardVariant.feed,
  });

  final Poster poster;
  final VoidCallback? onTap;
  final PosterCardVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == PosterCardVariant.compact) {
      return SizedBox(
        width: 220,
        child: _PosterTicketCard(
          poster: poster,
          onTap: onTap,
          compact: true,
        ),
      );
    }

    return _PosterTicketCard(
      poster: poster,
      onTap: onTap,
      compact: false,
    );
  }
}

class _PosterTicketCard extends StatelessWidget {
  const _PosterTicketCard({
    required this.poster,
    required this.compact,
    this.onTap,
  });

  final Poster poster;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(24);

    return Material(
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
              _PosterTicketHeader(
                poster: poster,
                compact: compact,
              ),
              PosterTicketPerforation(
                height: compact ? 12 : 12,
                backgroundColor: colors.background,
                cardColor: colors.card,
                borderColor: colors.border.withValues(alpha: 0.7),
                inset: compact ? 12 : 16,
              ),
              _PosterTicketBody(
                poster: poster,
                compact: compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterTicketHeader extends StatelessWidget {
  const _PosterTicketHeader({
    required this.poster,
    required this.compact,
  });

  final Poster poster;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final stamp = poster.dateStamp;
    final imageUrl = poster.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      height: compact ? 120 : 164,
      decoration: BoxDecoration(
        gradient: posterStageGradient(context, poster.tone),
      ),
      child: Stack(
        children: [
          if (hasImage)
            Positioned.fill(
              child: BbExternalEventImage(
                imageUrl: imageUrl,
                usage: compact
                    ? BbExternalEventImageUsage.rail
                    : BbExternalEventImageUsage.card,
              ),
            )
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.85, -0.75),
                    radius: 0.8,
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.72],
                  ),
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
                      Colors.black.withValues(alpha: 0.34),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned(
              left: compact ? 16 : 20,
              bottom: compact ? 6 : 8,
              child: Transform.rotate(
                angle: -0.04,
                child: Text(
                  poster.emoji,
                  style: TextStyle(
                    fontSize: compact ? 68 : 96,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: colors.foreground.withValues(alpha: 0.18),
                        blurRadius: compact ? 14 : 18,
                        offset: Offset(0, compact ? 6 : 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: compact ? 12 : 16,
            left: compact ? 12 : 20,
            child: PosterDateStampBadge(
              dow: stamp.dow,
              day: stamp.day,
              month: stamp.month,
              compact: compact,
            ),
          ),
          if (!compact)
            Positioned(
              top: 16,
              right: 20,
              child: _ProviderChip(provider: poster.provider),
            ),
          Positioned(
            top: compact ? 12 : null,
            right: compact ? 12 : 20,
            bottom: compact ? null : 12,
            child: PosterPriceChip(
              label: compact ? poster.compactPriceLabel : poster.priceLabel,
              free: poster.priceFrom == 0,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

Gradient posterStageGradient(BuildContext context, EventTone tone) {
  final colors = AppColors.of(context);
  final center = switch (tone) {
    EventTone.warm => const Alignment(-0.7, -1),
    EventTone.evening => const Alignment(0.75, -1),
    EventTone.sage => const Alignment(0, -1),
  };
  final base = switch (tone) {
    EventTone.warm => colors.warmStart,
    EventTone.evening => colors.eveningStart,
    EventTone.sage => colors.secondarySoft,
  };
  final end = switch (tone) {
    EventTone.warm => colors.warmEnd,
    EventTone.evening => colors.eveningEnd,
    EventTone.sage => colors.secondary.withValues(alpha: 0.26),
  };

  return RadialGradient(
    center: center,
    radius: 1.25,
    colors: [
      base,
      end,
      end.withValues(alpha: 0.58),
    ],
    stops: const [0, 0.55, 1],
  );
}

class PosterDateStampBadge extends StatelessWidget {
  const PosterDateStampBadge({
    super.key,
    required this.dow,
    required this.day,
    required this.month,
    required this.compact,
  });

  final String dow;
  final String day;
  final String month;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      constraints: BoxConstraints(minWidth: compact ? 46 : 58),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dow.isEmpty ? '·' : dow,
            style: AppTextStyles.caption.copyWith(
              color: colors.inkMute,
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: compact ? 1.2 : 1.5,
              height: 1,
            ),
          ),
          Text(
            day,
            style: AppTextStyles.cardTitle.copyWith(
              color: colors.foreground,
              fontSize: compact ? 18 : 24,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          Text(
            month,
            style: AppTextStyles.caption.copyWith(
              color: colors.inkMute,
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: compact ? 1.2 : 1.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
  });

  final String provider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.85),
        borderRadius: AppRadii.pillBorder,
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        provider,
        style: AppTextStyles.caption.copyWith(
          color: colors.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class PosterPriceChip extends StatelessWidget {
  const PosterPriceChip({
    super.key,
    required this.label,
    required this.free,
    required this.compact,
  });

  final String label;
  final bool free;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color:
            free ? colors.secondary : colors.background.withValues(alpha: 0.9),
        borderRadius: AppRadii.pillBorder,
        border: Border.all(
          color: free ? colors.secondary : colors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: free ? colors.secondaryForeground : colors.foreground,
          fontSize: compact ? 10.5 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class PosterTicketPerforation extends StatelessWidget {
  const PosterTicketPerforation({
    super.key,
    required this.height,
    required this.backgroundColor,
    required this.cardColor,
    required this.borderColor,
    required this.inset,
  });

  final double height;
  final Color backgroundColor;
  final Color cardColor;
  final Color borderColor;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: ColoredBox(color: cardColor)),
          Positioned.fill(
            left: inset,
            right: inset,
            child: CustomPaint(
              painter: _DashedLinePainter(color: borderColor),
            ),
          ),
          Positioned(
            left: -6,
            top: 0,
            child: _PerforationHole(
              color: backgroundColor,
              borderColor: borderColor,
            ),
          ),
          Positioned(
            right: -6,
            top: 0,
            child: _PerforationHole(
              color: backgroundColor,
              borderColor: borderColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerforationHole extends StatelessWidget {
  const _PerforationHole({
    required this.color,
    required this.borderColor,
  });

  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    var startX = 0.0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset((startX + 4).clamp(0, size.width).toDouble(), y),
        paint,
      );
      startX += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PosterTicketBody extends StatelessWidget {
  const _PosterTicketBody({
    required this.poster,
    required this.compact,
  });

  final Poster poster;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shortTag = poster.tags.isEmpty ? null : poster.tags.first;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 20,
        compact ? 4 : 8,
        compact ? 14 : 20,
        compact ? 14 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shortTag != null) ...[
            Text(
              shortTag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: colors.inkMute,
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w600,
                letterSpacing: compact ? 1.25 : 1.6,
              ),
            ),
            SizedBox(height: compact ? 6 : 7),
          ],
          SizedBox(
            height: compact ? 36 : null,
            child: Text(
              poster.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle.copyWith(
                color: colors.foreground,
                fontSize: compact ? 14 : 18,
                fontWeight: FontWeight.w600,
                height: compact ? 1.2 : 1.25,
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: _MetaIconText(
                  icon: LucideIcons.map_pin,
                  label: poster.venue,
                  compact: compact,
                  muted: true,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _MetaIconText(
                icon: LucideIcons.clock_3,
                label: poster.timeLabel,
                compact: compact,
                muted: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaIconText extends StatelessWidget {
  const _MetaIconText({
    required this.icon,
    required this.label,
    required this.compact,
    required this.muted,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = muted ? colors.inkSoft : colors.foreground;

    return Row(
      mainAxisSize: muted ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 12 : 14, color: color),
        SizedBox(width: compact ? 4 : 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta.copyWith(
              color: color,
              fontSize: compact ? 11 : 12.5,
              fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
