import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/after_party_state.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_check_in.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/models/live_meetup.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _EveningStage {
  route('Маршрут'),
  checkIn('Чек-ин'),
  live('Live'),
  after('After'),
  share('Итог'),
  end('Финал');

  const _EveningStage(this.label);

  final String label;
}

class EveningFlowScreen extends ConsumerStatefulWidget {
  const EveningFlowScreen({
    required this.eventId,
    super.key,
  });

  final String eventId;

  @override
  ConsumerState<EveningFlowScreen> createState() => _EveningFlowScreenState();
}

class _EveningFlowScreenState extends ConsumerState<EveningFlowScreen> {
  _EveningStage _stage = _EveningStage.route;
  int _rating = 0;
  bool _checkInBusy = false;
  bool _savingFeedback = false;
  final Set<String> _favoriteUserIds = <String>{};
  bool _favoriteUserIdsDirty = false;

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final event = eventAsync.valueOrNull;

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
                      eventId: widget.eventId,
                      eventTitle: event?.title,
                      onBack: () => context.pop(),
                      onSos: () => context.pushRoute(AppRoute.sos),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 0, 0),
                  sliver: SliverToBoxAdapter(
                    child: _StageTabs(
                      active: _stage,
                      onChanged: (stage) => setState(() => _stage = stage),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
                  sliver: SliverToBoxAdapter(
                    child: _buildStage(eventAsync),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(AsyncValue<EventDetail> eventAsync) {
    switch (_stage) {
      case _EveningStage.route:
        return _asyncBody(
          eventAsync,
          (event) => _RouteStage(
            event: event,
            onCheckIn: () => setState(() => _stage = _EveningStage.checkIn),
            onLive: () => setState(() => _stage = _EveningStage.live),
          ),
        );
      case _EveningStage.checkIn:
        return _asyncBody(
          ref.watch(checkInProvider(widget.eventId)),
          (state) => _CheckInStage(
            state: state,
            busy: _checkInBusy,
            onConfirm: () => _confirmCheckIn(state),
            onLive: () => setState(() => _stage = _EveningStage.live),
          ),
        );
      case _EveningStage.live:
        return _asyncBody(
          ref.watch(liveMeetupProvider(widget.eventId)),
          (live) => _LiveStage(
            live: live,
            onChat: live.chatId == null
                ? null
                : () => context.pushRoute(
                      AppRoute.meetupChat,
                      pathParameters: {'chatId': live.chatId!},
                    ),
            onMoment: () => context.pushRoute(
              AppRoute.stories,
              pathParameters: {'eventId': widget.eventId},
            ),
            onShare: () => context.pushRoute(
              AppRoute.shareCard,
              pathParameters: {'eventId': widget.eventId},
            ),
            onAfter: () => setState(() => _stage = _EveningStage.after),
          ),
        );
      case _EveningStage.after:
        return _asyncBody(
          ref.watch(afterPartyProvider(widget.eventId)),
          (afterParty) => _AfterStage(
            state: afterParty,
            favoriteUserIds: _effectiveFavoriteUserIds(afterParty),
            onToggleFavorite: (userId) =>
                _toggleFavorite(userId, afterParty.favoriteUserIds),
            onShare: () => setState(() => _stage = _EveningStage.share),
          ),
        );
      case _EveningStage.share:
        return _asyncBody(
          eventAsync,
          (event) => _ShareStage(
            event: event,
            live: ref.watch(liveMeetupProvider(widget.eventId)).valueOrNull,
            onStories: () => context.pushRoute(
              AppRoute.stories,
              pathParameters: {'eventId': widget.eventId},
            ),
            onSave: () => setState(() => _stage = _EveningStage.end),
          ),
        );
      case _EveningStage.end:
        return _asyncBody(
          ref.watch(afterPartyProvider(widget.eventId)),
          (afterParty) => _EndStage(
            state: afterParty,
            rating: _rating == 0 ? afterParty.hostRating ?? 0 : _rating,
            favoriteUserIds: _effectiveFavoriteUserIds(afterParty),
            saving: _savingFeedback,
            onRatingChanged: (rating) => setState(() => _rating = rating),
            onToggleFavorite: (userId) =>
                _toggleFavorite(userId, afterParty.favoriteUserIds),
            onDone: () => _saveFeedbackAndClose(afterParty),
          ),
        );
    }
  }

  Widget _asyncBody<T>(
    AsyncValue<T> value,
    Widget Function(T data) builder,
  ) {
    return value.when(
      data: builder,
      loading: () => const _EveningLoadingCard(),
      error: (error, _) => _EveningErrorCard(message: error.toString()),
    );
  }

  Future<void> _confirmCheckIn(EventCheckInData state) async {
    if (_checkInBusy) {
      return;
    }
    setState(() => _checkInBusy = true);
    try {
      final repository = ref.read(backendRepositoryProvider);
      await repository.confirmCheckIn(widget.eventId, code: state.code);
      if (!mounted) {
        return;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      container.invalidate(checkInProvider(widget.eventId));
      container.invalidate(eventDetailProvider(widget.eventId));
      container.invalidate(liveMeetupProvider(widget.eventId));
      setState(() => _stage = _EveningStage.live);
    } finally {
      if (mounted) {
        setState(() => _checkInBusy = false);
      }
    }
  }

  Set<String> _effectiveFavoriteUserIds(AfterPartyData state) {
    if (_favoriteUserIdsDirty) {
      return _favoriteUserIds;
    }
    return state.favoriteUserIds.toSet();
  }

  void _toggleFavorite(String userId, List<String> savedFavoriteUserIds) {
    setState(() {
      if (!_favoriteUserIdsDirty) {
        _favoriteUserIds
          ..clear()
          ..addAll(savedFavoriteUserIds);
        _favoriteUserIdsDirty = true;
      }
      if (_favoriteUserIds.contains(userId)) {
        _favoriteUserIds.remove(userId);
      } else {
        _favoriteUserIds.add(userId);
      }
    });
  }

  Future<void> _saveFeedbackAndClose(AfterPartyData state) async {
    if (_savingFeedback) {
      return;
    }
    setState(() => _savingFeedback = true);
    try {
      final repository = ref.read(backendRepositoryProvider);
      final favoriteUserIds = _favoriteUserIdsDirty
          ? _favoriteUserIds
          : state.favoriteUserIds.toSet();
      await repository.saveAfterParty(
        widget.eventId,
        vibe: state.vibe ?? 'cozy',
        hostRating: _rating == 0 ? state.hostRating ?? 5 : _rating,
        favoriteUserIds: favoriteUserIds.toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      container.invalidate(afterPartyProvider(widget.eventId));
      container.invalidate(eventDetailProvider(widget.eventId));
      context.goRoute(AppRoute.tonight);
    } finally {
      if (mounted) {
        setState(() => _savingFeedback = false);
      }
    }
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
                title: eventTitle ?? 'Вечер',
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

class _StageTabs extends StatelessWidget {
  const _StageTabs({
    required this.active,
    required this.onChanged,
  });

  final _EveningStage active;
  final ValueChanged<_EveningStage> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          children: [
            for (final stage in _EveningStage.values) ...[
              BbV5Chip(
                label: stage.label,
                active: stage == active,
                onTap: () => onChanged(stage),
              ),
              if (stage != _EveningStage.values.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteStage extends StatelessWidget {
  const _RouteStage({
    required this.event,
    required this.onCheckIn,
    required this.onLive,
  });

  final EventDetail event;
  final VoidCallback onCheckIn;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    final checkedIn = event.attendanceStatus == EventAttendanceStatus.checkedIn;
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
              Text(event.title, style: bbV5DisplayStyle(fontSize: 24)),
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
        const SizedBox(height: 20),
        _TimelinePoint(
          active: !checkedIn,
          done: checkedIn,
          icon: LucideIcons.map_pin,
          title: event.place,
          subtitle: 'Приходи на точку и подтверди чек-ин',
        ),
        _TimelinePoint(
          active: checkedIn,
          done: false,
          icon: LucideIcons.radio,
          title: 'Live-панель',
          subtitle: 'Участники, чат, сторис и быстрый SOS',
        ),
        const SizedBox(height: 18),
        BbV5PillButton(
          label: checkedIn ? 'Перейти в Live' : 'Начать чек-ин',
          icon: checkedIn ? LucideIcons.radio : LucideIcons.circle_check,
          dark: true,
          height: 54,
          expanded: true,
          onPressed: checkedIn ? onLive : onCheckIn,
        ),
      ],
    );
  }
}

class _CheckInStage extends StatelessWidget {
  const _CheckInStage({
    required this.state,
    required this.busy,
    required this.onConfirm,
    required this.onLive,
  });

  final EventCheckInData state;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    final checkedIn = state.status == EventAttendanceStatus.checkedIn;
    final checkedInCount = state.attendees
        .where(
          (attendee) =>
              attendee.attendanceStatus == EventAttendanceStatus.checkedIn,
        )
        .length;

    return Column(
      children: [
        BbV5Card(
          tint: BbV5Colors.brandSoft,
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: BbV5Colors.paperHi,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: const Icon(
                  LucideIcons.map_pin_check,
                  color: BbV5Colors.accent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              const BbV5Kicker('чек-ин'),
              const SizedBox(height: 6),
              Text(
                state.title,
                textAlign: TextAlign.center,
                style: bbV5DisplayStyle(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                state.place,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                checkedIn
                    ? 'Ты уже отмечен'
                    : 'Покажи код хосту или подтверди здесь',
                textAlign: TextAlign.center,
                style: AppTextStyles.meta.copyWith(
                  color: checkedIn ? BbV5Colors.sage : BbV5Colors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: LucideIcons.users,
                label: 'На месте',
                value: '$checkedInCount/${state.attendees.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(
                icon: LucideIcons.key_round,
                label: 'Код',
                value: state.code,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AttendeeList(
          attendees: state.attendees
              .map(
                (attendee) => _AttendeeItem(
                  userId: attendee.userId,
                  displayName: attendee.displayName,
                  avatarUrl: attendee.avatarUrl,
                  checkedIn: attendee.attendanceStatus ==
                      EventAttendanceStatus.checkedIn,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        BbV5PillButton(
          label: checkedIn
              ? 'Перейти в Live'
              : busy
                  ? 'Отмечаем'
                  : 'Подтвердить чек-ин',
          icon: checkedIn ? LucideIcons.radio : LucideIcons.circle_check,
          dark: true,
          height: 54,
          expanded: true,
          onPressed: busy ? null : (checkedIn ? onLive : onConfirm),
        ),
      ],
    );
  }
}

class _LiveStage extends StatelessWidget {
  const _LiveStage({
    required this.live,
    required this.onChat,
    required this.onMoment,
    required this.onShare,
    required this.onAfter,
  });

  final LiveMeetupData live;
  final VoidCallback? onChat;
  final VoidCallback onMoment;
  final VoidCallback onShare;
  final VoidCallback onAfter;

  @override
  Widget build(BuildContext context) {
    final checkedInCount = live.attendees
        .where(
          (attendee) =>
              attendee.attendanceStatus == EventAttendanceStatus.checkedIn,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5Card(
          tint: BbV5Colors.terraSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BbV5Kicker('вечер идёт'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: BbV5Colors.terra.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: BbV5Colors.terra,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: bbV5KickerStyle(
                            color: BbV5Colors.terra,
                            fontSize: 10,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(live.title, style: bbV5DisplayStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                '${live.place} · ${_elapsedLabel(live.elapsedMinutes)}',
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: LucideIcons.users,
                      label: 'На месте',
                      value: '$checkedInCount/${live.attendees.length}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      icon: LucideIcons.camera,
                      label: 'Моментов',
                      value: '${live.storiesCount}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AttendeeList(
          attendees: live.attendees
              .map(
                (attendee) => _AttendeeItem(
                  userId: attendee.userId,
                  displayName: attendee.displayName,
                  avatarUrl: attendee.avatarUrl,
                  checkedIn: attendee.attendanceStatus ==
                      EventAttendanceStatus.checkedIn,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SquareAction(
                icon: LucideIcons.message_circle,
                label: 'Чат',
                onTap: onChat,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SquareAction(
                icon: LucideIcons.camera,
                label: 'Момент',
                onTap: onMoment,
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
          label: 'Продлить вечер',
          icon: LucideIcons.party_popper,
          dark: true,
          height: 54,
          expanded: true,
          onPressed: onAfter,
        ),
      ],
    );
  }
}

class _AfterStage extends StatelessWidget {
  const _AfterStage({
    required this.state,
    required this.favoriteUserIds,
    required this.onToggleFavorite,
    required this.onShare,
  });

  final AfterPartyData state;
  final Set<String> favoriteUserIds;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5Card(
          tint: BbV5Colors.brandSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BbV5Kicker('after-party'),
              const SizedBox(height: 8),
              Text(
                'Куда дальше?',
                style: bbV5DisplayStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'Пока backend не отдаёт варианты голосования, экран показывает реальные действия вечера: участники, лайки и переход к итогу.',
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.attendees.isEmpty)
          const _EveningInfoCard(
            icon: LucideIcons.users,
            title: 'Участники ещё не загрузились',
            subtitle: 'Вернись к Live или попробуй позже',
          )
        else
          _FavoritePeopleList(
            attendees: state.attendees,
            favoriteUserIds: favoriteUserIds,
            onToggleFavorite: onToggleFavorite,
          ),
        const SizedBox(height: 18),
        BbV5PillButton(
          label: 'Завершить и поделиться',
          icon: LucideIcons.share_2,
          dark: true,
          height: 54,
          expanded: true,
          onPressed: onShare,
        ),
      ],
    );
  }
}

class _ShareStage extends StatelessWidget {
  const _ShareStage({
    required this.event,
    required this.live,
    required this.onStories,
    required this.onSave,
  });

  final EventDetail event;
  final LiveMeetupData? live;
  final VoidCallback onStories;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final peopleCount = live?.attendees.length ?? event.going;
    final storiesCount = live?.storiesCount ?? 0;
    return Column(
      children: [
        BbV5Card(
          tint: BbV5Colors.terraSoft,
          child: Column(
            children: [
              const BbV5Kicker('frendly memory'),
              const SizedBox(height: 10),
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: bbV5DisplayStyle(fontSize: 26),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const _MemoryStat(value: '1', label: 'место'),
                  _MemoryStat(value: '$peopleCount', label: 'людей'),
                  _MemoryStat(value: '$storiesCount', label: 'моментов'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                event.place,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SquareAction(
                icon: LucideIcons.share_2,
                label: 'В Stories',
                onTap: onStories,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SquareAction(
                icon: LucideIcons.camera,
                label: 'Сохранить',
                onTap: onSave,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SquareAction(
                icon: LucideIcons.heart,
                label: 'Лайк всем',
                onTap: onSave,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        BbV5PillButton(
          label: 'Оставить след вечера',
          trailingIcon: LucideIcons.chevron_right,
          dark: true,
          height: 54,
          expanded: true,
          onPressed: onSave,
        ),
      ],
    );
  }
}

class _EndStage extends StatelessWidget {
  const _EndStage({
    required this.state,
    required this.rating,
    required this.favoriteUserIds,
    required this.saving,
    required this.onRatingChanged,
    required this.onToggleFavorite,
    required this.onDone,
  });

  final AfterPartyData state;
  final int rating;
  final Set<String> favoriteUserIds;
  final bool saving;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BbV5Card(
          child: Column(
            children: [
              const BbV5Kicker('как вечер?'),
              const SizedBox(height: 8),
              Text(
                'Оцени по ощущениям',
                textAlign: TextAlign.center,
                style: bbV5DisplayStyle(fontSize: 22),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) {
                    final value = index + 1;
                    final active = value <= rating;
                    return IconButton(
                      onPressed: () => onRatingChanged(value),
                      icon: Icon(
                        LucideIcons.star,
                        color: active ? BbV5Colors.accent : BbV5Colors.inkMute,
                        fill: active ? 1 : 0,
                        size: 32,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FavoritePeopleList(
          attendees: state.attendees,
          favoriteUserIds: favoriteUserIds,
          onToggleFavorite: onToggleFavorite,
        ),
        const SizedBox(height: 12),
        const _EveningInfoCard(
          icon: LucideIcons.sparkles,
          title: 'Отзыв сохранится в историю вечера',
          subtitle: 'Начисление токенов остаётся на стороне текущего backend',
        ),
        const SizedBox(height: 18),
        BbV5PillButton(
          label: saving ? 'Сохраняем' : 'Готово',
          icon: LucideIcons.check,
          dark: true,
          height: 54,
          expanded: true,
          onPressed: saving ? null : onDone,
        ),
      ],
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({
    required this.active,
    required this.done,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool active;
  final bool done;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final markerColor = done || active ? BbV5Colors.accent : BbV5Colors.paperHi;
    final markerFg = done || active ? BbV5Colors.paperHi : BbV5Colors.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: done || active ? BbV5Colors.accent : BbV5Colors.hair,
              ),
              boxShadow: active ? BbV5Shadows.pill : null,
            ),
            child: Icon(
              done ? LucideIcons.check : icon,
              size: 15,
              color: markerFg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BbV5Card(
              radius: 20,
              padding: const EdgeInsets.all(14),
              borderColor: active ? BbV5Colors.accent : BbV5Colors.hair,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.itemTitle.copyWith(
                      color: BbV5Colors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ),
        ],
      ),
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
            style: bbV5DisplayStyle(fontSize: 16),
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

class _MemoryStat extends StatelessWidget {
  const _MemoryStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: bbV5DisplayStyle(fontSize: 26)),
          const SizedBox(height: 5),
          Text(
            label,
            style: bbV5KickerStyle(
              color: BbV5Colors.inkMute,
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeList extends StatelessWidget {
  const _AttendeeList({required this.attendees});

  final List<_AttendeeItem> attendees;

  @override
  Widget build(BuildContext context) {
    if (attendees.isEmpty) {
      return const _EveningInfoCard(
        icon: LucideIcons.users,
        title: 'Участников пока нет',
        subtitle: 'Список появится после обновления встречи',
      );
    }

    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(children: attendees),
    );
  }
}

class _AttendeeItem extends StatelessWidget {
  const _AttendeeItem({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.checkedIn,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          BbAvatar(name: displayName, imageUrl: avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
            ),
          ),
          Text(
            checkedIn ? 'на месте' : 'ждет',
            style: AppTextStyles.caption.copyWith(
              color: checkedIn ? BbV5Colors.sage : BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritePeopleList extends StatelessWidget {
  const _FavoritePeopleList({
    required this.attendees,
    required this.favoriteUserIds,
    required this.onToggleFavorite,
  });

  final List<AfterPartyAttendee> attendees;
  final Set<String> favoriteUserIds;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    if (attendees.isEmpty) {
      return const _EveningInfoCard(
        icon: LucideIcons.heart,
        title: 'Некого отметить',
        subtitle: 'Когда участники будут в after-party, они появятся здесь',
      );
    }

    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: attendees.map((attendee) {
          final selected = favoriteUserIds.contains(attendee.userId);
          return Padding(
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
                IconButton(
                  onPressed: () => onToggleFavorite(attendee.userId),
                  icon: Icon(
                    LucideIcons.heart,
                    color: selected ? BbV5Colors.accent : BbV5Colors.inkMute,
                    fill: selected ? 1 : 0,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BbV5Colors.paperHi, BbV5Colors.paper],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Column(
            children: [
              Icon(icon, size: 17, color: BbV5Colors.ink),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkSoft,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
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
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: BbV5Colors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, size: 18, color: BbV5Colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.itemTitle),
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
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
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
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySoft.copyWith(color: BbV5Colors.inkSoft),
      ),
    );
  }
}

String _elapsedLabel(int minutes) {
  if (minutes <= 0) {
    return 'только началось';
  }
  if (minutes < 60) {
    return '$minutes мин';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) {
    return '$hours ч';
  }
  return '$hours ч $rest мин';
}
