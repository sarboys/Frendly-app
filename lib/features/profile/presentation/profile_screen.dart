import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/utils/location_label.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final photoPreviews = ref.watch(profilePhotoPreviewProvider);

    return BbV5Scaffold(
      child: profileAsync.when(
        loading: () => const _ProfileLoadingState(),
        error: (_, __) => _ProfileErrorState(
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) => _ProfileContent(
          profile: profile,
          photoPreviews: photoPreviews,
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.photoPreviews,
  });

  final ProfileData profile;
  final Map<String, Uint8List> photoPreviews;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileHeader(
                        onBack: () => context.goRoute(AppRoute.tonight),
                        onSettings: () => context.pushRoute(AppRoute.settings),
                      ),
                      const SizedBox(height: 20),
                      _ProfileHeroCard(
                        profile: profile,
                        photoPreviews: photoPreviews,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _FrendlyPlusCard(
                        onTap: () => context.pushRoute(AppRoute.paywall),
                      ),
                      _ProfileSection(
                        title: 'Зачем здесь',
                        child: _ProfileTags(
                          values: profile.intent,
                          emptyLabel: 'Пока не выбрано',
                          iconFor: (value) => value == 'Свидания'
                              ? LucideIcons.heart
                              : LucideIcons.users,
                        ),
                      ),
                      _ProfileSection(
                        title: 'Настроение',
                        child: _VibeCard(vibe: profile.vibe),
                      ),
                      _ProfileSection(
                        title: 'Интересы',
                        child: _ProfileTags(
                          values: profile.interests,
                          emptyLabel: 'Интересы появятся после заполнения',
                        ),
                      ),
                      _ProfileSection(
                        title: 'О себе',
                        child: _AboutCard(text: profile.bio),
                      ),
                      _ProfileSection(
                        title: 'История',
                        child: _HistoryGrid(profile: profile),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onBack,
    required this.onSettings,
  });

  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          iconSize: 16,
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.xs),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker('Аккаунт'),
              SizedBox(height: 4),
              BbV5HeroTitle(title: 'Твой', accent: 'профиль'),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        BbV5IconButton(
          icon: LucideIcons.settings,
          iconSize: 16,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.photoPreviews,
  });

  final ProfileData profile;
  final Map<String, Uint8List> photoPreviews;

  @override
  Widget build(BuildContext context) {
    final shortName = _shortName(profile.displayName);
    final location = composeLocationLabel(profile.city, profile.area);

    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileAvatarTile(
                profile: profile,
                photoPreviews: photoPreviews,
                onCameraTap: () => context.pushRoute(AppRoute.editProfile),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.age == null
                                  ? shortName
                                  : '$shortName, ${profile.age}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bbV5DisplayStyle(
                                fontSize: 20,
                                height: 1.25,
                                letterSpacing: -0.4,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          if (profile.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              LucideIcons.shield_check,
                              size: 17,
                              color: BbV5Colors.brand,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.map_pin,
                            size: 12,
                            color: BbV5Colors.inkMute,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location.isEmpty
                                  ? 'Москва · Чистые пруды'
                                  : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      BbV5PillButton(
                        label: 'Изменить',
                        icon: LucideIcons.pen_line,
                        height: 32,
                        fontSize: 11.5,
                        iconSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        onPressed: () =>
                            context.pushRoute(AppRoute.editProfile),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: BbV5Colors.hairSoft),
          const SizedBox(height: AppSpacing.lg),
          _ProfileStatsGrid(profile: profile),
          const SizedBox(height: AppSpacing.md),
          _ProfileSignalRow(profile: profile),
        ],
      ),
    );
  }
}

class _ProfileAvatarTile extends StatelessWidget {
  const _ProfileAvatarTile({
    required this.profile,
    required this.photoPreviews,
    required this.onCameraTap,
  });

