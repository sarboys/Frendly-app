import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/meetup_chat/presentation/meetup_invite_sheet.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/utils/event_time_labels.dart';
import 'package:big_break_mobile/shared/widgets/async_value_view.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({
    required this.eventId,
    super.key,
  });

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _actionBusy = false;

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return BbV5Scaffold(
      child: AsyncValueView<EventDetail>(
        value: eventAsync,
        data: (event) {
          final hasPendingJoinRequest = !event.joined &&
              event.joinRequestStatus == EventJoinRequestStatus.pending;
          return _EventDetailBody(
            event: event,
            actionBusy: _actionBusy,
            onJoinOrOpen: _actionBusy || hasPendingJoinRequest
                ? null
                : () async {
                    final requiresRequest =
                        event.joinMode == EventJoinMode.request ||
                            event.accessMode == 'request' ||
                            event.visibilityMode == 'friends';

                    if (event.isHost) {
                      if (context.mounted) {
                        context.pushRoute(
                          AppRoute.hostEvent,
                          pathParameters: {'eventId': event.id},
                        );
                      }
                      return;
                    }

                    if (event.joined) {
                      if (context.mounted) {
                        context.pushRoute(
                          AppRoute.eveningFlow,
                          pathParameters: {'eventId': event.id},
                        );
                      }
                      return;
                    }

                    if (!event.joined && requiresRequest) {
                      if (context.mounted) {
                        context.pushRoute(
                          AppRoute.joinRequest,
                          pathParameters: {'eventId': event.id},
                        );
                      }
                      return;
                    }

                    final repository = ref.read(backendRepositoryProvider);
                    final container = ProviderScope.containerOf(
                      context,
                      listen: false,
                    );
                    setState(() {
                      _actionBusy = true;
                    });
                    try {
                      final detail = event.joined
                          ? event
                          : await repository.joinEvent(event.id);
                      if (!mounted) {
                        return;
                      }
                      container.invalidate(eventDetailProvider(event.id));
                      container.invalidate(eventsProvider('nearby'));
                      container.invalidate(mapEventsProvider);
                      container.invalidate(eventsProvider('now'));
                      container.invalidate(eventsProvider('calm'));
                      container.invalidate(eventsProvider('newcomers'));
                      container.invalidate(eventsProvider('date'));
                      container.invalidate(meetupChatsProvider);
                      if (context.mounted) {
                        context.pushRoute(
                          AppRoute.eveningFlow,
                          pathParameters: {'eventId': detail.id},
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Не получилось обновить участие')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _actionBusy = false;
                        });
                      }
                    }
                  },
            onInvite: event.joined || event.isHost
                ? () => showMeetupInviteSheet(
                      context,
                      eventId: event.id,
                      title: event.title,
                    )
                : null,
            onSecondaryAction: _actionBusy
                ? null
                : (!event.joined &&
                            event.joinRequestStatus ==
                                EventJoinRequestStatus.pending) ||
                        (event.joined && !event.isHost)
                    ? () async {
                        final repository = ref.read(backendRepositoryProvider);
                        final container = ProviderScope.containerOf(
                          context,
                          listen: false,
                        );
                        setState(() {
                          _actionBusy = true;
                        });
                        try {
                          if (!event.joined &&
                              event.joinRequestStatus ==
                                  EventJoinRequestStatus.pending) {
                            await repository.cancelJoinRequest(event.id);
                          } else if (event.joined && !event.isHost) {
                            await repository.leaveEvent(event.id);
                          }

                          if (!mounted) {
                            return;
                          }
                          container.invalidate(eventDetailProvider(event.id));
                          container.invalidate(eventsProvider('nearby'));
                          container.invalidate(mapEventsProvider);
                          container.invalidate(eventsProvider('now'));
                          container.invalidate(eventsProvider('calm'));
                          container.invalidate(eventsProvider('newcomers'));
                          container.invalidate(eventsProvider('date'));
                          container.invalidate(meetupChatsProvider);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Не получилось обновить заявку')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _actionBusy = false;
                            });
                          }
                        }
                      }
                    : null,
          );
        },
      ),
    );
  }
}

