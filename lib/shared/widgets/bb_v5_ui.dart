import 'dart:ui';

import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

class BbV5Colors {
  const BbV5Colors._();

  static const paper = Color(0xFFF1E6D6);
  static const paperDeep = Color(0xFFE8D6BE);
  static const paperHi = Color(0xFFFBF3E6);
  static const ink = Color(0xFF1B1A18);
  static const inkSoft = Color(0xFF3F3A34);
  static const inkMute = Color(0xFF8A7E72);
  static const brand = Color(0xFF6F8B72);
  static const brandDeep = Color(0xFF4F6A53);
  static const brandSoft = Color(0xFFC9D5BE);
  static const terra = Color(0xFFC97A55);
  static const terraSoft = Color(0xFFEBC0A0);
  static const accent = Color(0xFFD08A63);
  static const accentDeep = Color(0xFFB26F4A);
  static const sage = Color(0xFF6F8B72);
  static const sageDeep = Color(0xFF4F6A53);
  static const gold = Color(0xFFC99A55);
  static const rose = Color(0xFFD89A8E);

  static const hair = Color(0x1A3C281C);
  static const hairSoft = Color(0x0F3C281C);
}

class BbV5AfterDarkColors {
  const BbV5AfterDarkColors._();

  static const background = Color(0xFF0E0817);
  static const backgroundDeep = Color(0xFF070310);
  static const surface = Color(0x0AFFFFFF);
  static const surfaceHi = Color(0x12FFFFFF);
  static const border = Color(0x1AFFFFFF);
  static const foreground = Color(0xFFF2EAFE);
  static const foregroundSoft = Color(0xFFC8B8DC);
  static const foregroundMute = Color(0xFF7E6E94);
  static const magenta = Color(0xFFE94BB8);
  static const violet = Color(0xFF8B5CF6);
  static const violetDeep = Color(0xFF5B21B6);
  static const cyan = Color(0xFF2FE3FF);

  static const neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta],
  );

  static const glowShadow = [
    BoxShadow(
      color: Color(0x592FE3FF),
      blurRadius: 24,
      spreadRadius: -12,
      offset: Offset(0, 10),
    ),
  ];

  static const neonShadow = [
    BoxShadow(
      color: Color(0x808B5CF6),
      blurRadius: 32,
      spreadRadius: -8,
      offset: Offset(0, 12),
    ),
  ];

  static const cardShadow = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 32,
      spreadRadius: -16,
      offset: Offset(0, 18),
    ),
  ];
}

class BbV5Radii {
  const BbV5Radii._();

  static const sm = 14.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const pill = 999.0;
}

class BbV5Shadows {
  const BbV5Shadows._();

