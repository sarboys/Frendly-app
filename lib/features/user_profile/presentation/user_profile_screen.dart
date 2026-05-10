import 'dart:async';

import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/profile/presentation/profile_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/widgets/async_value_view.dart';
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
                  .where(currentProfile.interests.contains)
                  .toList(growable: false);

          return ProfileV5Content(
            profile: profile,
            header: _PublicProfileHeader(
              profile: profile,
              userId: userId,
            ),
            showOwnerCards: false,
            heroAction: null,
            locationFallback: null,
            heroSignalRow: BbSocialActions(
              userId: userId,
              initialSocial: profile.social,
              enabled: currentProfile?.id != userId,
            ),
            interestHighlights: commonInterests.toSet(),
            interestFooter: commonInterests.isEmpty
                ? null
                : Text(
                    '${commonInterests.length} общих с тобой',
                    style: AppTextStyles.meta.copyWith(
                      color: BbV5Colors.inkMute,
                    ),
                  ),
            bottomOverlay: _PublicProfileBottomBar(userId: userId),
          );
        },
      ),
    );
  }
}

class _PublicProfileHeader extends StatelessWidget {
  const _PublicProfileHeader({
    required this.profile,
    required this.userId,
  });

  final ProfileData profile;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return BbV5TopBar(
      kicker: 'Профиль',
      title: profile.displayName,
      onBack: () => context.pop(),
      right: BbV5IconButton(
        icon: Icons.more_horiz_rounded,
        onPressed: () => _showProfileActions(context, userId),
      ),
    );
  }
}

class _PublicProfileBottomBar extends ConsumerWidget {
  const _PublicProfileBottomBar({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Row(
                children: [
                  Expanded(
                    child: BbV5PillButton(
                      label: 'Позвать на встречу',
                      icon: LucideIcons.calendar_plus,
                      height: 52,
                      fontSize: 12,
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
                        final repository = ref.read(backendRepositoryProvider);
                        final chatId =
                            await repository.createOrGetDirectChat(userId);
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
                      await repository.createBlock(targetUserId: userId);
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
