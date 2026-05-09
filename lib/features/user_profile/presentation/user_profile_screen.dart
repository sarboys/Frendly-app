import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/async_value_view.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_gallery.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_social_actions.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(personProfileProvider(userId));
    final currentProfile = ref.watch(profileProvider).valueOrNull;

    return BbV5Scaffold(
      child: AsyncValueView<ProfileData>(
        value: profileAsync,
        data: (profile) {
          _prewarmUserProfilePhotos(ref, profile);
          final commonInterests = currentProfile == null
              ? <String>[]
              : profile.interests
                  .where(
                      (interest) => currentProfile.interests.contains(interest))
                  .toList(growable: false);
          final title = profile.age == null
              ? profile.displayName
              : '${profile.displayName}, ${profile.age}';
          final location = _profileLocationLabel(profile);

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
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 132),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BbV5TopBar(
                                  kicker: 'Профиль',
                                  title: profile.displayName,
                                  onBack: () => context.pop(),
                                  right: BbV5IconButton(
                                    icon: Icons.more_horiz_rounded,
                                    onPressed: () =>
                                        _showProfileActions(context, userId),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                BbV5Card(
                                  tint: BbV5Colors.brandSoft,
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          BbProfilePhotoGallery(
                                            displayName: title,
                                            photos: profile.photos,
                                            height: 340,
                                          ),
                                          if (profile.online)
                                            Positioned(
                                              right: 16,
                                              bottom: 16,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: BbV5Colors.sage,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: BbV5Colors.paperHi,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        title,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: bbV5DisplayStyle(
                                                          fontSize: 21,
                                                          height: 1.2,
                                                        ),
                                                      ),
                                                    ),
                                                    if (profile.verified) ...[
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                        LucideIcons
                                                            .shield_check,
                                                        size: 17,
                                                        color: BbV5Colors.brand,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (location.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        LucideIcons.map_pin,
                                                        size: 13,
                                                        color:
                                                            BbV5Colors.inkMute,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Expanded(
                                                        child: Text(
                                                          location,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: AppTextStyles
                                                              .meta
                                                              .copyWith(
                                                            color: BbV5Colors
                                                                .inkMute,
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      BbSocialActions(
                                        userId: userId,
                                        initialSocial: profile.social,
                                        enabled: currentProfile?.id != userId,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _TrustCard(
                                              value: '${profile.meetupCount}',
                                              label: 'Встреч',
                                              icon: LucideIcons.users,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Expanded(
                                            child: _TrustCard(
                                              value: profile.rating
                                                  .toStringAsFixed(1),
                                              label: 'Рейтинг',
                                              icon: LucideIcons.star,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Expanded(
                                            child: _TrustCard(
                                              value: profile.verified
                                                  ? 'Да'
                                                  : 'Нет',
                                              label: 'Профиль',
                                              icon: LucideIcons.shield_check,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _UserSection(
                                  title: 'Настроение',
                                  child: BbV5Card(
                                    radius: 20,
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.sparkles,
                                          size: 16,
                                          color: BbV5Colors.terra,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                profile.vibe ?? 'Спокойно',
                                                style: AppTextStyles.itemTitle
                                                    .copyWith(
                                                  color: BbV5Colors.ink,
                                                ),
                                              ),
                                              Text(
                                                'Камерные встречи без спешки',
                                                style:
                                                    AppTextStyles.meta.copyWith(
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
                                _UserSection(
                                  title: 'Зачем здесь',
                                  child: _UserTagWrap(
                                    values: profile.intent,
                                    emptyLabel: 'Пока не выбрано',
                                    iconFor: (item) => item == 'Свидания'
                                        ? LucideIcons.heart
                                        : LucideIcons.users,
                                  ),
                                ),
                                _UserSection(
                                  title: 'Интересы',
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _UserTagWrap(
                                        values: profile.interests,
                                        emptyLabel: 'Интересы пока не указаны',
                                        activeValues: commonInterests.toSet(),
                                      ),
                                      if (profile.interests.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          '${commonInterests.length} общих с тобой',
                                          style: AppTextStyles.meta.copyWith(
                                            color: BbV5Colors.inkMute,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                _UserSection(
                                  title: 'О себе',
                                  child: Text(
                                    (profile.bio ?? '').isEmpty
                                        ? 'Пока без описания'
                                        : profile.bio!,
                                    style: AppTextStyles.bodySoft.copyWith(
                                      fontSize: 14,
                                      height: 1.625,
                                      color: BbV5Colors.inkSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00F1E6D6),
                          BbV5Colors.paper,
                          BbV5Colors.paper,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: BbV5PillButton(
                                label: 'Позвать',
                                icon: LucideIcons.calendar_plus,
                                height: 52,
                                expanded: true,
                                onPressed: () => context.pushRoute(
                                  AppRoute.createMeetup,
                                  queryParameters: {'inviteeUserId': userId},
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: BbV5PillButton(
                                label: 'Написать',
                                icon: LucideIcons.message_circle,
                                dark: true,
                                height: 52,
                                expanded: true,
                                onPressed: () async {
                                  final repository =
                                      ref.read(backendRepositoryProvider);
                                  final chatId = await repository
                                      .createOrGetDirectChat(userId);
                                  if (context.mounted) {
                                    context.pushRoute(
                                      AppRoute.personalChat,
                                      pathParameters: {'chatId': chatId},
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _prewarmUserProfilePhotos(WidgetRef ref, ProfileData profile) {
  unawaited(
    ref.read(appMediaPrewarmServiceProvider).warmProfileImages(
          profile.photos.map(
            (photo) => photo.bestUrlFor(BbImageUsageProfile.hero),
          ),
          usageProfile: BbImageUsageProfile.hero,
          limit: 3,
          concurrency: 2,
        ),
  );
}

Future<void> _showProfileActions(
  BuildContext outerContext,
  String userId,
) {
  final container = ProviderScope.containerOf(outerContext, listen: false);
  final repository = container.read(backendRepositoryProvider);
  return showModalBottomSheet<void>(
    context: outerContext,
    backgroundColor: Colors.transparent,
    barrierColor: BbV5Colors.ink.withValues(alpha: 0.5),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: BbV5Card(
              radius: 28,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BbV5Colors.hair,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProfileActionRow(
                    icon: LucideIcons.flag,
                    label: 'Пожаловаться',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      outerContext.pushRoute(
                        AppRoute.report,
                        pathParameters: {'userId': userId},
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _ProfileActionRow(
                    icon: LucideIcons.user_x,
                    label: 'Заблокировать',
                    destructive: true,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await repository.createBlock(
                        targetUserId: userId,
                      );
                      if (!outerContext.mounted) {
                        return;
                      }
                      container.invalidate(peopleProvider);
                      container.invalidate(personProfileProvider(userId));
                      container.invalidate(personalChatsProvider);
                      container.invalidate(meetupChatsProvider);
                      container.invalidate(safetyHubProvider);
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text('Пользователь заблокирован'),
                        ),
                      );
                      outerContext.pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _profileLocationLabel(ProfileData profile) {
  return [
    if ((profile.city ?? '').isNotEmpty) profile.city!,
    if ((profile.area ?? '').isNotEmpty) profile.area!,
  ].join(' · ');
}

class _UserSection extends StatelessWidget {
  const _UserSection({
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
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
              letterSpacing: 1.9,
              color: BbV5Colors.inkMute,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _UserTagWrap extends StatelessWidget {
  const _UserTagWrap({
    required this.values,
    required this.emptyLabel,
    this.activeValues = const <String>{},
    this.iconFor,
  });

  final List<String> values;
  final String emptyLabel;
  final Set<String> activeValues;
  final IconData Function(String value)? iconFor;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Text(
        emptyLabel,
        style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
      );
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: values
          .map(
            (value) => _UserTag(
              label: value,
              icon: iconFor?.call(value),
              active: activeValues.contains(value),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _UserTag extends StatelessWidget {
  const _UserTag({
    required this.label,
    required this.active,
    this.icon,
  });

  final String label;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? BbV5Colors.terra : BbV5Colors.inkSoft;
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
            style: AppTextStyles.meta.copyWith(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: BbV5Colors.inkMute),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 16,
              height: 1.15,
              color: BbV5Colors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              height: 1.2,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? BbV5Colors.terra : BbV5Colors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTextStyles.itemTitle.copyWith(
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
