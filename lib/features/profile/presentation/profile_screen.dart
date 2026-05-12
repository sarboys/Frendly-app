import 'dart:async';
import 'dart:typed_data';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/utils/location_label.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_gallery.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
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
        data: (profile) {
          _prewarmProfilePhotos(ref, profile);
          return ProfileV5Content(
            profile: profile,
            photoPreviews: photoPreviews,
          );
        },
      ),
    );
  }
}

class ProfileV5Content extends StatelessWidget {
  const ProfileV5Content({
    required this.profile,
    this.photoPreviews = const {},
    this.header,
    this.showOwnerCards = true,
    this.heroAction,
    this.heroSignalRow,
    this.interestHighlights = const {},
    this.interestFooter,
    this.bottomOverlay,
    this.bottomPadding = 132,
    this.locationFallback = 'Москва · Чистые пруды',
    this.useShortHeroName = true,
    super.key,
  });

  final ProfileData profile;
  final Map<String, Uint8List> photoPreviews;
  final Widget? header;
  final bool showOwnerCards;
  final Widget? heroAction;
  final Widget? heroSignalRow;
  final Set<String> interestHighlights;
  final Widget? interestFooter;
  final Widget? bottomOverlay;
  final double bottomPadding;
  final String? locationFallback;
  final bool useShortHeroName;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPadding),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header ??
                        _ProfileHeader(
                          onBack: () => context.goRoute(AppRoute.tonight),
                          onSos: () => context.pushRoute(AppRoute.sos),
                          onSettings: () =>
                              context.pushRoute(AppRoute.settings),
                        ),
                    const SizedBox(height: 20),
                    _ProfileHeroCard(
                      profile: profile,
                      photoPreviews: photoPreviews,
                      locationFallback: locationFallback,
                      useShortName: useShortHeroName,
                      action: heroAction ??
                          (showOwnerCards ? _ownerHeroAction(context) : null),
                      signalRow: heroSignalRow,
                    ),
                    if (showOwnerCards) ...[
                      const SizedBox(height: AppSpacing.md),
                      _FrendlyPlusCard(
                        onTap: () => context.pushRoute(AppRoute.paywall),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _FriendlyTokensCard(
                        onBalance: () =>
                            context.pushRoute(AppRoute.tokensBalance),
                        onFocus: () => context.pushRoute(AppRoute.tokensFocus),
                        onTopUp: () => context.pushRoute(AppRoute.tokensTopUp),
                        onBoost: () => context.pushRoute(AppRoute.tokensBoost),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ProfileTrustActions(
                        onVerification: () =>
                            context.pushRoute(AppRoute.verification),
                        onSos: () => context.pushRoute(AppRoute.sos),
                        onNotifications: () =>
                            context.pushRoute(AppRoute.notifications),
                      ),
                    ],
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileTags(
                            values: profile.interests,
                            emptyLabel: 'Интересы появятся после заполнения',
                            activeValues: interestHighlights,
                          ),
                          if (interestFooter != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            interestFooter!,
                          ],
                        ],
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
    );

    return SafeArea(
      bottom: false,
      child: bottomOverlay == null
          ? content
          : Stack(
              children: [
                content,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: bottomOverlay!,
                ),
              ],
            ),
    );
  }

  Widget _ownerHeroAction(BuildContext context) {
    return BbV5PillButton(
      label: 'Изменить',
      icon: LucideIcons.pen_line,
      height: 34,
      fontSize: 11.5,
      iconSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      onPressed: () => context.pushRoute(AppRoute.editProfile),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onBack,
    required this.onSos,
    required this.onSettings,
  });

  final VoidCallback onBack;
  final VoidCallback onSos;
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
        _ProfileHeaderSosButton(onTap: onSos),
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

