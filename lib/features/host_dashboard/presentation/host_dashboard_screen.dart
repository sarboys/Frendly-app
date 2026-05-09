import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/host_dashboard.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  const HostDashboardScreen({
    super.key,
    this.initialEventId,
  });

  final String? initialEventId;

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  _HostedMeetupsTab _tab = _HostedMeetupsTab.upcoming;
  final Set<String> _processingRequestIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(hostDashboardProvider);

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: dashboardAsync.when(
              data: _buildDashboard,
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: BbV5Colors.accent,
                ),
              ),
              error: (_, __) => _HostErrorState(
                onRetry: () => ref.invalidate(hostDashboardProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(HostDashboardData dashboard) {
    final wallet = ref.watch(tokenWalletProvider);
    final heroNames = <String>{
      ...dashboard.requests.map((request) => request.userName),
      ...dashboard.events.expand((event) => event.attendees),
    }.toList(growable: false);
    final visibleEvents = _eventsForTab(dashboard.events);

    return RefreshIndicator(
      color: BbV5Colors.accent,
      onRefresh: () async {
        ref.invalidate(hostDashboardProvider);
        await ref.read(hostDashboardProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          BbV5TopBar(
            kicker: 'Хост-панель',
            title: 'Твои',
            accent: 'вечера',
            right: _HostWalletBadge(
              balance: wallet.balance,
              onTap: () => context.pushRoute(AppRoute.wallet),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _HeroMetric(
            count: dashboard.stats.meetupsCount,
            pendingRequests: dashboard.pendingRequestsCount,
            names: heroNames,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _HostStatCard(
                icon: LucideIcons.calendar_days,
                value: '${dashboard.stats.meetupsCount}',
                label: 'Встреч',
              ),
              const SizedBox(width: AppSpacing.xs),
              _HostStatCard(
                icon: LucideIcons.star,
                value: dashboard.stats.rating.toStringAsFixed(1),
                label: 'Рейтинг',
              ),
              const SizedBox(width: AppSpacing.xs),
              _HostStatCard(
                icon: LucideIcons.trending_up,
                value: '${dashboard.stats.fillRate}%',
                label: 'Заполн.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _CreateMeetupCta(
            onTap: () => context.pushRoute(AppRoute.createMeetup),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RequestsSection(
            requests: dashboard.requests,
            busyIds: _processingRequestIds,
            onApprove: (request) => _reviewRequest(
              request,
              approve: true,
            ),
            onReject: (request) => _reviewRequest(
              request,
              approve: false,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _HostedTabs(
            tab: _tab,
            onChanged: (tab) {
              setState(() {
                _tab = tab;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visibleEvents.isEmpty)
            _HostedEmptyState(tab: _tab)
          else
            ...visibleEvents.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _HostedEventTile(
                  event: event,
                  promoted: wallet.isPromoted(event.id),
                  onTap: () => context.pushRoute(
                    AppRoute.eventDetail,
                    pathParameters: {'eventId': event.id},
                  ),
                  onPromote: () => _openPromoteSheet(event),
                  onOpenChat: () => context.pushRoute(
                    AppRoute.meetupChat,
                    pathParameters: {'chatId': event.id},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openPromoteSheet(Event event) async {
    final wallet = ref.read(tokenWalletProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: BbV5Colors.ink.withValues(alpha: 0.55),
      builder: (sheetContext) => _PromoteSheet(
        event: event,
        wallet: wallet,
        onPick: (option) async {
          final ok = await ref
              .read(tokenWalletProvider.notifier)
              .promote(event.id, option);
          if (!mounted || !sheetContext.mounted) {
            return;
          }
          Navigator.of(sheetContext).pop();
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Недостаточно токенов')),
            );
            context.pushRoute(AppRoute.wallet);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Встреча продвигается · ${option.title}')),
          );
        },
      ),
    );
  }

  List<Event> _eventsForTab(List<Event> events) {
    if (_tab == _HostedMeetupsTab.drafts) {
      return const [];
    }

    final now = DateTime.now();
    final filtered = events.where((event) {
      final startsAt = DateTime.tryParse(event.startsAtIso ?? '');
      if (startsAt == null) {
        return _tab == _HostedMeetupsTab.upcoming;
      }
      return _tab == _HostedMeetupsTab.upcoming
          ? startsAt.isAfter(now)
          : !startsAt.isAfter(now);
    }).toList(growable: false);

    final selected = widget.initialEventId;
    if (selected == null) {
      return filtered;
    }

    return [
      ...filtered.where((event) => event.id == selected),
      ...filtered.where((event) => event.id != selected),
    ];
  }

  Future<void> _reviewRequest(
    HostJoinRequest request, {
    required bool approve,
  }) async {
    if (_processingRequestIds.contains(request.id)) {
      return;
    }

    final repository = ref.read(backendRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);

    setState(() {
      _processingRequestIds.add(request.id);
    });

    try {
      if (approve) {
        await repository.approveJoinRequest(request.id);
      } else {
        await repository.rejectJoinRequest(request.id);
      }
      if (!mounted) {
        return;
      }
      container
        ..invalidate(hostDashboardProvider)
        ..invalidate(hostEventProvider(request.eventId))
        ..invalidate(eventDetailProvider(request.eventId))
        ..invalidate(liveMeetupProvider(request.eventId));
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? 'Заявка принята' : 'Заявка отклонена'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Не получилось принять заявку'
                : 'Не получилось отклонить заявку',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestIds.remove(request.id);
        });
      }
    }
  }
}

class _HostWalletBadge extends StatelessWidget {
  const _HostWalletBadge({
    required this.balance,
    required this.onTap,
  });

  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: BbV5Colors.paperHi,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: BbV5Colors.hair),
          boxShadow: BbV5Shadows.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.coins,
              size: 15,
              color: BbV5Colors.terra,
            ),
            const SizedBox(width: 6),
            Text(
              '$balance',
              style: AppTextStyles.caption.copyWith(
                fontFamily: 'Sora',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BbV5Colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HostedMeetupsTab { upcoming, past, drafts }

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.count,
    required this.pendingRequests,
    required this.names,
  });

  final int count;
  final int pendingRequests;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(20),
      radius: 28,
      tint: BbV5Colors.terraSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BbV5Kicker('Этот месяц'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: bbV5DisplayStyle(
                  fontSize: 44,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'встреч ты уже собрал',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                BbAvatarStack(
                  names: names,
                  size: BbAvatarSize.sm,
                  max: 5,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pendingRequests > 0
                        ? '+ ещё $pendingRequests заявки ждут ответа'
                        : 'Все новые заявки разобраны',
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HostStatCard extends StatelessWidget {
  const _HostStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BbV5Card(
        padding: const EdgeInsets.all(12),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: BbV5Colors.inkMute),
            const SizedBox(height: 8),
            Text(
              value,
              style: bbV5DisplayStyle(
                fontSize: 20,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: BbV5Colors.inkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateMeetupCta extends StatelessWidget {
  const _CreateMeetupCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BbV5Colors.accent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: BbV5Shadows.ink,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.plus,
                  color: BbV5Colors.paperHi,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Создать вечер',
                      style: AppTextStyles.itemTitle.copyWith(
                        color: BbV5Colors.paperHi,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Или собери через AI за минуту',
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.paperHi.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevron_right,
                size: 17,
                color: BbV5Colors.paperHi,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({
    required this.requests,
    required this.busyIds,
    required this.onApprove,
    required this.onReject,
  });

  final List<HostJoinRequest> requests;
  final Set<String> busyIds;
  final ValueChanged<HostJoinRequest> onApprove;
  final ValueChanged<HostJoinRequest> onReject;

  @override
  Widget build(BuildContext context) {
    final pendingCount = requests
        .where((request) => request.status == EventJoinRequestStatus.pending)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(child: BbV5Kicker('Новые заявки · $pendingCount')),
              Text(
                'Все',
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: BbV5Colors.terra,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                LucideIcons.chevron_right,
                size: 13,
                color: BbV5Colors.terra,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (requests.isEmpty)
          BbV5Card(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Text(
              'Новых заявок нет.',
              style: AppTextStyles.bodySoft.copyWith(
                color: BbV5Colors.inkSoft,
              ),
            ),
          )
        else
          ...requests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(
                request: request,
                busy: busyIds.contains(request.id),
                onApprove: () => onApprove(request),
                onReject: () => onReject(request),
              ),
            ),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final HostJoinRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final reviewed = request.status != EventJoinRequestStatus.pending;

    return BbV5Card(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbAvatar(
                name: request.userName,
                imageUrl: request.avatarUrl,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.itemTitle.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const Icon(
                          LucideIcons.star,
                          size: 12,
                          color: BbV5Colors.gold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${request.compatibilityScore}%',
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'на «${request.eventTitle}»',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                    if ((request.note ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '«${request.note!.trim()}»',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySoft.copyWith(
                          fontFamily: 'InstrumentSerif',
                          fontStyle: FontStyle.italic,
                          color: BbV5Colors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (reviewed)
            Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: request.status == EventJoinRequestStatus.approved
                    ? BbV5Colors.brandSoft
                    : BbV5Colors.hairSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                request.status == EventJoinRequestStatus.approved
                    ? 'Принято'
                    : 'Отклонено',
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontWeight: FontWeight.w600,
                  color: request.status == EventJoinRequestStatus.approved
                      ? BbV5Colors.brandDeep
                      : BbV5Colors.inkMute,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: BbV5PillButton(
                    label: busy ? '...' : 'Отклонить',
                    icon: LucideIcons.x,
                    height: 40,
                    expanded: true,
                    onPressed: busy ? null : onReject,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: BbV5PillButton(
                    label: busy ? '...' : 'Принять',
                    icon: LucideIcons.check,
                    dark: true,
                    height: 40,
                    expanded: true,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HostedTabs extends StatelessWidget {
  const _HostedTabs({
    required this.tab,
    required this.onChanged,
  });

  final _HostedMeetupsTab tab;
  final ValueChanged<_HostedMeetupsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BbV5Colors.hairSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        children: [
          _HostedTabButton(
            label: 'Предстоящие',
            selected: tab == _HostedMeetupsTab.upcoming,
            onTap: () => onChanged(_HostedMeetupsTab.upcoming),
          ),
          _HostedTabButton(
            label: 'Прошедшие',
            selected: tab == _HostedMeetupsTab.past,
            onTap: () => onChanged(_HostedMeetupsTab.past),
          ),
          _HostedTabButton(
            label: 'Черновики',
            selected: tab == _HostedMeetupsTab.drafts,
            onTap: () => onChanged(_HostedMeetupsTab.drafts),
          ),
        ],
      ),
    );
  }
}

class _HostedTabButton extends StatelessWidget {
  const _HostedTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BbV5Colors.paperHi : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? BbV5Shadows.pill : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? BbV5Colors.ink : BbV5Colors.inkMute,
            ),
          ),
        ),
      ),
    );
  }
}

class _HostedEventTile extends StatelessWidget {
  const _HostedEventTile({
    required this.event,
    required this.promoted,
    required this.onTap,
    required this.onPromote,
    required this.onOpenChat,
  });

  final Event event;
  final bool promoted;
  final VoidCallback onTap;
  final VoidCallback onPromote;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.imageUrl?.trim();

    return BbV5Card(
      padding: const EdgeInsets.all(12),
      radius: 20,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? BbExternalEventImage(
                            imageUrl: imageUrl,
                            usage: BbExternalEventImageUsage.rail,
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _eventGradient(event.tone),
                            ),
                            child: Center(
                              child: Text(
                                event.emoji,
                                style: const TextStyle(fontSize: 24, height: 1),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.itemTitle
                                  .copyWith(fontSize: 13),
                            ),
                          ),
                          if (promoted)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: BbV5Colors.terra,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.flame,
                                    size: 10,
                                    color: BbV5Colors.paperHi,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'ПРОДВИГАЕТСЯ',
                                    style: AppTextStyles.caption.copyWith(
                                      color: BbV5Colors.paperHi,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_statusLabel(event)} · ${event.time} · ${event.place}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          color: BbV5Colors.inkMute,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _MiniMetric(
                            icon: LucideIcons.users,
                            label: '${event.going}/${event.capacity}',
                          ),
                          const SizedBox(width: 12),
                          const _MiniMetric(
                            icon: LucideIcons.eye,
                            label: '142',
                          ),
                          const SizedBox(width: 12),
                          const _MiniMetric(
                            icon: LucideIcons.heart,
                            label: '18',
                          ),
                        ],
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
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BbV5PillButton(
                  label: promoted ? 'Усилить ещё' : 'Продвигать',
                  icon: LucideIcons.zap,
                  dark: !promoted,
                  expanded: true,
                  onPressed: onPromote,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              BbV5PillButton(
                label: 'Чат',
                icon: LucideIcons.message_circle,
                onPressed: onOpenChat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoteSheet extends StatelessWidget {
  const _PromoteSheet({
    required this.event,
    required this.wallet,
    required this.onPick,
  });

  final Event event;
  final TokenWalletState wallet;
  final ValueChanged<PromoOption> onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              color: BbV5Colors.paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: Offset(0, -20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BbV5Colors.hair,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BbV5Kicker('Продвижение'),
                          const SizedBox(height: 4),
                          const BbV5HeroTitle(
                            title: 'Усилить',
                            accent: 'встречу',
                            fontSize: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: BbV5Colors.inkMute,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _HostWalletBadge(
                      balance: wallet.balance,
                      onTap: () => context.pushRoute(AppRoute.wallet),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final option in promoOptions) ...[
                  _PromoOptionButton(
                    option: option,
                    enough: wallet.balance >= option.cost,
                    onTap: () => onPick(option),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Отмена',
                      style: AppTextStyles.button.copyWith(
                        color: BbV5Colors.inkMute,
                        fontSize: 12.5,
                      ),
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

class _PromoOptionButton extends StatelessWidget {
  const _PromoOptionButton({
    required this.option,
    required this.enough,
    required this.onTap,
  });

  final PromoOption option;
  final bool enough;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enough ? 1 : 0.5,
      child: BbV5Card(
        radius: 20,
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: BbV5Colors.terraSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.zap,
                size: 17,
                color: BbV5Colors.accentDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: AppTextStyles.itemTitle.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: BbV5Colors.inkMute,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.coins,
                  size: 15,
                  color: enough ? BbV5Colors.terra : BbV5Colors.inkMute,
                ),
                const SizedBox(width: 4),
                Text(
                  '${option.cost}',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    color: enough ? BbV5Colors.terra : BbV5Colors.inkMute,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: BbV5Colors.inkSoft),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: BbV5Colors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _HostedEmptyState extends StatelessWidget {
  const _HostedEmptyState({required this.tab});

  final _HostedMeetupsTab tab;

  @override
  Widget build(BuildContext context) {
    final text = switch (tab) {
      _HostedMeetupsTab.upcoming => 'Пока нет предстоящих встреч.',
      _HostedMeetupsTab.past => 'Пока нет прошедших встреч.',
      _HostedMeetupsTab.drafts =>
        'Черновики появятся после сохранения встречи.',
    };

    return BbV5Card(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Text(
        text,
        style: AppTextStyles.bodySoft.copyWith(
          color: BbV5Colors.inkSoft,
        ),
      ),
    );
  }
}

class _HostErrorState extends StatelessWidget {
  const _HostErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: BbV5Card(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Не получилось загрузить хост-панель',
                style: bbV5DisplayStyle(fontSize: 18, letterSpacing: 0),
              ),
              const SizedBox(height: 8),
              Text(
                'Проверь соединение и попробуй ещё раз.',
                style: AppTextStyles.bodySoft.copyWith(
                  color: BbV5Colors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              BbV5PillButton(
                label: 'Повторить',
                icon: LucideIcons.refresh_cw,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(Event event) {
  if (event.liveStatus == EventLiveStatus.live) {
    return 'идёт сейчас';
  }
  final startsAt = DateTime.tryParse(event.startsAtIso ?? '');
  if (startsAt != null && startsAt.isBefore(DateTime.now())) {
    return 'завершена';
  }
  return 'скоро';
}

LinearGradient _eventGradient(EventTone tone) {
  return switch (tone) {
    EventTone.sage => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BbV5Colors.brandSoft, BbV5Colors.brand],
      ),
    EventTone.evening => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BbV5Colors.gold, BbV5Colors.terra],
      ),
    EventTone.warm => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BbV5Colors.terraSoft, BbV5Colors.paperDeep],
      ),
  };
}