  static const card = [
    BoxShadow(
      color: Color(0x381F241D),
      blurRadius: 48,
      spreadRadius: -28,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: Color(0x0A1F241D),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
  ];

  static const pill = [
    BoxShadow(
      color: Color(0x4D1F241D),
      blurRadius: 14,
      spreadRadius: -10,
      offset: Offset(0, 6),
    ),
  ];

  static const ink = [
    BoxShadow(
      color: Color(0x801F241D),
      blurRadius: 28,
      spreadRadius: -10,
      offset: Offset(0, 12),
    ),
  ];

  static const nav = [
    BoxShadow(
      color: Color(0x2E1F241D),
      blurRadius: 40,
      spreadRadius: -8,
      offset: Offset(0, -12),
    ),
  ];
}

TextStyle bbV5KickerStyle({
  Color color = BbV5Colors.inkMute,
  double fontSize = 10,
  double letterSpacing = 2.4,
  FontWeight fontWeight = FontWeight.w500,
}) {
  return AppTextStyles.caption.copyWith(
    fontFamily: 'Sora',
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: 1.1,
    letterSpacing: letterSpacing,
    color: color,
  );
}

TextStyle bbV5DisplayStyle({
  double fontSize = 22,
  double height = 1.1,
  FontWeight fontWeight = FontWeight.w600,
  double? letterSpacing,
  Color color = BbV5Colors.ink,
}) {
  return AppTextStyles.screenTitle.copyWith(
    fontFamily: 'Sora',
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing ?? -fontSize * 0.02,
    color: color,
  );
}

class BbV5WarmBackground extends StatelessWidget {
  const BbV5WarmBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF6E2CC),
                BbV5Colors.paper,
                Color(0xFFECDFCB),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          right: -96,
          top: -92,
          width: 330,
          height: 240,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFF2C9A8), Color(0x00F2C9A8)],
              ),
            ),
          ),
        ),
        Positioned(
          left: -120,
          top: 80,
          width: 320,
          height: 230,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFF5DCC2), Color(0x00F5DCC2)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -160,
          height: 390,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFEBD2B4), Color(0x00EBD2B4)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BbV5Scaffold extends StatelessWidget {
  const BbV5Scaffold({
    required this.child,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = false,
    super.key,
  });

  final Widget child;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BbV5Colors.paper,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          const Positioned.fill(child: BbV5WarmBackground()),
          Positioned.fill(
            child: DefaultTextStyle.merge(
              style: AppTextStyles.body.copyWith(color: BbV5Colors.ink),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class BbV5Page extends StatelessWidget {
  const BbV5Page({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 32, 20, 32),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: AppTextStyles.body.copyWith(color: BbV5Colors.ink),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class BbV5FixedBottomBar extends StatelessWidget {
  const BbV5FixedBottomBar({
    required this.child,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.fadeStop = 0.4,
    super.key,
  }) : assert(fadeStop >= 0 && fadeStop <= 1);

  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry padding;
  final double fadeStop;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BbV5Colors.paper.withValues(alpha: 0),
            BbV5Colors.paper.withValues(alpha: 0.96),
            BbV5Colors.paper,
          ],
          stops: [0, fadeStop, 1],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: padding.add(EdgeInsets.only(bottom: bottom)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BbV5Card extends StatelessWidget {
  const BbV5Card({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = BbV5Radii.lg,
    this.tint,
    this.borderColor = BbV5Colors.hair,
    this.clip = Clip.antiAlias,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final Color borderColor;
  final Clip clip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: clip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BbV5Colors.paperHi, BbV5Colors.paper],
          ),
          border: Border.all(color: borderColor),
          boxShadow: BbV5Shadows.card,
        ),
        child: Stack(
          children: [
            if (tint != null)
              Positioned(
                top: -64,
                right: -64,
                width: 224,
                height: 224,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tint!.withValues(alpha: 0.42),
                        blurRadius: 72,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: AppTextStyles.body.copyWith(color: BbV5Colors.ink),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

class BbV5BottomSheet extends StatelessWidget {
  const BbV5BottomSheet({
    required this.child,
    this.maxHeightFactor = 0.85,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    super.key,
  });

  final Widget child;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * maxHeightFactor;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            constraints: BoxConstraints(maxHeight: height),
            decoration: const BoxDecoration(
              color: BbV5Colors.paper,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(BbV5Radii.lg),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: Offset(0, -20),
                ),
              ],
            ),
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: BbV5Colors.hair,
                      borderRadius: BorderRadius.circular(BbV5Radii.pill),
                    ),
                  ),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BbV5Kicker extends StatelessWidget {
  const BbV5Kicker(
    this.text, {
    this.color = BbV5Colors.inkMute,
    this.maxLines,
    super.key,
  });

  final String text;
  final Color color;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: bbV5KickerStyle(color: color),
    );
  }
}

class BbV5HeroTitle extends StatelessWidget {
  const BbV5HeroTitle({
    required this.title,
    this.accent,
    this.fontSize = 22,
    this.maxLines,
    super.key,
  });

  final String title;
  final String? accent;
  final double fontSize;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final base = bbV5DisplayStyle(
      fontSize: fontSize,
      height: 1.25,
      letterSpacing: -fontSize * 0.02,
    );
    final accentText = accent;
    if (accentText == null || accentText.isEmpty) {
      return Text(
        title,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: base,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: title),
          const TextSpan(text: ' '),
          TextSpan(
            text: accentText,
            style: base.copyWith(
              fontFamily: 'InstrumentSerif',
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      style: base,
    );
  }
}

class BbV5Section extends StatelessWidget {
  const BbV5Section({
    required this.title,
    required this.child,
    this.right,
    this.margin = const EdgeInsets.only(top: 24),
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? right;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: BbV5Kicker(title)),
                if (right != null) right!,
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class BbV5TopBar extends StatelessWidget {
  const BbV5TopBar({
    required this.title,
    this.kicker,
    this.accent,
    this.onBack,
    this.right,
    super.key,
  });

  final String title;
  final String? kicker;
  final String? accent;
  final VoidCallback? onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: onBack ?? () => context.pop(),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker != null) BbV5Kicker(kicker!),
              BbV5HeroTitle(title: title, accent: accent),
            ],
          ),
        ),
        if (right != null) ...[
          const SizedBox(width: AppSpacing.xs),
          right!,
        ],
      ],
    );
  }
}