class _ProfileHeaderSosButton extends StatelessWidget {
  const _ProfileHeaderSosButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'SOS',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('profile-header-sos'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(BbV5Radii.pill),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD85B4A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB5443B)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99B5443B),
                  blurRadius: 18,
                  spreadRadius: -8,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.shield_alert,
              size: 17,
              color: BbV5Colors.paperHi,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.photoPreviews,
    required this.locationFallback,
    required this.useShortName,
    this.action,
    this.signalRow,
  });

  final ProfileData profile;
  final Map<String, Uint8List> photoPreviews;
  final String? locationFallback;
  final bool useShortName;
  final Widget? action;
  final Widget? signalRow;

  @override
  Widget build(BuildContext context) {
    final name =
        useShortName ? _shortName(profile.displayName) : profile.displayName;
    final title = profile.age == null ? name : '$name, ${profile.age}';
    final location = composeLocationLabel(profile.city, profile.area);
    final locationLabel =
        location.isEmpty ? locationFallback?.trim() ?? '' : location;
    final photos = _heroPhotosFor(profile);

    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbProfilePhotoGallery(
            displayName: title,
            photos: photos,
            photoPreviews: photoPreviews,
            height: 356,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: locationLabel.isEmpty
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          const Icon(
                            LucideIcons.map_pin,
                            size: 13,
                            color: BbV5Colors.inkMute,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ),
                          if (profile.verified) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              LucideIcons.shield_check,
                              size: 17,
                              color: BbV5Colors.brand,
                            ),
                          ],
                        ],
                      ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.sm),
                action!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: BbV5Colors.hairSoft),
          const SizedBox(height: AppSpacing.md),
          _ProfileStatsRow(profile: profile),
          if (signalRow != null) ...[
            const SizedBox(height: AppSpacing.md),
            signalRow!,
          ],
        ],
      ),
    );
  }
}

List<ProfilePhoto> _heroPhotosFor(ProfileData profile) {
  if (profile.photos.isNotEmpty) {
    return profile.photos;
  }

  final avatarUrl = profile.avatarUrl?.trim();
  if (avatarUrl == null || avatarUrl.isEmpty) {
    return const [];
  }

  return [
    ProfilePhoto(
      id: 'avatar-fallback',
      url: avatarUrl,
      order: 0,
    ),
  ];
}