class _EventDetailBody extends StatelessWidget {
  const _EventDetailBody({
    required this.event,
    required this.onJoinOrOpen,
    required this.actionBusy,
    this.onInvite,
    this.onSecondaryAction,
  });

  final EventDetail event;
  final Future<void> Function()? onJoinOrOpen;
  final bool actionBusy;
  final VoidCallback? onInvite;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final requiresRequest = event.joinMode == EventJoinMode.request ||
        event.accessMode == 'request' ||
        event.visibilityMode == 'friends';
    final hasPendingJoinRequest = !event.joined &&
        event.joinRequestStatus == EventJoinRequestStatus.pending;
    final criteria = _buildCriteria(event);
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      BbV5IconButton(
                        icon: LucideIcons.arrow_left,
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BbV5Kicker('Встреча · ${event.distance}'),
                            const SizedBox(height: 2),
                            Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bbV5DisplayStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (event.isHost) ...[
                        BbV5IconButton(
                          icon: LucideIcons.pencil,
                          onPressed: () => context.pushRoute(
                            AppRoute.createMeetup,
                            queryParameters: {'editEventId': event.id},
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      if (onInvite != null) ...[
                        BbV5IconButton(
                          icon: LucideIcons.user_plus,
                          onPressed: onInvite,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      BbV5IconButton(
                        icon: LucideIcons.share_2,
                        onPressed: () => context.pushRoute(
                          AppRoute.shareCard,
                          pathParameters: {'eventId': event.id},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _V5MeetupHeroCard(event: event),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _V5HostCard(event: event),
                ),
              ),
              if (event.hostNote != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _V5HostQuote(note: event.hostNote!),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 0, 0),
                sliver: SliverToBoxAdapter(
                  child: _V5AttendeesRail(event: event),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _V5MiniMapCard(event: event),
                ),
              ),
              if (event.hasTableBooking)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _V5BookingCard(event: event),
                  ),
                ),
              if (criteria.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: BbV5Section(
                      title: 'Условия',
                      margin: EdgeInsets.zero,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final criterion in criteria)
                            BbV5Chip(label: criterion),
                        ],
                      ),
                    ),
                  ),
                ),
              if (event.partnerName != null || event.partnerOffer != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _V5PerkCard(event: event),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _V5SafeWalkCard(event: event),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
                sliver: SliverToBoxAdapter(
                  child: TextButton.icon(
                    onPressed: () => context.pushRoute(
                      AppRoute.report,
                      pathParameters: {'userId': event.host.id},
                    ),
                    icon: const Icon(LucideIcons.flag, size: 12),
                    label: const Text('Пожаловаться на встречу'),
                    style: TextButton.styleFrom(
                      foregroundColor: BbV5Colors.inkMute,
                      textStyle: AppTextStyles.meta.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  BbV5Colors.paper.withValues(alpha: 0),
                  BbV5Colors.paper.withValues(alpha: 0.96),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (event.hasPaidTicket)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _V5TicketBottomAction(event: event),
                      ),
                    if (event.hasTableBooking)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _V5BookingBottomAction(event: event),
                      ),
                    if (onSecondaryAction != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: TextButton(
                          onPressed: onSecondaryAction,
                          child: Text(
                            actionBusy
                                ? 'Подождите'
                                : event.joined
                                    ? 'Выйти из встречи'
                                    : 'Отменить заявку',
                            style: AppTextStyles.meta.copyWith(
                              color: BbV5Colors.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: BbV5Colors.paperHi,
                            shape: BoxShape.circle,
                            border: Border.all(color: BbV5Colors.hair),
                            boxShadow: BbV5Shadows.pill,
                          ),
                          child: IconButton(
                            onPressed: event.chatId == null
                                ? null
                                : () => context.pushRoute(
                                      AppRoute.meetupChat,
                                      pathParameters: {'chatId': event.chatId!},
                                    ),
                            icon: const Icon(LucideIcons.message_circle),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: event.joined
                                    ? BbV5Colors.ink
                                    : hasPendingJoinRequest
                                        ? BbV5Colors.inkSoft
                                        : BbV5Colors.accent,
                                disabledBackgroundColor: hasPendingJoinRequest
                                    ? BbV5Colors.inkSoft
                                    : null,
                                disabledForegroundColor: BbV5Colors.paperHi,
                                foregroundColor: BbV5Colors.paperHi,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: onJoinOrOpen,
                              child: Text(
                                actionBusy
                                    ? 'Подождите'
                                    : event.isHost
                                        ? 'Открыть хост-панель'
                                        : event.joined
                                            ? 'Начать вечер'
                                            : hasPendingJoinRequest
                                                ? 'Заявка отправлена'
                                                : requiresRequest
                                                    ? 'Отправить заявку'
                                                    : 'Присоединиться',
                                style: AppTextStyles.button.copyWith(
                                  color: BbV5Colors.paperHi,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _buildCriteria(EventDetail event) {
    final criteria = <String>[];

    if (event.capacity > 0) {
      criteria.add('До ${event.capacity} участников');
    }

    final lifestyle = _lifestyleLabel(event.lifestyle);
    if (lifestyle != null) {
      criteria.add(lifestyle);
    }

    final price = _priceLabel(event);
    if (price != null) {
      criteria.add(price);
    }

    final access = _accessLabel(event.accessMode);
    if (access != null) {
      criteria.add(access);
    }

    final gender = _genderLabel(event.genderMode);
    if (gender != null) {
      criteria.add(gender);
    }

    return criteria;
  }

  String? _lifestyleLabel(String? raw) {
    switch (raw) {
      case 'zozh':
        return 'ЗОЖ';
      case 'neutral':
        return 'Нейтрально';
      case 'anti':
        return 'Не ЗОЖ';
      default:
        return null;
    }
  }

  String? _priceLabel(EventDetail event) {
    switch (event.priceMode) {
      case 'free':
        return 'Бесплатно';
      case 'split':
        return 'Скидываемся';
      case 'fixed':
        return event.priceAmountFrom == null
            ? null
            : '${event.priceAmountFrom} ₽';
      case 'from':
        return event.priceAmountFrom == null
            ? null
            : 'от ${event.priceAmountFrom} ₽';
      case 'upto':
        return event.priceAmountTo == null
            ? null
            : 'до ${event.priceAmountTo} ₽';
      case 'range':
        if (event.priceAmountFrom != null && event.priceAmountTo != null) {
          return '${event.priceAmountFrom}-${event.priceAmountTo} ₽';
        }
        if (event.priceAmountFrom != null) {
          return 'от ${event.priceAmountFrom} ₽';
        }
        if (event.priceAmountTo != null) {
          return 'до ${event.priceAmountTo} ₽';
        }
        return null;
      default:
        return null;
    }
  }

  String? _genderLabel(String? raw) {
    switch (raw) {
      case 'all':
        return 'Все';
      case 'female':
        return 'Девушки';
      case 'male':
        return 'Парни';
      default:
        return null;
    }
  }

  String? _accessLabel(String? raw) {
    switch (raw) {
      case 'open':
        return 'Открытое вступление';
      case 'request':
        return 'По заявке';
      case 'free':
        return 'Свободный приход';
      default:
        return null;
    }
  }
}

class _V5MeetupHeroCard extends StatelessWidget {
  const _V5MeetupHeroCard({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: EdgeInsets.zero,
      radius: 28,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [BbV5Colors.terraSoft, BbV5Colors.brandSoft],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Text(
                      event.emoji,
                      style: const TextStyle(fontSize: 104, height: 1),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BbV5Kicker('${event.vibe} · ${event.time}'),
                        const SizedBox(height: 6),
                        BbV5HeroTitle(
                          title: _titleLead(event.title),
                          accent: _titleAccent(event.title),
                          fontSize: 26,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
              children: [
                _V5InfoTile(
                  icon: LucideIcons.calendar,
                  label: 'Когда',
                  value: eventDayLabel(
                    time: event.time,
                    startsAtIso: event.startsAtIso,
                  ),
                  subtitle: eventClockLabel(event.time),
                ),
                _V5InfoTile(
                  icon: LucideIcons.map_pin,
                  label: 'Где',
                  value: _shortPlace(event.place),
                  subtitle: event.distance,
                ),
                _V5InfoTile(
                  icon: LucideIcons.users,
                  label: 'Идут',
                  value: '${event.going}/${event.capacity}',
                  subtitle:
                      event.accessMode == 'request' ? 'По заявке' : 'Открытое',
                ),
                const _V5InfoTile(
                  icon: LucideIcons.clock,
                  label: 'Длительность',
                  value: '≈ 2 часа',
                  subtitle: 'до 23:00',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _V5InfoTile extends StatelessWidget {
  const _V5InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: BbV5Colors.inkMute),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5KickerStyle(letterSpacing: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bbV5DisplayStyle(fontSize: 13, height: 1.25).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _V5TicketBottomAction extends StatelessWidget {
  const _V5TicketBottomAction({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BbV5Colors.accent),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.ticket,
            size: 18,
            color: BbV5Colors.accentDeep,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _ticketSubtitle(event),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.inkSoft,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          BbV5PillButton(
            label: 'Купить билет',
            icon: LucideIcons.ticket,
            height: 40,
            fontSize: 12,
            dark: true,
            onPressed: () => _openEventTicketUrl(context, event.ticketUrl!),
          ),
        ],
      ),
    );
  }
}

class _V5BookingBottomAction extends StatelessWidget {
  const _V5BookingBottomAction({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.calendar_check,
            size: 18,
            color: BbV5Colors.terra,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _bookingSubtitle(event),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.inkSoft,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          BbV5PillButton(
            label: 'Забронировать столик',
            icon: LucideIcons.calendar_check,
            height: 40,
            fontSize: 12,
            dark: true,
            onPressed: () => _openEventBookingUrl(context, event.bookingUrl!),
          ),
        ],
      ),
    );
  }
}

class _V5BookingCard extends StatelessWidget {
  const _V5BookingCard({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    final promos = event.bookingPromos.take(3).toList(growable: false);
    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.calendar_check,
                size: 18,
                color: BbV5Colors.terra,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Бронь столика',
                  style: bbV5DisplayStyle(fontSize: 18, height: 1.15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _bookingSubtitle(event),
            style: AppTextStyles.body.copyWith(
              color: BbV5Colors.inkSoft,
              height: 1.35,
            ),
          ),
          if (promos.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final promo in promos)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.badge_percent,
                      size: 14,
                      color: BbV5Colors.terra,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        promo.title,
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _V5HostCard extends StatelessWidget {
  const _V5HostCard({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BbV5Kicker('Хост вечера'),
          const SizedBox(height: 8),
          Row(
            children: [
              BbAvatar(
                name: event.host.displayName,
                size: BbAvatarSize.lg,
                online: true,
                imageUrl: event.host.avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.host.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bbV5DisplayStyle(fontSize: 14),
                          ),
                        ),
                        if (event.host.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.badge_check,
                            size: 15,
                            color: BbV5Colors.brandDeep,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.star,
                          size: 13,
                          color: BbV5Colors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.host.rating.toStringAsFixed(1)} · ${event.host.meetupCount} встреч',
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkMute,
                            letterSpacing: 0,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              BbV5PillButton(
                label: 'Профиль',
                height: 36,
                fontSize: 11.5,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: () {
                  if (event.isHost) {
                    context.pushRoute(AppRoute.profile);
                    return;
                  }

                  context.pushRoute(
                    AppRoute.userProfile,
                    pathParameters: {'userId': event.host.id},
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _V5HostQuote extends StatelessWidget {
  const _V5HostQuote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BbV5Kicker('От хоста'),
          const SizedBox(height: 8),
          Text(
            '«$note»',
            style: AppTextStyles.body.copyWith(
              fontFamily: 'InstrumentSerif',
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: BbV5Colors.inkSoft,
              height: 1.625,
            ),
          ),
        ],
      ),
    );
  }
}

class _V5AttendeesRail extends StatelessWidget {
  const _V5AttendeesRail({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    final seenUserIds = <String>{event.host.id};
    final cards = <_V5AttendeeData>[
      _V5AttendeeData(
        id: event.host.id,
        name: event.host.displayName,
        role: 'Хост',
        avatarUrl: event.host.avatarUrl,
        verified: event.host.verified,
      ),
    ];
    for (final attendee in event.attendees) {
      if (!seenUserIds.add(attendee.id)) {
        continue;
      }
      cards.add(
        _V5AttendeeData(
          id: attendee.id,
          name: attendee.displayName,
          role: 'идёт',
          avatarUrl: attendee.avatarUrl,
          verified: false,
        ),
      );
    }
    final count = event.going > 0 ? event.going : cards.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            children: [
              Expanded(child: BbV5Kicker('Кто идёт · $count')),
              Text(
                'Все ›',
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.terra,
                  fontFamily: 'Sora',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 20),
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _V5AttendeeCard(
              attendee: cards[index],
              index: index,
            ),
          ),
        ),
      ],
    );
  }
}

class _V5AttendeeData {
  const _V5AttendeeData({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.verified,
  });

  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final bool verified;
}

class _V5AttendeeCard extends StatelessWidget {
  const _V5AttendeeCard({
    required this.attendee,
    required this.index,
  });

  final _V5AttendeeData attendee;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: BbAvatar(
                    name: attendee.name,
                    imageUrl: attendee.avatarUrl,
                    size: BbAvatarSize.xl,
                  ),
                ),
                if (attendee.verified)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(
                      LucideIcons.badge_check,
                      color: BbV5Colors.brandDeep,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${attendee.name}${index == 0 ? '' : ', ${24 + index}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: BbV5Colors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            attendee.role,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 10,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _V5MiniMapCard extends StatelessWidget {
  const _V5MiniMapCard({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.4, -0.2),
                        radius: 1.0,
                        colors: [BbV5Colors.brandSoft, BbV5Colors.terraSoft],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _MiniMapPainter()),
                ),
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BbV5Colors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BbV5Colors.paperHi.withValues(alpha: 0.7),
                        width: 6,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                      boxShadow: BbV5Shadows.ink,
                    ),
                    child: const Icon(
                      LucideIcons.map_pin,
                      size: 18,
                      color: BbV5Colors.paperHi,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showEventMapOptions(context, event),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bbV5DisplayStyle(fontSize: 13.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.distance} · в 15 минутах от тебя',
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkMute,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                BbV5PillButton(
                  label: 'Маршрут',
                  icon: LucideIcons.navigation,
                  height: 40,
                  fontSize: 12,
                  onPressed: () => context.pushRoute(
                    AppRoute.map,
                    queryParameters: {'eventId': event.id},
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

Future<void> _showEventMapOptions(
  BuildContext context,
  EventDetail event,
) async {
  final query = event.place.trim();
  if (query.isEmpty) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Открыть адрес',
                style: bbV5DisplayStyle(fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              _EventMapOption(
                icon: LucideIcons.map,
                title: 'Google Карты',
                subtitle: query,
                onTap: () => _openEventMapUrl(
                  context,
                  sheetContext,
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': query,
                  }),
                ),
              ),
              _EventMapOption(
                icon: LucideIcons.navigation,
                title: 'Яндекс Карты',
                subtitle: query,
                onTap: () => _openEventMapUrl(
                  context,
                  sheetContext,
                  Uri.https('yandex.ru', '/maps/', {'text': query}),
                ),
              ),
              Text(
                'Откроется внешнее приложение или браузер.',
                style: AppTextStyles.meta.copyWith(
                  color: BbV5Colors.inkMute,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _openEventMapUrl(
  BuildContext rootContext,
  BuildContext sheetContext,
  Uri uri,
) async {
  sheetContext.pop();
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !rootContext.mounted) {
    return;
  }
  ScaffoldMessenger.of(rootContext).showSnackBar(
    const SnackBar(content: Text('Не получилось открыть карты.')),
  );
}

Future<void> _openEventTicketUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не получилось открыть билет.')),
    );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Не получилось открыть билет.')),
  );
}

Future<void> _openEventBookingUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не получилось открыть бронь.')),
    );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Не получилось открыть бронь.')),
  );
}

String _ticketSubtitle(EventDetail event) {
  final parts = <String>[];
  final price = event.ticketPriceFrom;
  if (price != null && price > 0) {
    parts.add('от $price ₽');
  }
  final venue = event.ticketVenue?.trim();
  if (venue != null && venue.isNotEmpty) {
    parts.add(venue);
  }
  return parts.isEmpty ? 'Откроется внешний сайт' : parts.join(' · ');
}

String _bookingSubtitle(EventDetail event) {
  final parts = <String>[];
  final averageCheck = event.bookingAverageCheck;
  if (averageCheck != null && averageCheck > 0) {
    parts.add(
        'средний чек $averageCheck ${_currencySymbol(event.bookingCurrency)}');
  }
  final provider = event.bookingProvider?.trim();
  if (provider != null && provider.isNotEmpty) {
    parts.add(provider);
  }
  return parts.isEmpty
      ? 'Откроется внешний сайт бронирования'
      : parts.join(' · ');
}

String _currencySymbol(String? currency) {
  return currency == 'RUB' || currency == null ? '₽' : currency;
}

class _EventMapOption extends StatelessWidget {
  const _EventMapOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbV5Colors.paperHi,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              Icon(icon, color: BbV5Colors.ink, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: bbV5DisplayStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BbV5Colors.ink.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..lineTo(size.width * 0.3, size.height * 0.28)
      ..lineTo(size.width * 0.6, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.36);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * 0.1, 0),
      Offset(size.width * 0.15, size.height),
      paint..color = BbV5Colors.ink.withValues(alpha: 0.08),
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.56, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _V5PerkCard extends StatelessWidget {
  const _V5PerkCard({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    final partner = event.partnerName ?? 'партнёра';
    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      borderColor: BbV5Colors.terraSoft,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BbV5Colors.terraSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.gift,
              size: 18,
              color: BbV5Colors.accentDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Бонус от $partner',
                  style: bbV5DisplayStyle(fontSize: 12.5, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text(
                  event.partnerOffer ?? 'Перк появится после проверки места',
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.pushRoute(AppRoute.perks),
            style: TextButton.styleFrom(
              textStyle: AppTextStyles.button.copyWith(fontSize: 11),
              foregroundColor: BbV5Colors.terra,
            ),
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }
}

class _V5SafeWalkCard extends StatelessWidget {
  const _V5SafeWalkCard({required this.event});

  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    final verifiedCount = event.host.verified ? 1 : 0;
    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BbV5Colors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.shield,
              size: 18,
              color: BbV5Colors.brandDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Безопасный вечер',
                  style: bbV5DisplayStyle(fontSize: 12.5, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  'Хост и $verifiedCount участник верифицированы. Можешь поделиться маршрутом с близким.',
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkSoft,
                    fontSize: 11,
                    height: 1.625,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Safe Walk включен')),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: BbV5Colors.brandDeep,
                    textStyle: AppTextStyles.button.copyWith(fontSize: 11),
                  ),
                  child: const Text('Включить Safe Walk'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _titleLead(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.length <= 1) {
    return value;
  }
  return parts.take(parts.length - 1).join(' ');
}

String? _titleAccent(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.length <= 1) {
    return null;
  }
  return parts.last;
}

String _shortPlace(String value) {
  final comma = value.indexOf(',');
  if (comma <= 0) {
    return value;
  }
  return value.substring(0, comma).trim();
}