  final ProfileData profile;
  final Map<String, Uint8List> photoPreviews;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    final primaryPhoto = profile.photos.isEmpty ? null : profile.photos.first;
    final previewBytes =
        primaryPhoto == null ? null : photoPreviews[primaryPhoto.id];
    final imageUrl = profile.avatarUrl ?? primaryPhoto?.url;

    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 80,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [BbV5Colors.terraSoft, BbV5Colors.brandSoft],
                  ),
                ),
                child: previewBytes == null
                    ? BbProfilePhotoImage(
                        imageUrl: imageUrl,
                        fallbackText: _initial(profile.displayName),
                        usageProfile: BbImageUsageProfile.avatar,
                        fallbackFontSize: 26,
                      )
                    : Image.memory(
                        previewBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: 260,
                        cacheHeight: 260,
                      ),
              ),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: BbV5IconButton(
              icon: LucideIcons.camera,
              onPressed: onCameraTap,
              dark: true,
              size: 28,
              iconSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatsGrid extends StatelessWidget {
  const _ProfileStatsGrid({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: [
        _MetricTile(
          icon: LucideIcons.users,
          value: _formatCount(profile.social.followers),
          label: 'Подписчиков',
        ),
        _MetricTile(
          icon: LucideIcons.heart,
          value: _formatCount(profile.social.likes),
          label: 'Лайков',
        ),
        _MetricTile(
          icon: LucideIcons.star,
          value: profile.rating.toStringAsFixed(1),
          label: 'Рейтинг',
        ),
        _MetricTile(
          icon: LucideIcons.shield_check,
          value: '${profile.meetupCount}',
          label: 'Встреч',
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: BbV5Colors.inkMute),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: bbV5DisplayStyle(fontSize: 15, height: 1).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9.5,
              letterSpacing: 0,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSignalRow extends StatelessWidget {
  const _ProfileSignalRow({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final social = profile.social;

    return Row(
      children: [
        Expanded(
          child: BbV5PillButton(
            label: social.iFollow ? 'Подписан' : 'Подписаться',
            icon:
                social.iFollow ? LucideIcons.user_check : LucideIcons.user_plus,
            dark: !social.iFollow,
            height: 44,
            fontSize: 12.5,
            iconSize: 14,
            expanded: true,
            onPressed: () => _showOwnProfileSnack(context),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        BbV5PillButton(
          label: _formatCount(social.likes),
          icon: LucideIcons.heart,
          height: 44,
          fontSize: 12.5,
          iconSize: 14,
          onPressed: () => _showOwnProfileSnack(context),
        ),
        const SizedBox(width: AppSpacing.xs),
        BbV5IconButton(
          icon: LucideIcons.share_2,
          iconSize: 16,
          onPressed: () => _copyProfilePath(context, profile),
        ),
      ],
    );
  }
}

class _FrendlyPlusCard extends StatelessWidget {
  const _FrendlyPlusCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: const Icon(
              LucideIcons.crown,
              size: 21,
              color: BbV5Colors.terra,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Frendly'),
                      TextSpan(
                        text: '+',
                        style: AppTextStyles.itemTitle.copyWith(
                          color: BbV5Colors.terra,
                        ),
                      ),
                    ],
                  ),
                  style: bbV5DisplayStyle(fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dating, фильтры и приоритет в заявках',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    fontSize: 11.5,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            LucideIcons.chevron_right,
            size: 17,
            color: BbV5Colors.inkMute,
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbV5Kicker(title),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ProfileTags extends StatelessWidget {
  const _ProfileTags({
    required this.values,
    required this.emptyLabel,
    this.iconFor,
  });

  final List<String> values;
  final String emptyLabel;
  final IconData Function(String value)? iconFor;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return _EmptyInlineCard(label: emptyLabel);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => _ProfileTag(
              label: value,
              icon: iconFor?.call(value),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: BbV5Colors.ink),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 0,
              color: BbV5Colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({required this.vibe});

  final String? vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (vibe == null || vibe!.trim().isEmpty) ? 'Спокойно' : vibe!,
            style: bbV5DisplayStyle(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Камерные встречи, разговор без спешки',
            style: AppTextStyles.meta.copyWith(
              fontSize: 12.5,
              color: BbV5Colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      return const _EmptyInlineCard(label: 'Расскажи о себе в профиле');
    }

    return Text(
      value,
      style: AppTextStyles.body.copyWith(
        fontSize: 13.5,
        height: 1.625,
        color: BbV5Colors.inkSoft,
      ),
    );
  }
}

class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final items = [
      (value: '${profile.meetupCount}', label: 'встреч за 3 мес'),
      (value: profile.rating.toStringAsFixed(1), label: 'рейтинг'),
      (value: '${profile.interests.length}', label: 'интересов'),
      (value: _formatCount(profile.social.followers), label: 'новых знакомых'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BbV5Colors.hair),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.value,
                      maxLines: 1,
                      style: bbV5DisplayStyle(fontSize: 20, height: 1).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 0,
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EmptyInlineCard extends StatelessWidget {
  const _EmptyInlineCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Text(
        label,
        style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
      ),
    );
  }
}

class _ProfileLoadingState extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BbV5Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Не получилось загрузить профиль',
                    textAlign: TextAlign.center,
                    style: bbV5DisplayStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Проверь соединение и попробуй ещё раз.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.meta.copyWith(
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BbV5PillButton(
                    label: 'Повторить',
                    onPressed: onRetry,
                    dark: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _copyProfilePath(BuildContext context, ProfileData profile) async {
  await Clipboard.setData(
    ClipboardData(text: '/user/${Uri.encodeComponent(profile.id)}'),
  );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Ссылка скопирована')),
  );
}

void _showOwnProfileSnack(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Это твой профиль')),
  );
}

String _shortName(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return 'Профиль';
  }
  return parts.first;
}

String _initial(String value) {
  final short = _shortName(value);
  return short.characters.first.toUpperCase();
}

String _formatCount(int value) {
  if (value >= 1000) {
    final short = value / 1000;
    final text = value >= 10000
        ? short.toStringAsFixed(0)
        : short.toStringAsFixed(1).replaceAll('.0', '');
    return '${text}k';
  }
  return value.toString();
}
