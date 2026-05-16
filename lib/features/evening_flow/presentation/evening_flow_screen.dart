import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EveningFlowScreen extends ConsumerWidget {
  const EveningFlowScreen({
    required this.eventId,
    super.key,
  });

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _EveningHeader(
                      eventId: eventId,
                      eventTitle: eventAsync.valueOrNull?.title,
                      onBack: () => context.pop(),
                      onSos: () => context.pushRoute(AppRoute.sos),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
                  sliver: SliverToBoxAdapter(
                    child: eventAsync.when(
                      data: (event) => _ParticipantHub(
                        event: event,
                        onChat: event.chatId == null
                            ? null
                            : () => context.pushRoute(
                                  AppRoute.meetupChat,
                                  pathParameters: {'chatId': event.chatId!},
                                ),
                        onStories: () => context.pushRoute(
                          AppRoute.stories,
                          pathParameters: {'eventId': eventId},
                        ),
                        onShare: () => context.pushRoute(
                          AppRoute.shareCard,
                          pathParameters: {'eventId': eventId},
                        ),
                      ),
                      loading: () => const _EveningLoadingCard(),
                      error: (error, _) =>
                          _EveningErrorCard(message: error.toString()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EveningHeader extends StatelessWidget {
  const _EveningHeader({
    required this.eventId,
    required this.eventTitle,
    required this.onBack,
    required this.onSos,
  });

  final String eventId;
  final String? eventTitle;
  final VoidCallback onBack;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(icon: LucideIcons.arrow_left, onPressed: onBack),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker('встреча #$eventId'),
              const SizedBox(height: 2),
              BbV5HeroTitle(
                title: eventTitle ?? 'Встреча',
                accent: 'идёт',
                maxLines: 1,
              ),
            ],
          ),
        ),
        BbV5IconButton(
          icon: LucideIcons.shield_alert,
          onPressed: onSos,
          dark: true,
          color: BbV5Colors.paperHi,
        ),
      ],
    );
  }
}

class _ParticipantHub extends StatelessWidget {
  const _ParticipantHub({
    required this.event,
    required this.onChat,
    required this.onStories,
    required this.onShare,
  });

  final EventDetail event;
  final VoidCallback? onChat;
  final VoidCallback onStories;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5Card(
          tint: BbV5Colors.terraSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker('${event.time} · ${event.vibe}'),
              const SizedBox(height: 8),
              Text(
                event.title,
                style: bbV5DisplayStyle(fontSize: 24, letterSpacing: 0),
              ),
              const SizedBox(height: 6),
              Text(
                event.place,
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.inkMute,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: LucideIcons.users,
                      label: 'Идут',
                      value: '${event.going}/${event.capacity}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      icon: LucideIcons.map_pin,
                      label: 'Рядом',
                      value: event.distance,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _EveningInfoCard(
          icon: LucideIcons.radio,
          title: 'Встреча идёт',
          subtitle: 'Хост завершит вечер и отметит тех, кто был на месте',
        ),
        const SizedBox(height: 12),
        _AttendeeList(attendees: event.attendees),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SquareAction(
                icon: LucideIcons.camera,
                label: 'Моменты',
                onTap: onStories,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SquareAction(
                icon: LucideIcons.share_2,
                label: 'Позвать',
                onTap: onShare,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        BbV5PillButton(
          label: onChat == null ? 'Чат появится позже' : 'Открыть чат',
          icon: LucideIcons.message_circle,
          dark: true,
          height: 54,
          expanded: true,
          onPressed: onChat,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: BbV5Colors.inkMute),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bbV5DisplayStyle(fontSize: 16, letterSpacing: 0),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeList extends StatelessWidget {
  const _AttendeeList({required this.attendees});

  final List<EventAttendee> attendees;

  @override
  Widget build(BuildContext context) {
    if (attendees.isEmpty) {
      return const _EveningInfoCard(
        icon: LucideIcons.users,
        title: 'Участники пока не загрузились',
        subtitle: 'Список обновится после загрузки встречи',
      );
    }

    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: attendees
            .map(
              (attendee) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    BbAvatar(
                      name: attendee.displayName,
                      imageUrl: attendee.avatarUrl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        attendee.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: BbV5Card(
        radius: 20,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 19, color: BbV5Colors.terra),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: BbV5Colors.ink,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EveningInfoCard extends StatelessWidget {
  const _EveningInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: BbV5Colors.terraSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: BbV5Colors.accentDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EveningLoadingCard extends StatelessWidget {
  const _EveningLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const BbV5Card(
      child: SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: BbV5Colors.accent),
        ),
      ),
    );
  }
}

class _EveningErrorCard extends StatelessWidget {
  const _EveningErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Не получилось открыть встречу',
            style: bbV5DisplayStyle(fontSize: 18, letterSpacing: 0),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
