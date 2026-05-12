import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/live_meetup.dart';
import 'package:big_break_mobile/shared/widgets/async_value_view.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LiveMeetupScreen extends ConsumerWidget {
  const LiveMeetupScreen({
    required this.eventId,
    super.key,
  });

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _V5LiveColors.instance;
    final liveAsync = ref.watch(liveMeetupProvider(eventId));

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: AsyncValueView<LiveMeetupData>(
          value: liveAsync,
          data: (live) {
            final checkedInCount = live.attendees
                .where((item) => item.attendanceStatus.name == 'checkedIn')
                .length;

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon:
                              const Icon(Icons.chevron_left_rounded, size: 28),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.destructive.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.destructive,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'В прямом эфире',
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.destructive,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.clock_3,
                          size: 14,
                          color: colors.inkMute,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Идёт уже ${_elapsedLabel(live.elapsedMinutes)}',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.inkMute,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(live.title, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.map_pin,
                          size: 14,
                          color: colors.inkMute,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(live.place, style: AppTextStyles.meta),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(BbV5Radii.lg),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'На встрече сейчас',
                                style: AppTextStyles.meta.copyWith(
                                  color: colors.inkSoft,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$checkedInCount из ${live.attendees.length}',
                                style: AppTextStyles.meta.copyWith(
                                  color: colors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: live.attendees
                                .map(
                                  (attendee) => SizedBox(
                                    width: 88,
                                    child: Column(
                                      children: [
                                        BbAvatar(
                                          name: attendee.displayName,
                                          size: BbAvatarSize.lg,
                                          imageUrl: attendee.avatarUrl,
                                          online:
                                              attendee.attendanceStatus.name ==
                                                  'checkedIn',
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          attendee.displayName,
                                          style: AppTextStyles.meta.copyWith(
                                            color: colors.foreground,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.primaryForeground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                      ),
                      onPressed: () {
                        context.pushRoute(
                          AppRoute.stories,
                          pathParameters: {'eventId': eventId},
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(LucideIcons.camera, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Поделись моментом',
                                  style: AppTextStyles.itemTitle.copyWith(
                                    color: colors.primaryForeground,
                                  ),
                                ),
                                Text(
                                  'Сторис увидят только участники встречи',
                                  style: AppTextStyles.meta.copyWith(
                                    color: colors.primaryForeground
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(color: colors.border),
                        backgroundColor: colors.card,
                      ),
                      onPressed: live.chatId == null
                          ? null
                          : () => context.pushRoute(
                                AppRoute.meetupChat,
                                pathParameters: {'chatId': live.chatId!},
                              ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.message_circle,
                            color: colors.inkSoft,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Открыть чат встречи',
                                  style: AppTextStyles.itemTitle.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  live.chatId == null
                                      ? 'Чат пока недоступен'
                                      : 'Чат доступен для участников',
                                  style: AppTextStyles.meta.copyWith(
                                    color: colors.inkMute,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: colors.destructive.withValues(alpha: 0.35),
                        ),
                        backgroundColor:
                            colors.destructive.withValues(alpha: 0.08),
                      ),
                      onPressed: () async {
                        final repository = ref.read(backendRepositoryProvider);
                        try {
                          await repository.createSos(eventId: eventId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('SOS отправлен')),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SOS сейчас недоступен'),
                              ),
                            );
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.shield_alert,
                            color: colors.destructive,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Тревога',
                                  style: AppTextStyles.itemTitle.copyWith(
                                    fontSize: 14,
                                    color: colors.destructive,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Уведомим близких и саппорт Frendly',
                                  style: AppTextStyles.meta.copyWith(
                                    color: colors.destructive
                                        .withValues(alpha: 0.82),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.background.withValues(alpha: 0),
                            colors.background,
                            colors.background,
                          ],
                        ),
                      ),
                      child: SizedBox(
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.foreground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => context.pushRoute(
                            AppRoute.afterParty,
                            pathParameters: {'eventId': eventId},
                          ),
                          child: Text(
                            'Завершить встречу',
                            style: AppTextStyles.button.copyWith(
                              color: colors.primaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _elapsedLabel(int elapsedMinutes) {
    final hours = elapsedMinutes ~/ 60;
    final minutes = elapsedMinutes % 60;
    if (hours == 0) {
      return '$minutes мин';
    }
    return '$hours ч ${minutes.toString().padLeft(2, '0')} мин';
  }
}

class _V5LiveColors {
  const _V5LiveColors._();

  static const instance = _V5LiveColors._();

  Color get background => BbV5Colors.paper;
  Color get border => BbV5Colors.hair;
  Color get card => BbV5Colors.paperHi;
  Color get destructive => BbV5Colors.accentDeep;
  Color get foreground => BbV5Colors.ink;
  Color get inkMute => BbV5Colors.inkMute;
  Color get inkSoft => BbV5Colors.inkSoft;
  Color get primary => BbV5Colors.accent;
  Color get primaryForeground => BbV5Colors.paperHi;
  Color get secondary => BbV5Colors.sage;
}
