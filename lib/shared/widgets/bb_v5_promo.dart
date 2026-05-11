import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class BbV5PromoColors {
  const BbV5PromoColors._();

  static const gold = Color(0xFFC99A55);
  static const goldDeep = Color(0xFF9B6F2B);
  static const goldSoft = Color(0xFFFFE2A8);
  static const goldPale = Color(0xFFFFF3D3);
  static const glow = Color(0x66FFC75F);
}

class BbV5PromoBadge extends StatelessWidget {
  const BbV5PromoBadge({
    this.label = 'ТОП',
    this.compact = false,
    this.dark = true,
    super.key,
  });

  final String label;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? BbV5Colors.paperHi : BbV5PromoColors.goldDeep;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  BbV5PromoColors.goldDeep,
                  BbV5PromoColors.gold,
                  BbV5PromoColors.goldSoft,
                ]
              : const [
                  BbV5PromoColors.goldPale,
                  BbV5PromoColors.goldSoft,
                ],
        ),
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(
          color: dark ? BbV5PromoColors.goldSoft : BbV5PromoColors.gold,
          width: compact ? 1 : 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: BbV5PromoColors.glow,
            blurRadius: 22,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 3 : 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.flame,
              size: compact ? 9 : 11,
              color: foreground,
            ),
            SizedBox(width: compact ? 2 : 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: foreground,
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? 0.8 : 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BbV5PromoFrame extends StatelessWidget {
  const BbV5PromoFrame({
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.onTap,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: BbV5PromoColors.gold, width: 1.4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BbV5PromoColors.goldPale.withValues(alpha: 0.92),
            BbV5Colors.paperHi,
            BbV5Colors.paper,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: BbV5PromoColors.glow,
            blurRadius: 30,
            spreadRadius: -14,
            offset: Offset(0, 16),
          ),
          ...BbV5Shadows.card,
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

class BbV5PromoRibbon extends StatelessWidget {
  const BbV5PromoRibbon({
    this.label = 'Продвигается',
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BbV5PromoColors.goldPale,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5PromoColors.gold),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: bbV5KickerStyle(
            color: BbV5PromoColors.goldDeep,
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class BbV5PromoPulse extends StatelessWidget {
  const BbV5PromoPulse({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 10,
      height: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BbV5PromoColors.gold,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: BbV5PromoColors.glow,
              blurRadius: 14,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class BbV5PromoNote extends StatelessWidget {
  const BbV5PromoNote({
    required this.text,
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BbV5PromoColors.goldPale.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5PromoColors.gold.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BbV5PromoPulse(),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: BbV5PromoColors.goldDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
