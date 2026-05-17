import 'dart:async';
import 'dart:typed_data';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
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
                      _ProfileQuickGrid(
                        onPlus: () => context.pushRoute(AppRoute.paywall),
                        onWallet: () => context.pushRoute(AppRoute.wallet),
                        onVerification: () =>
                            context.pushRoute(AppRoute.verification),
                        onSos: () => context.pushRoute(AppRoute.sos),
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
            badges: _profileBadges(profile),
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

List<Widget> _profileBadges(ProfileData profile) {
  return [
    if (profile.verified)
      const _ProfileTrustBadge(
        label: 'Verified',
        icon: LucideIcons.shield_check,
        backgroundStart: Color(0xFFE8F0E3),
        backgroundEnd: Color(0xAAC9D5BE),
        foreground: BbV5Colors.brandDeep,
        border: Color(0x384F6A53),
      ),
    if (profile.frendlyPlus)
      const _ProfileTrustBadge(
        label: 'Frendly+',
        icon: LucideIcons.crown,
        backgroundStart: Color(0xFFF6D8B5),
        backgroundEnd: BbV5Colors.terraSoft,
        foreground: Color(0xFF7A3F22),
        border: Color(0x4DB26F4A),
      ),
  ];
}

class _ProfileTrustBadge extends StatelessWidget {
  const _ProfileTrustBadge({
    required this.label,
    required this.icon,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.foreground,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          label == 'Verified' ? 'Профиль верифицирован' : 'Подписка Frendly+',
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: 7, right: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundStart, backgroundEnd],
          ),
          borderRadius: BorderRadius.circular(BbV5Radii.pill),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.22),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.meta.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
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

class _ProfileQuickGrid extends ConsumerWidget {
  const _ProfileQuickGrid({
    required this.onPlus,
    required this.onWallet,
    required this.onVerification,
    required this.onSos,
  });

  final VoidCallback onPlus;
  final VoidCallback onWallet;
  final VoidCallback onVerification;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(tokenWalletProvider).balance;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ProfileFeatureCard(
                icon: LucideIcons.crown,
                title: 'Frendly+',
                subtitle: 'Фильтры, лайки, закрытые вечера',
                tone: BbV5Colors.gold,
                onTap: onPlus,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileFeatureCard(
                icon: LucideIcons.wallet,
                title: 'Wallet',
                subtitle: '${_formatTokenBalance(balance)} токенов',
                tone: BbV5Colors.brand,
                onTap: onWallet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ProfileTrustButton(
                icon: LucideIcons.badge_check,
                label: 'Верификация',
                sub: 'Быстрее проходят заявки',
                onTap: onVerification,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileTrustButton(
                icon: LucideIcons.shield_alert,
                label: 'SOS',
                sub: 'Контакты и быстрый сигнал',
                danger: true,
                onTap: onSos,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileFeatureCard extends StatelessWidget {
  const _ProfileFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 20,
      padding: const EdgeInsets.all(14),
      tint: tone.withValues(alpha: 0.55),
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tone.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, size: 16, color: tone),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bbV5DisplayStyle(fontSize: 14, height: 1.15),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.8,
                height: 1.2,
                color: BbV5Colors.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTrustButton extends StatelessWidget {
  const _ProfileTrustButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tone = danger ? const Color(0xFFB5443B) : BbV5Colors.brandDeep;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 17, color: tone),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bbV5DisplayStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        height: 1.15,
                        color: BbV5Colors.inkMute,
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

String _formatTokenBalance(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    final fromEnd = raw.length - index;
    buffer.write(raw[index]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
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