class BbV5IconButton extends StatelessWidget {
  const BbV5IconButton({
    required this.icon,
    required this.onPressed,
    this.dark = false,
    this.size = 44,
    this.iconSize = 17,
    this.color,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool dark;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? BbV5Colors.accent : BbV5Colors.paperHi,
          shape: BoxShape.circle,
          border: Border.all(color: dark ? BbV5Colors.accent : BbV5Colors.hair),
          boxShadow: dark ? BbV5Shadows.ink : BbV5Shadows.pill,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onPressed,
          icon: BbV5LucideIcon(
            icon,
            size: iconSize,
            color: color ?? (dark ? BbV5Colors.paperHi : BbV5Colors.ink),
          ),
        ),
      ),
    );
  }
}

class BbV5LucideIcon extends StatelessWidget {
  const BbV5LucideIcon(
    this.icon, {
    this.size = 17,
    this.color,
    this.weight = 300,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final int weight;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? IconTheme.of(context).color,
    );
  }
}

class BbV5PillButton extends StatelessWidget {
  const BbV5PillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.dark = false,
    this.height = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.fontSize = 12,
    this.iconSize = 16,
    this.iconGap = 6,
    this.iconColor,
    this.trailingIconColor,
    this.expanded = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool dark;
  final double height;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double iconSize;
  final double iconGap;
  final Color? iconColor;
  final Color? trailingIconColor;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: padding,
          backgroundColor: dark ? BbV5Colors.accent : BbV5Colors.paperHi,
          foregroundColor: dark ? BbV5Colors.paperHi : BbV5Colors.ink,
          disabledBackgroundColor:
              (dark ? BbV5Colors.accent : BbV5Colors.paperHi)
                  .withValues(alpha: 0.45),
          disabledForegroundColor: (dark ? BbV5Colors.paperHi : BbV5Colors.ink)
              .withValues(alpha: 0.45),
          shape: StadiumBorder(
            side: BorderSide(
              color: dark ? BbV5Colors.accent : BbV5Colors.hair,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              BbV5LucideIcon(icon!, size: iconSize, color: iconColor),
              SizedBox(width: iconGap),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: 0,
                  color: dark ? BbV5Colors.paperHi : BbV5Colors.ink,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              SizedBox(width: iconGap),
              BbV5LucideIcon(
                trailingIcon!,
                size: iconSize,
                color: trailingIconColor,
              ),
            ],
          ],
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        boxShadow: dark ? BbV5Shadows.ink : BbV5Shadows.pill,
      ),
      child: button,
    );
  }
}

class BbV5Chip extends StatelessWidget {
  const BbV5Chip({
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
                  letterSpacing: 0.23,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BbV5SearchPill extends StatelessWidget {
  const BbV5SearchPill({
    required this.hintText,
    this.controller,
    this.onChanged,
    this.trailing,
    super.key,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 16,
            color: BbV5Colors.inkMute,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.meta.copyWith(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: BbV5Colors.ink,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTextStyles.meta.copyWith(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: BbV5Colors.inkMute,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class BbV5GlassBottomBar extends StatelessWidget {
  const BbV5GlassBottomBar({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB8F8F4E8),
                  borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.55)),
                  boxShadow: BbV5Shadows.nav,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 32,
                      right: 32,
                      top: 0,
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
