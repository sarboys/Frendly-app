import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_plan_data.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_edit_state.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/subscription.dart';
import 'package:big_break_mobile/shared/widgets/bb_bottom_nav.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class EveningPlanScreen extends ConsumerStatefulWidget {
  const EveningPlanScreen({
    required this.routeId,
    this.isPremium = false,
    this.autoOpenLaunch = false,
    this.initialRoute,
    super.key,
  });

  final String routeId;
  final bool isPremium;
  final bool autoOpenLaunch;
  final EveningRouteData? initialRoute;

  @override
  ConsumerState<EveningPlanScreen> createState() => _EveningPlanScreenState();
}

class _EveningPlanScreenState extends ConsumerState<EveningPlanScreen> {
  final Set<String> _usedPerks = <String>{};
  final Set<String> _boughtTickets = <String>{};
  bool _autoLaunchOpened = false;
  EveningRouteData? _backendRoute;
  CancelToken? _backendRouteCancelToken;

  EveningRouteData get _route => readEveningRoute(
        ref,
        widget.routeId,
        fallback: _backendRoute ??
            widget.initialRoute ??
            findEveningRoute(widget.routeId),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadBackendRoute();
      if (widget.autoOpenLaunch) {
        if (!mounted || _autoLaunchOpened) {
          return;
        }
        _autoLaunchOpened = true;
        _openLaunchSheet();
      }
    });
  }

  @override
  void dispose() {
    final cancelToken = _backendRouteCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('evening_plan_disposed');
    }
    super.dispose();
  }

  Future<void> _loadBackendRoute() async {
    final activeToken = _backendRouteCancelToken;
    if (activeToken != null && !activeToken.isCancelled) {
      activeToken.cancel('evening_plan_route_replaced');
    }
    final cancelToken = CancelToken();
    _backendRouteCancelToken = cancelToken;
    final repository = ref.read(backendRepositoryProvider);
    try {
      final json = await repository.fetchEveningRoute(
        widget.routeId,
        cancelToken: cancelToken,
      );
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_backendRouteCancelToken, cancelToken)) {
        return;
      }
      setState(() {
        _backendRoute = eveningRouteFromJson(
          json,
          fallback: widget.initialRoute ?? findEveningRoute(widget.routeId),
        );
      });
    } catch (_) {
    } finally {
      if (identical(_backendRouteCancelToken, cancelToken)) {
        _backendRouteCancelToken = null;
      }
    }
  }

  void _markPerkUsed(String id) {
    setState(() {
      _usedPerks.add(id);
    });
  }

  void _markTicketBought(String id) {
    setState(() {
      _boughtTickets.add(id);
    });
  }

  Future<void> _buyTicketForStep(EveningRouteStep step) async {
    final rawUrl = step.ticketUrl;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https') {
      _markTicketBought(step.id);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || !context.mounted) {
      return;
    }
    if (opened) {
      _markTicketBought(step.id);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть билетную ссылку')),
    );
  }

  Future<void> _openPerkForStep(EveningRouteStep step) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.of(context).foreground.withValues(alpha: 0.4),
      builder: (context) => _PerkRedeemSheet(
        partner: _PerkPartner.fromStep(step),
        eventTitle: _route.title,
        eventTime: _route.durationLabel,
      ),
    );

    if (!mounted) {
      return;
    }
    _markPerkUsed(step.id);
  }

  Future<void> _openStepDetails(EveningRouteStep step) {
    final route = _route;
    final index = route.steps.indexWhere((item) => item.id == step.id);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.of(context).foreground.withValues(alpha: 0.4),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return _StepDetailSheet(
            step: step,
            stepIndex: index,
            totalSteps: route.steps.length,
            kindLabel: eveningKindLabel(step.kind),
            perkUsed: _usedPerks.contains(step.id),
            ticketBought: _boughtTickets.contains(step.id),
            onUsePerk: () {
              Navigator.of(sheetContext).pop();
              _openPerkForStep(step);
            },
            onBuyTicket: () {
              _buyTicketForStep(step).then((_) {
                if (sheetContext.mounted) {
                  setSheetState(() {});
                }
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _openLaunchSheet() async {
    final route = _route;
    final repository = ref.read(backendRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final result = await showModalBottomSheet<_LaunchEveningChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.of(context).foreground.withValues(alpha: 0.4),
      builder: (context) => _LaunchEveningSheet(route: route),
    );

    if (result == null) {
      if (widget.autoOpenLaunch && mounted && context.mounted) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
      return;
    }

    if (!mounted || !context.mounted) {
      return;
    }

    try {
      final published = await repository.publishEveningRoute(
        route.id,
        privacy: result.privacy,
      );
      if (!mounted || !context.mounted) {
        return;
      }
      _cachePublishedEveningChat(container, route, published);
      context.pushReplacementNamed(
        AppRoute.meetupChat.name,
        pathParameters: {'chatId': published.chatId},
      );
      return;
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Не удалось опубликовать вечер. Проверь сеть и попробуй ещё раз'),
          ),
        );
      }
    }
  }

  void _cachePublishedEveningChat(
    ProviderContainer container,
    EveningRouteData route,
    EveningPublishResult published,
  ) {
    final currentUserId = container.read(currentUserIdProvider);
    final existingChats = container.read(meetupChatsProvider).valueOrNull ??
        container.read(meetupChatsLocalStateProvider);

    if (existingChats == null || currentUserId == null) {
      container.read(meetupChatsLocalStateProvider.notifier).state = null;
      container.invalidate(meetupChatsProvider);
      container.invalidate(eveningSessionsProvider);
      container.invalidate(eveningSessionProvider(published.sessionId));
      return;
    }

    final totalSteps = route.steps.length;
    final summary = MeetupChat(
      id: published.chatId,
      eventId: null,
      title: route.title,
      emoji: route.steps.isEmpty ? '✨' : route.steps.first.emoji,
      time: route.durationLabel,
      lastMessage:
          'Вечер опубликован · $totalSteps шагов · ${_privacyLabel(published.privacy)}',
      lastAuthor: 'Frendly',
      lastTime: 'сейчас',
      unread: 0,
      members: const ['Ты'],
      status: 'Сбор участников',
      phase: MeetupPhase.soon,
      totalSteps: totalSteps,
      startsInLabel: 'Скоро',
      routeId: published.routeId,
      sessionId: published.sessionId,
      privacy: published.privacy,
      joinedCount: published.joinedCount,
      maxGuests: published.maxGuests,
      hostUserId: currentUserId,
      hostName: 'Ты',
      area: route.area,
    );

    container.read(meetupChatsLocalStateProvider.notifier).state =
        upsertMeetupChat(existingChats, summary);
    container.invalidate(eveningSessionsProvider);
    container.invalidate(eveningSessionProvider(published.sessionId));
  }

  String _privacyLabel(EveningPrivacy privacy) {
    switch (privacy) {
      case EveningPrivacy.request:
        return 'по заявке';
      case EveningPrivacy.invite:
        return 'по приглашениям';
      case EveningPrivacy.open:
        return 'открытый';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(eveningRouteOverridesProvider);
    final route = _route;
    final subscription = route.premium && !widget.isPremium
        ? ref.watch(subscriptionStateProvider).valueOrNull
        : null;
    final hasPremiumAccess =
        widget.isPremium || _hasFrendlyPlusAccess(subscription);
    final locked = route.premium && !hasPremiumAccess;
    return Scaffold(
      backgroundColor: BbV5Colors.paper,
      extendBody: true,
      bottomNavigationBar: BbV5GlassBottomBar(
        child: BbBottomNav(
          location: AppRoute.eveningPlan.path,
          onTap: (tab) => context.goRoute(tab.route),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: BbV5WarmBackground()),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _PlanHero(
                  route: route,
                  onShare: () => _shareRoute(route),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: BbV5Card(
                    padding: const EdgeInsets.all(20),
                    tint: BbV5Colors.terraSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BbV5Kicker(route.recommendedFor ?? 'Маршрут вечера'),
                        const SizedBox(height: 6),
                        _RouteHeroTitle(title: route.title),
                        const SizedBox(height: 8),
                        Text(
                          route.blurb,
                          style: AppTextStyles.meta.copyWith(
                            fontSize: 13,
                            color: BbV5Colors.inkSoft,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _RouteHeroMetric(
                                icon: LucideIcons.clock,
                                value: route.durationLabel.split(' — ').first,
                                label: route.durationLabel,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RouteHeroMetric(
                                icon: LucideIcons.map_pin,
                                value: route.area.split(' → ').first,
                                label: route.area,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RouteHeroMetric(
                                icon: LucideIcons.users,
                                value: '${route.hostsCount}',
                                label: 'идут',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(height: 1, color: BbV5Colors.hairSoft),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    'Бюджет от',
                                    style: AppTextStyles.meta.copyWith(
                                      fontSize: 11,
                                      color: BbV5Colors.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${route.totalPriceFrom}₽',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: bbV5DisplayStyle(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                height: 28,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: BbV5Colors.paperHi,
                                  borderRadius:
                                      BorderRadius.circular(BbV5Radii.pill),
                                  border: Border.all(color: BbV5Colors.hair),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.sparkles,
                                      size: 12,
                                      color: BbV5Colors.terra,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'экономия −${route.totalSavings}₽',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 10.5,
                                          color: BbV5Colors.terra,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ],
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
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (locked)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _LockedOverlay(
                      onUnlock: () => context.pushRoute(AppRoute.paywall),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 168),
                    child: _RouteStepsTimeline(
                      steps: route.steps,
                      onOpenStep: _openStepDetails,
                    ),
                  ),
                ),
            ],
          ),
          if (!locked && !widget.autoOpenLaunch)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyPlanCta(
                label: 'Запустить маршрут · в чат',
                onTap: _openLaunchSheet,
                bottomGap: 96,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _shareRoute(EveningRouteData route) async {
    await Clipboard.setData(ClipboardData(text: route.title));
    if (!mounted || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }
}

bool _hasFrendlyPlusAccess(SubscriptionStateData? subscription) {
  return subscription?.status == 'trial' || subscription?.status == 'active';
}

class _PlanHero extends StatelessWidget {
  const _PlanHero({
    required this.route,
    required this.onShare,
  });

  final EveningRouteData route;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, safeTop + 8, 20, 0),
      child: Row(
        children: [
          BbV5IconButton(
            icon: LucideIcons.arrow_left,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BbV5Kicker('Маршрут вечера'),
                const SizedBox(height: 3),
                Text(
                  route.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5DisplayStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          BbV5IconButton(
            icon: LucideIcons.share_2,
            iconSize: 17,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _RouteHeroMetric extends StatelessWidget {
  const _RouteHeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: BbV5Colors.inkMute),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bbV5DisplayStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHeroTitle extends StatelessWidget {
  const _RouteHeroTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final base = bbV5DisplayStyle(fontSize: 24, height: 1.1);
    final split = title.split(' на ');
    if (split.length < 2) {
      return Text(
        title,
        style: base,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: split.first),
          const TextSpan(text: ' '),
          TextSpan(
            text: 'на ${split.skip(1).join(' на ')}',
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}

class _RouteStepsTimeline extends StatelessWidget {
  const _RouteStepsTimeline({
    required this.steps,
    required this.onOpenStep,
  });

  final List<EveningRouteStep> steps;
  final ValueChanged<EveningRouteStep> onOpenStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BbV5Kicker('Шаги вечера'),
        const SizedBox(height: 12),
        Stack(
          children: [
            const Positioned(
              left: 27,
              top: 12,
              bottom: 12,
              child: SizedBox(
                width: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: BbV5Colors.hair),
                ),
              ),
            ),
            Column(
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  _TimelineStepTile(
                    step: steps[index],
                    index: index,
                    onOpen: () => onOpenStep(steps[index]),
                  ),
                  if (index != steps.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineStepTile extends StatelessWidget {
  const _TimelineStepTile({
    required this.step,
    required this.index,
    required this.onOpen,
  });

  final EveningRouteStep step;
  final int index;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${step.time}${step.endTime == null ? '' : ' — ${step.endTime}'}';
    final perkLabel = step.perkShort ?? step.perk;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        BbV5Card(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(56, 16, 16, 16),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$timeLabel · шаг ${index + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkMute,
                            fontFamily: 'Sora',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          step.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: bbV5DisplayStyle(fontSize: 14.5, height: 1.15),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${step.venue} · ${step.address}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkSoft,
                            fontSize: 11.5,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (perkLabel != null && perkLabel.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _StepPerkBadge(label: perkLabel),
                  ],
                ],
              ),
              if (step.description != null &&
                  step.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  step.description!,
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkSoft,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
              if (step.walkMin != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.map_pin,
                      size: 13,
                      color: BbV5Colors.inkMute,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '~${step.walkMin} мин пешком до следующего',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 12,
          top: 16,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BbV5Colors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Text(
              step.emoji,
              style: const TextStyle(fontSize: 18, height: 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepPerkBadge extends StatelessWidget {
  const _StepPerkBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 104),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.tag,
            size: 11,
            color: BbV5Colors.terra,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.terra,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDetailSheet extends StatelessWidget {
  const _StepDetailSheet({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.kindLabel,
    required this.perkUsed,
    required this.ticketBought,
    required this.onUsePerk,
    required this.onBuyTicket,
  });

  final EveningRouteStep step;
  final int stepIndex;
  final int totalSteps;
  final String kindLabel;
  final bool perkUsed;
  final bool ticketBought;
  final VoidCallback onUsePerk;
  final VoidCallback onBuyTicket;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tomestoBooking = _isTomestoStep(step);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.88,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: AppRadii.pillBorder,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.warmStart, colors.warmEnd],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        step.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _TinyPill(
                                label: kindLabel,
                                foreground: colors.inkMute,
                                background: colors.muted,
                              ),
                              Text(
                                'Шаг ${stepIndex + 1} / $totalSteps',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colors.inkMute,
                                  letterSpacing: 0,
                                ),
                              ),
                              if (step.sponsored)
                                _TinyPill(
                                  label: 'Sponsored',
                                  foreground: colors.secondary,
                                  background:
                                      colors.secondary.withValues(alpha: 0.15),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.title,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.venue,
                            style: AppTextStyles.meta.copyWith(
                              color: colors.inkMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'Закрыть',
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: AppRadii.pillBorder,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.muted,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: colors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _InfoPill(
                          icon: LucideIcons.clock,
                          label:
                              '${step.time}${step.endTime != null ? ' — ${step.endTime}' : ''}',
                        ),
                        _InfoPill(
                          icon: LucideIcons.map_pin,
                          label:
                              '${step.distance}${step.walkMin != null ? ' · ${step.walkMin} мин' : ''}',
                        ),
                        if (step.vibeTag != null)
                          _InfoPill(label: step.vibeTag!),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.map_pin,
                            size: 16,
                            color: colors.inkSoft,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Адрес',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.inkMute,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step.address,
                                  style: AppTextStyles.meta.copyWith(
                                    fontSize: 13,
                                    color: colors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors.foreground,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              LucideIcons.navigation,
                              size: 16,
                              color: colors.background,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (step.description != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        step.description!,
                        style: AppTextStyles.meta.copyWith(
                          fontSize: 13,
                          height: 1.45,
                          color: colors.inkSoft,
                        ),
                      ),
                    ],
                    if (step.perk != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: perkUsed
                              ? colors.secondary.withValues(alpha: 0.1)
                              : colors.warmStart,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: perkUsed
                                ? colors.secondary.withValues(alpha: 0.4)
                                : colors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.sparkles,
                                  size: 12,
                                  color: colors.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Перк партнёра',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colors.secondary,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const Spacer(),
                                _DetailStatusChip(
                                  used: perkUsed,
                                  kind: _DetailStatusKind.perk,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step.perk!,
                              style: AppTextStyles.meta.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (step.ticketPrice != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ticketBought
                              ? colors.secondary.withValues(alpha: 0.1)
                              : colors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ticketBought
                                ? colors.secondary.withValues(alpha: 0.4)
                                : colors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              tomestoBooking
                                  ? LucideIcons.calendar_check
                                  : LucideIcons.ticket,
                              size: 16,
                              color: colors.inkSoft,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                tomestoBooking
                                    ? 'Средний чек ${step.ticketPrice} ₽'
                                    : 'Билет ${step.ticketPrice} ₽',
                                style: AppTextStyles.meta.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.foreground,
                                ),
                              ),
                            ),
                            _DetailStatusChip(
                              used: ticketBought,
                              kind: tomestoBooking
                                  ? _DetailStatusKind.booking
                                  : _DetailStatusKind.ticket,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (step.perk != null || step.ticketPrice != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
                  child: Column(
                    children: [
                      if (step.ticketPrice != null)
                        _SheetActionButton(
                          icon: ticketBought
                              ? LucideIcons.circle_check
                              : tomestoBooking
                                  ? LucideIcons.calendar_check
                                  : LucideIcons.ticket,
                          trailingIcon:
                              ticketBought ? null : LucideIcons.arrow_right,
                          label: ticketBought
                              ? tomestoBooking
                                  ? 'Бронь открыта'
                                  : 'Билет куплен'
                              : tomestoBooking
                                  ? 'Забронировать столик'
                                  : 'Купить билет ${step.ticketPrice} ₽',
                          done: ticketBought,
                          onTap: ticketBought ? null : onBuyTicket,
                        ),
                      if (step.ticketPrice != null && step.perk != null)
                        const SizedBox(height: AppSpacing.xs),
                      if (step.perk != null)
                        _SheetActionButton(
                          icon: perkUsed
                              ? LucideIcons.circle_check
                              : LucideIcons.sparkles,
                          label: perkUsed
                              ? 'Перк использован'
                              : 'Использовать перк',
                          done: perkUsed,
                          secondary: step.ticketPrice != null,
                          onTap: perkUsed ? null : onUsePerk,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PerkRedeemSheet extends StatefulWidget {
  const _PerkRedeemSheet({
    required this.partner,
    required this.eventTitle,
    required this.eventTime,
  });

  final _PerkPartner partner;
  final String eventTitle;
  final String eventTime;

  @override
  State<_PerkRedeemSheet> createState() => _PerkRedeemSheetState();
}

class _PerkRedeemSheetState extends State<_PerkRedeemSheet> {
  _RedeemStep _step = _RedeemStep.intro;
  int _people = 4;
  String _name = 'Ты';
  String _phone = '+7 ';
  bool _copied = false;

  String get _code {
    final suffix = widget.partner.id.length > 4
        ? widget.partner.id.substring(widget.partner.id.length - 4)
        : widget.partner.id;
    return 'FRD-${suffix.toUpperCase()}-4821';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: AppRadii.pillBorder,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.warmStart, colors.warmEnd],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.partner.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Перк партнёра',
                        style: AppTextStyles.caption.copyWith(
                          color: colors.inkMute,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          letterSpacing: 1.54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.partner.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.itemTitle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                          Icon(
                            LucideIcons.shield_check,
                            size: 16,
                            color: colors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.map_pin,
                            size: 12,
                            color: colors.inkMute,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.partner.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: colors.inkMute,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Закрыть',
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: AppRadii.pillBorder,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.muted,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: colors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
              shrinkWrap: true,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.warmStart, colors.background],
                    ),
                    borderRadius: AppRadii.cardBorder,
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.sparkles,
                            size: 14,
                            color: colors.inkSoft,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Твой бонус',
                            style: AppTextStyles.caption.copyWith(
                              color: colors.inkSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                              letterSpacing: 1.54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.partner.perk,
                        style: AppTextStyles.cardTitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_step == _RedeemStep.intro)
                  _buildIntro(context)
                else if (_step == _RedeemStep.form)
                  _buildForm(context)
                else
                  _buildSuccess(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final colors = AppColors.of(context);
    final items = [
      'Бронируем в приложении — стол держим до начала встречи',
      'Покажи код или экран на месте',
      'Перк действует только на участников встречи',
    ];

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.check,
                  size: 16,
                  color: colors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: AppTextStyles.meta.copyWith(
                      color: colors.inkSoft,
                      fontSize: 13,
                      height: 1.375,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.muted.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(LucideIcons.calendar, size: 14, color: colors.inkSoft),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.eventTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 22),
                  Expanded(
                    child: Text(
                      widget.eventTime,
                      style: AppTextStyles.meta.copyWith(color: colors.inkSoft),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SheetActionButton(
          label: 'Забронировать с перком',
          trailingIcon: LucideIcons.arrow_right,
          fontSize: 15,
          onTap: () => setState(() {
            _step = _RedeemStep.form;
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Бесплатная отмена за 2 часа до начала',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: colors.inkMute),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Детали брони',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.of(context).inkMute,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 1.68,
          ),
        ),
        const SizedBox(height: 10),
        _RedeemField(
          label: 'Имя для брони',
          child: TextFormField(
            initialValue: _name,
            onChanged: (value) => _name = value,
            decoration: const InputDecoration.collapsed(
              hintText: 'Как обратиться',
            ),
            style: AppTextStyles.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _RedeemField(
          label: 'Телефон',
          child: TextFormField(
            initialValue: _phone,
            onChanged: (value) => _phone = value,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration.collapsed(
              hintText: '+7 999 000 00 00',
            ),
            style: AppTextStyles.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _RedeemField(
          label: 'Гостей',
          child: Row(
            children: [
              Icon(
                LucideIcons.users,
                size: 16,
                color: AppColors.of(context).inkSoft,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '$_people ${_people == 1 ? 'гость' : _people < 5 ? 'гостя' : 'гостей'}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
              _StepperButton(
                label: '-',
                onTap: () => setState(() {
                  if (_people > 1) {
                    _people -= 1;
                  }
                }),
              ),
              const SizedBox(width: AppSpacing.xs),
              _StepperButton(
                label: '+',
                onTap: () => setState(() {
                  if (_people < 20) {
                    _people += 1;
                  }
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SheetActionButton(
          label: 'Подтвердить бронь',
          fontSize: 15,
          onTap: () => setState(() {
            _step = _RedeemStep.success;
          }),
        ),
        TextButton(
          onPressed: () => setState(() {
            _step = _RedeemStep.intro;
          }),
          child: const Text('Назад'),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.secondary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.check,
            size: 28,
            color: colors.secondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Бронь подтверждена',
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Покажи код на входе — перк применят автоматически',
          textAlign: TextAlign.center,
          style: AppTextStyles.meta.copyWith(
            color: colors.inkSoft,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: _code));
            if (!mounted) {
              return;
            }
            setState(() {
              _copied = true;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _copied
                  ? colors.secondary.withValues(alpha: 0.1)
                  : colors.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _copied ? colors.secondary : colors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Промокод',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.inkMute,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _code,
                        style: AppTextStyles.sectionTitle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                          height: 1.2,
                          letterSpacing: 1.1,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      _copied ? LucideIcons.check : LucideIcons.copy,
                      size: 20,
                      color: _copied ? colors.secondary : colors.inkSoft,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SheetActionButton(
          label: 'Готово',
          fontSize: 15,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Перк действует на встречу «${widget.eventTitle}»',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: colors.inkMute),
        ),
      ],
    );
  }
}

class _LaunchEveningChoice {
  const _LaunchEveningChoice({
    required this.privacy,
  });

  final EveningPrivacy privacy;
}

class _LaunchEveningSheet extends StatefulWidget {
  const _LaunchEveningSheet({required this.route});

  final EveningRouteData route;

  @override
  State<_LaunchEveningSheet> createState() => _LaunchEveningSheetState();
}

class _LaunchEveningSheetState extends State<_LaunchEveningSheet> {
  EveningPrivacy _privacy = EveningPrivacy.open;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final route = widget.route;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: AppShadows.card,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + bottomInset),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    LucideIcons.sparkles,
                    color: colors.primaryForeground,
                    size: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Опубликовать вечер?',
                        style:
                            AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Соберём людей, потом запустим live',
                        style: AppTextStyles.caption.copyWith(
                          color: colors.inkMute,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, color: colors.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.warmStart, colors.warmEnd],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      route.steps.isEmpty ? '✨' : route.steps.first.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${route.durationLabel} · ${route.area}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.meta.copyWith(
                            fontSize: 11,
                            height: 1.2,
                            color: colors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TinyPill(
                    label: '${route.steps.length} шагов',
                    foreground: colors.inkMute,
                    background: colors.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: route.steps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final step = route.steps[index];
                  return Container(
                    width: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              step.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const Spacer(),
                            Text(
                              '${index + 1}/${route.steps.length}',
                              style: AppTextStyles.caption.copyWith(
                                color: colors.inkMute,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          step.venue,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.itemTitle.copyWith(
                            fontSize: 12,
                            height: 1.15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          step.time,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            height: 1.1,
                            color: colors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _LaunchSectionTitle('Кто может вписаться'),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  _PrivacyOptionTile(
                    icon: LucideIcons.globe,
                    title: 'Открытый',
                    text: 'Любой может вписаться одним тапом',
                    active: _privacy == EveningPrivacy.open,
                    onTap: () => setState(() => _privacy = EveningPrivacy.open),
                  ),
                  _PrivacyOptionTile(
                    icon: LucideIcons.user_check,
                    title: 'По заявке',
                    text: 'Ты подтверждаешь каждого гостя',
                    active: _privacy == EveningPrivacy.request,
                    onTap: () =>
                        setState(() => _privacy = EveningPrivacy.request),
                  ),
                  _PrivacyOptionTile(
                    icon: LucideIcons.lock,
                    title: 'По приглашениям',
                    text: 'Видят только те, кому ты отправил инвайт',
                    active: _privacy == EveningPrivacy.invite,
                    onTap: () =>
                        setState(() => _privacy = EveningPrivacy.invite),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _LaunchSectionTitle('Сбор участников'),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.users, color: colors.inkSoft, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Пока только ты',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.meta.copyWith(
                            fontSize: 13,
                            height: 1.2,
                            color: colors.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'После публикации гости попадут сюда из preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            height: 1.2,
                            color: colors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colors.muted,
                      borderRadius: AppRadii.pillBorder,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'После публикации',
                      style: AppTextStyles.caption.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 12,
                        color: colors.foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SheetActionButton(
              label: 'Опубликовать и собрать людей',
              trailingIcon: LucideIcons.arrow_right,
              fontSize: 15,
              onTap: () => Navigator.of(context).pop(
                _LaunchEveningChoice(
                  privacy: _privacy,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Изменить план',
                style: AppTextStyles.meta.copyWith(
                  color: colors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Live-сценарий запустишь из чата вечера, когда соберётесь',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: colors.inkMute,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyOptionTile extends StatelessWidget {
  const _PrivacyOptionTile({
    required this.icon,
    required this.title,
    required this.text,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = active ? colors.background : colors.foreground;
    final secondary =
        active ? colors.background.withValues(alpha: 0.72) : colors.inkMute;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active ? colors.foreground : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active
                      ? colors.background.withValues(alpha: 0.14)
                      : colors.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: foreground),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.itemTitle.copyWith(
                        fontSize: 13,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: AppTextStyles.caption.copyWith(
                        color: secondary,
                        fontSize: 11,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? colors.background : Colors.transparent,
                  border: Border.all(
                    color: active ? colors.background : colors.border,
                    width: 2,
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

class _LaunchSectionTitle extends StatelessWidget {
  const _LaunchSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: colors.inkMute,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: 1.54,
      ),
    );
  }
}

class _StickyPlanCta extends StatelessWidget {
  const _StickyPlanCta({
    required this.label,
    required this.onTap,
    this.bottomGap = 32,
  });

  final String label;
  final VoidCallback onTap;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomGap + bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BbV5Colors.paper.withValues(alpha: 0),
            BbV5Colors.paper.withValues(alpha: 0.95),
          ],
          stops: const [0, 0.32],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: BbV5Colors.accent,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(BbV5Radii.pill),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  boxShadow: BbV5Shadows.ink,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.play,
                      size: 17,
                      color: BbV5Colors.paperHi,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.button.copyWith(
                          color: BbV5Colors.paperHi,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
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
}

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.warmStart, colors.background],
        ),
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.foreground.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.lock, size: 24, color: colors.foreground),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Премиум-маршрут Frendly+',
            style: AppTextStyles.cardTitle.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Лучшие маршруты, приоритетная бронь и закрытые места доступны подписчикам Frendly+',
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(
              color: colors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SheetActionButton(
            icon: LucideIcons.crown,
            label: 'Открыть Frendly+',
            onTap: onUnlock,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.check, size: 12, color: colors.secondary),
              const SizedBox(width: 4),
              Text(
                'Первая неделя бесплатно',
                style: AppTextStyles.caption.copyWith(color: colors.inkMute),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.label,
    this.icon,
    this.trailingIcon,
    this.fontSize = 14,
    this.done = false,
    this.secondary = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final double fontSize;
  final bool done;
  final bool secondary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final background = done
        ? colors.secondary.withValues(alpha: 0.15)
        : secondary
            ? colors.card
            : colors.foreground;
    final foreground = done
        ? colors.secondary
        : secondary
            ? colors.foreground
            : colors.background;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done
                ? colors.secondary.withValues(alpha: 0.4)
                : secondary
                    ? colors.border
                    : colors.foreground,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(trailingIcon, size: 16, color: foreground),
            ],
          ],
        ),
      ),
    );
  }
}

class _RedeemField extends StatelessWidget {
  const _RedeemField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.inkMute,
              height: 1.1,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.pillBorder,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colors.muted,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foreground,
          height: 1.1,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

enum _DetailStatusKind { perk, ticket, booking }

class _DetailStatusChip extends StatelessWidget {
  const _DetailStatusChip({
    required this.used,
    required this.kind,
  });

  final bool used;
  final _DetailStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = used
        ? kind == _DetailStatusKind.perk
            ? 'Использован'
            : kind == _DetailStatusKind.booking
                ? 'Открыта'
                : 'Куплено'
        : 'Доступно';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: used ? colors.secondary.withValues(alpha: 0.15) : colors.muted,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (used) ...[
            Icon(LucideIcons.circle_check, size: 12, color: colors.secondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: used ? colors.secondary : colors.inkMute,
              height: 1.1,
              letterSpacing: 0.72,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkPartner {
  const _PerkPartner({
    required this.id,
    required this.name,
    required this.emoji,
    required this.address,
    required this.perk,
  });

  factory _PerkPartner.fromStep(EveningRouteStep step) {
    return _PerkPartner(
      id: step.partnerId ?? step.id,
      name: step.venue,
      emoji: step.emoji,
      address: '${step.address} · ${step.distance}',
      perk: step.perk ?? 'Бонус для участников маршрута',
    );
  }

  final String id;
  final String name;
  final String emoji;
  final String address;
  final String perk;
}

enum _RedeemStep { intro, form, success }

bool _isTomestoStep(EveningRouteStep step) {
  final sourceCode = step.ticketSourceCode?.trim().toLowerCase();
  if (sourceCode == 'tomesto') {
    return true;
  }

  final ticketUrl = step.ticketUrl?.trim();
  if (ticketUrl == null || ticketUrl.isEmpty) {
    return false;
  }
  final host = Uri.tryParse(ticketUrl)?.host.toLowerCase();
  return host == 'tomesto.ru' || host?.endsWith('.tomesto.ru') == true;
}