void _prewarmProfilePhotos(WidgetRef ref, ProfileData profile) {
  unawaited(
    ref.read(appMediaPrewarmServiceProvider).warmProfileImages(
          _heroPhotosFor(profile).map(
            (photo) => photo.bestUrlFor(BbImageUsageProfile.hero),
          ),
          usageProfile: BbImageUsageProfile.hero,
          limit: 3,
          concurrency: 2,
        ),
  );
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            key: const ValueKey('profile-stat-followers'),
            icon: LucideIcons.users,
            value: _formatCount(profile.social.followers),
            semanticLabel: 'Подписчиков',
          ),
        ),
        Expanded(
          child: _MetricTile(
            key: const ValueKey('profile-stat-likes'),
            icon: LucideIcons.heart,
            value: _formatCount(profile.social.likes),
            semanticLabel: 'Лайков',
          ),
        ),
        Expanded(
          child: _MetricTile(
            key: const ValueKey('profile-stat-rating'),
            icon: LucideIcons.star,
            value: profile.rating.toStringAsFixed(1),
            semanticLabel: 'Рейтинг',
          ),
        ),
        Expanded(
          child: _MetricTile(
            key: const ValueKey('profile-stat-meetups'),
            icon: LucideIcons.shield_check,
            value: '${profile.meetupCount}',
            semanticLabel: 'Встреч',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String value;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticLabel $value',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: BbV5Colors.inkMute),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: bbV5DisplayStyle(fontSize: 16, height: 1).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
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

class _FriendlyTokensCard extends StatelessWidget {
  const _FriendlyTokensCard({
    required this.onBalance,
    required this.onFocus,
    required this.onTopUp,
    required this.onBoost,
  });

  final VoidCallback onBalance;
  final VoidCallback onFocus;
  final VoidCallback onTopUp;
  final VoidCallback onBoost;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      tint: BbV5Colors.terraSoft,
      onTap: onBalance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BbV5Colors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                  boxShadow: BbV5Shadows.pill,
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 22,
                  color: BbV5Colors.paperHi,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frendly Tokens',
                      style: bbV5DisplayStyle(
                        fontSize: 15,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Продвигай встречи, маршруты и события',
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
              const SizedBox(width: AppSpacing.sm),
              Text(
                '1 240',
                style: AppTextStyles.itemTitle.copyWith(
                  fontSize: 16,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevron_right,
                size: 17,
                color: BbV5Colors.inkMute,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TokenEntryChip(
                label: 'Баланс',
                icon: LucideIcons.wallet,
                onTap: onBalance,
              ),
              _TokenEntryChip(
                label: 'Фокус',
                icon: LucideIcons.sparkles,
                onTap: onFocus,
              ),
              _TokenEntryChip(
                label: 'Пополнить',
                icon: LucideIcons.plus,
                onTap: onTopUp,
              ),
              _TokenEntryChip(
                label: 'Буст',
                icon: LucideIcons.target,
                onTap: onBoost,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileTrustActions extends ConsumerWidget {
  const _ProfileTrustActions({
    required this.onVerification,
    required this.onSos,
    required this.onNotifications,
  });

  final VoidCallback onVerification;
  final VoidCallback onSos;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationUnreadCountProvider).valueOrNull ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ProfileActionTile(
                icon: LucideIcons.shield_check,
                iconColor: BbV5Colors.brand,
                title: 'Верификация',
                subtitle: 'Получи галочку доверия',
                onTap: onVerification,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _ProfileActionTile(
                icon: LucideIcons.shield_alert,
                iconColor: const Color(0xFFB5443B),
                iconBackground: const Color(0x1FD85B4A),
                title: 'Кнопка SOS',
                subtitle: 'Доверенные и горячие линии',
                onTap: onSos,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        BbV5Card(
          radius: BbV5Radii.md,
          padding: const EdgeInsets.all(16),
          onTap: onNotifications,
          child: Row(
            children: [
              const _ProfileActionIcon(
                icon: LucideIcons.bell,
                color: BbV5Colors.terra,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Уведомления',
                      style: AppTextStyles.caption.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: BbV5Colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Приглашения, чаты, перки',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BbV5Colors.accent,
                    borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: AppTextStyles.caption.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: BbV5Colors.paperHi,
                    ),
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
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBackground,
  });

  final IconData icon;
  final Color iconColor;
  final Color? iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: BbV5Radii.md,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileActionIcon(
            icon: icon,
            color: iconColor,
            background: iconBackground,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: BbV5Colors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.5,
              height: 1.25,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionIcon extends StatelessWidget {
  const _ProfileActionIcon({
    required this.icon,
    required this.color,
    this.background,
  });

  final IconData icon;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background ?? BbV5Colors.paper,
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

class _TokenEntryChip extends StatelessWidget {
  const _TokenEntryChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5PillButton(
      label: label,
      icon: icon,
      height: 34,
      fontSize: 11.5,
      iconSize: 13,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onPressed: onTap,
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
    this.activeValues = const {},
    this.iconFor,
  });

  final List<String> values;
  final String emptyLabel;
  final Set<String> activeValues;
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
              active: activeValues.contains(value),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({
    required this.label,
    this.active = false,
    this.icon,
  });

  final String label;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? BbV5Colors.terra : BbV5Colors.ink;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? BbV5Colors.terraSoft : BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(
          color: active ? BbV5Colors.accent : BbV5Colors.hair,
        ),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ] else if (active) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: BbV5Colors.terra,
                shape: BoxShape.circle,
              ),
            ),
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
              color: foreground,
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

String _shortName(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return 'Профиль';
  }
  return parts.first;
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
