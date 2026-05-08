import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/widgets/async_value_view.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        data: (event) => _EventDetailBody(
          event: event,
          actionBusy: _actionBusy,
          onJoinOrOpen: _actionBusy
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
                    if (context.mounted && detail.chatId != null) {
                      context.pushRoute(
                        AppRoute.meetupChat,
                        pathParameters: {'chatId': detail.chatId!},
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
                                content: Text('Не получилось обновить заявку')),
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
        ),
      ),
    );
  }
}

class _EventDetailBody extends StatelessWidget {
  const _EventDetailBody({
    required this.event,
    required this.onJoinOrOpen,
    required this.actionBusy,
    this.onSecondaryAction,
  });

  final EventDetail event;
  final Future<void> Function()? onJoinOrOpen;
  final bool actionBusy;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final requiresRequest = event.joinMode == EventJoinMode.request ||
        event.accessMode == 'request' ||
        event.visibilityMode == 'friends';
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
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _V5ProgramCard(),
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
                                    : BbV5Colors.accent,
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
                                            ? 'Открыть чат встречи'
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
                  value: 'Сегодня',
                  subtitle: event.time,
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

class _V5ProgramCard extends StatelessWidget {
  const _V5ProgramCard();

  static const _steps = [
    (
      LucideIcons.wine,
      'Brix Wine',
      '20:00 · бокал на старт',
      'Стартуем у барной стойки, знакомимся',
    ),
    (
      LucideIcons.coffee,
      'Прогулка по Покровке',
      '21:30 · 15 минут пешком',
      '',
    ),
    (
      LucideIcons.music,
      'Late jazz в Aglio',
      '22:00 · вечер закрываем под джаз',
      'Опционально, кто захочет',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'Программа вечера',
      right: Text(
        '3 шага',
        style: bbV5KickerStyle(letterSpacing: 1.8).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      margin: EdgeInsets.zero,
      child: BbV5Card(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            for (var index = 0; index < _steps.length; index++)
              _V5ProgramStep(
                icon: _steps[index].$1,
                title: _steps[index].$2,
                subtitle: _steps[index].$3,
                note: _steps[index].$4,
                showLine: index != _steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _V5ProgramStep extends StatelessWidget {
  const _V5ProgramStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.showLine,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String note;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BbV5Colors.paperHi,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: Icon(icon, size: 16, color: BbV5Colors.terra),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: BbV5Colors.hair,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 18 : 0, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: bbV5DisplayStyle(fontSize: 13.5, height: 1.25),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      letterSpacing: 0,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.inkSoft,
                        fontSize: 11.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
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
    final cards = [
      _V5AttendeeData(
        name: event.host.displayName,
        role: 'Хост',
        avatarUrl: event.host.avatarUrl,
        verified: event.host.verified,
      ),
      ...event.attendees.map(
        (attendee) => _V5AttendeeData(
          name: attendee.displayName,
          role: 'идёт',
          avatarUrl: attendee.avatarUrl,
          verified: false,
        ),
      ),
    ];
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
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.verified,
  });

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
    final partner = event.partnerName ?? 'Brix';
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
                  event.partnerOffer ??
                      'Бокал игристого на компанию 3+ при чек-ине',
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
