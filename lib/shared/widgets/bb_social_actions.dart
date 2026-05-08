import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BbSocialActionsVariant { full, compact, row }

class BbSocialActions extends ConsumerWidget {
  const BbSocialActions({
    required this.userId,
    required this.initialSocial,
    this.variant = BbSocialActionsVariant.full,
    this.enabled = true,
    super.key,
  });

  final String userId;
  final ProfileSocialData initialSocial;
  final BbSocialActionsVariant variant;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (variant == BbSocialActionsVariant.row) {
      return _SocialRow(social: initialSocial);
    }

    final socialAsync = ref.watch(profileSocialProvider(userId));
    final social = socialAsync.valueOrNull ?? initialSocial;
    final controller = ref.read(profileSocialProvider(userId).notifier);

    return switch (variant) {
      BbSocialActionsVariant.compact => _SocialCompact(
          social: social,
          enabled: enabled,
          onFollow: controller.toggleFollow,
          onLike: controller.toggleLike,
        ),
      BbSocialActionsVariant.row => _SocialRow(social: initialSocial),
      BbSocialActionsVariant.full => _SocialFull(
          social: social,
          enabled: enabled,
          onFollow: controller.toggleFollow,
          onLike: controller.toggleLike,
          onSuper: controller.toggleSuper,
        ),
    };
  }
}

class _SocialFull extends StatelessWidget {
  const _SocialFull({
    required this.social,
    required this.enabled,
    required this.onFollow,
    required this.onLike,
    required this.onSuper,
  });

  final ProfileSocialData social;
  final bool enabled;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onSuper;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SocialStat(
                value: _formatSocialCount(social.followers),
                label: 'Подписчики',
                active: social.iFollow,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _SocialStat(
                value: _formatSocialCount(social.likes),
                label: 'Лайков',
                active: social.iLike,
                accent: _SocialAccent.rose,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _SocialStat(
                value: _formatSocialCount(social.superLikes),
                label: 'Супер',
                active: social.iSuper,
                accent: _SocialAccent.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: enabled ? onFollow : null,
                  icon: Icon(
                    social.iFollow
                        ? LucideIcons.user_check
                        : LucideIcons.user_plus,
                    size: 16,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      social.iFollow ? 'Вы подписаны' : 'Подписаться',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        social.iFollow ? colors.foreground : colors.card,
                    foregroundColor:
                        social.iFollow ? colors.background : colors.foreground,
                    disabledBackgroundColor: colors.card,
                    disabledForegroundColor: colors.inkMute,
                    side: BorderSide(
                      color: social.iFollow ? colors.foreground : colors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: AppTextStyles.body.copyWith(
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _SocialIconButton(
              icon: LucideIcons.heart,
              active: social.iLike,
              color: const Color(0xfff43f5e),
              onTap: enabled ? onLike : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            _SocialIconButton(
              icon: LucideIcons.star,
              active: social.iSuper,
              color: const Color(0xfff59e0b),
              onTap: enabled ? onSuper : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialCompact extends StatelessWidget {
  const _SocialCompact({
    required this.social,
    required this.enabled,
    required this.onFollow,
    required this.onLike,
  });

  final ProfileSocialData social;
  final bool enabled;
  final VoidCallback onFollow;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: OutlinedButton.icon(
            onPressed: enabled ? onFollow : null,
            icon: Icon(
              social.iFollow ? LucideIcons.user_check : LucideIcons.user_plus,
              size: 14,
            ),
            label: Text(social.iFollow ? 'Подписан' : 'Подписаться'),
            style: OutlinedButton.styleFrom(
              backgroundColor: social.iFollow ? colors.foreground : colors.card,
              foregroundColor:
                  social.iFollow ? colors.background : colors.foreground,
              side: BorderSide(
                color: social.iFollow ? colors.foreground : colors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _SocialIconButton(
          icon: LucideIcons.heart,
          active: social.iLike,
          color: const Color(0xfff43f5e),
          onTap: enabled ? onLike : null,
          size: 32,
          iconSize: 16,
        ),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.social});

  final ProfileSocialData social;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SocialCountIcon(
          icon: LucideIcons.user_check,
          value: social.followers,
          color: colors.inkSoft,
        ),
        const SizedBox(width: 12),
        _SocialCountIcon(
          icon: LucideIcons.heart,
          value: social.likes,
          color: colors.inkSoft,
        ),
        const SizedBox(width: 12),
        _SocialCountIcon(
          icon: LucideIcons.star,
          value: social.superLikes,
          color: colors.inkSoft,
        ),
      ],
    );
  }
}

class _SocialCountIcon extends StatelessWidget {
  const _SocialCountIcon({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          _formatSocialCount(value),
          style: AppTextStyles.caption.copyWith(
            fontFamily: 'Sora',
            fontSize: 12,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

enum _SocialAccent { neutral, rose, amber }

class _SocialStat extends StatelessWidget {
  const _SocialStat({
    required this.value,
    required this.label,
    required this.active,
    this.accent = _SocialAccent.neutral,
  });

  final String value;
  final String label;
  final bool active;
  final _SocialAccent accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rose = const Color(0xfff43f5e);
    final amber = const Color(0xfff59e0b);
    final activeColor = switch (accent) {
      _SocialAccent.rose => rose,
      _SocialAccent.amber => amber,
      _SocialAccent.neutral => colors.foreground,
    };
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(
                alpha: accent == _SocialAccent.neutral ? 1 : 0.12)
            : colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? activeColor.withValues(
                  alpha: accent == _SocialAccent.neutral ? 1 : 0.35)
              : colors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 15,
              height: 1,
              color: active && accent == _SocialAccent.neutral
                  ? colors.background
                  : colors.foreground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9.5,
              height: 1.1,
              letterSpacing: 0,
              color: active && accent == _SocialAccent.neutral
                  ? colors.background.withValues(alpha: 0.74)
                  : colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
    this.size = 44,
    this.iconSize = 18,
  });

  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.14) : colors.card,
            borderRadius: BorderRadius.circular(size < 40 ? 999 : 16),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.35) : colors.border,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: active ? color : colors.inkSoft,
            fill: active ? 1 : 0,
          ),
        ),
      ),
    );
  }
}

String _formatSocialCount(int value) {
  if (value >= 1000) {
    final short = value / 1000;
    final text = value >= 10000
        ? short.toStringAsFixed(0)
        : short.toStringAsFixed(1).replaceAll('.0', '');
    return '${text}k';
  }
  return value.toString();
}
