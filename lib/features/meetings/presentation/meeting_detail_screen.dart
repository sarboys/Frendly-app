import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/meetings/presentation/meeting_boost.dart';
import 'package:mobile2/features/meetings/presentation/meeting_viewer_state.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_map_choice_sheet.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';
import 'package:url_launcher/url_launcher.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.inviteRequestId,
  });

  final String meetingId;
  final String? inviteRequestId;

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  static const _refreshInterval = Duration(seconds: 5);

  bool _saved = false;
  BackendCardItem? _localMeeting;
  bool _joinBusy = false;
  bool _promoteBusy = false;
  bool _reportBusy = false;
  bool _refreshBusy = false;
  String? _joinError;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant MeetingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meetingId != widget.meetingId) {
      _localMeeting = null;
      _startRefreshTimer();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_refreshMeetingDetail());
    });
  }

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: Builder(
        builder: (context) {
          final state = ref.watch(meetingDetailProvider(widget.meetingId));
          final currentUserId = ref.watch(currentUserIdProvider);
          final meeting = _localMeeting ?? state.valueOrNull;
          final isHost = meeting == null
              ? false
              : _isHost(meeting, currentUserId: currentUserId);
          final joined = meeting == null
              ? false
              : isHost || meetingViewerHasJoined(meeting);
          final realtimeChatId = meeting == null || !joined
              ? null
              : _stringOrNull(meeting.raw['chatId']);
          if (realtimeChatId != null) {
            ref.watch(chatRealtimeProvider(realtimeChatId));
          }
          return Stack(
            children: [
              if (state.isLoading && meeting == null)
                const _DetailStatus(message: 'Загружаем встречу')
              else if (meeting == null)
                _DetailStatus(
                  message: state.hasError
                      ? 'Не удалось загрузить встречу'
                      : 'Встреча не найдена',
                )
              else
                _BackendMeetingDetail(
                  meeting: meeting,
                  saved: _saved,
                  currentUserId: currentUserId,
                  onSaved: () => setState(() => _saved = !_saved),
                  onRequirementTap: _openEntryRequirement,
                  onRequests: () => _showHostRequestsSheet(meeting),
                  onPromote: () => _showPromoteSheet(meeting),
                  onReport:
                      isHost ? null : () => _showReportMeetingSheet(meeting),
                  reportBusy: _reportBusy,
                ),
              if (meeting != null)
                _StickyMeetingActions(
                  meeting: meeting,
                  currentUserId: currentUserId,
                  joined: joined,
                  isHost: isHost,
                  busy: _joinBusy,
                  error: _joinError,
                  onJoin: () => _toggleJoin(ref, meeting),
                  onFinishHost: () => _showFinishMeetingSheet(meeting),
                  onJoinRequest: () => _setJoinRequested(ref, meeting, true),
                  onCancelJoinRequest: () =>
                      _setJoinRequested(ref, meeting, false),
                  inviteRequestId: widget.inviteRequestId,
                  onAcceptInvite: (requestId) =>
                      _acceptInvite(ref, meeting, requestId),
                  onDeclineInvite: (requestId) =>
                      _declineInvite(ref, meeting, requestId),
                  onRequirementTap: _openEntryRequirement,
                  onInvite: () => _showMeetingInviteSheet(
                    context,
                    eventId: meeting.id,
                    title: meeting.title,
                  ),
                ),
              const DateasyBottomNav(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refreshMeetingDetail() async {
    if (!mounted || _joinBusy || _refreshBusy || widget.meetingId.isEmpty) {
      return;
    }
    _refreshBusy = true;
    try {
      final updated = await ref
          .read(backendRepositoryProvider)
          .fetchEventDetail(widget.meetingId);
      if (!mounted) {
        return;
      }
      setState(() {
        _localMeeting = updated;
      });
    } catch (_) {
    } finally {
      _refreshBusy = false;
    }
  }

  Future<void> _toggleJoin(WidgetRef ref, BackendCardItem meeting) async {
    if (_joinBusy || meeting.id.isEmpty) {
      return;
    }
    setState(() {
      _joinBusy = true;
      _joinError = null;
    });
    try {
      final updated = await ref.read(meetingActionsProvider).setJoined(
            eventId: meeting.id,
            joined: !meetingViewerHasJoined(meeting),
            chatId: _stringOrNull(meeting.raw['chatId']),
          );
      final nextMeeting = meetingWithActionResponse(meeting, updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _localMeeting = nextMeeting;
        _joinBusy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joinBusy = false;
        _joinError = 'Не удалось обновить участие';
      });
    }
  }

  Future<void> _setJoinRequested(
    WidgetRef ref,
    BackendCardItem meeting,
    bool requested,
  ) async {
    if (_joinBusy || meeting.id.isEmpty) {
      return;
    }
    setState(() {
      _joinBusy = true;
      _joinError = null;
    });
    try {
      final updated = await ref.read(meetingActionsProvider).setJoinRequested(
            eventId: meeting.id,
            requested: requested,
          );
      final nextMeeting = meetingWithActionResponse(meeting, updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _localMeeting = nextMeeting;
        _joinBusy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joinBusy = false;
        _joinError = requested
            ? 'Не удалось отправить заявку'
            : 'Не удалось отменить заявку';
      });
    }
  }

  Future<void> _acceptInvite(
    WidgetRef ref,
    BackendCardItem meeting,
    String requestId,
  ) async {
    if (_joinBusy || meeting.id.isEmpty || requestId.isEmpty) {
      return;
    }
    setState(() {
      _joinBusy = true;
      _joinError = null;
    });
    try {
      final updated =
          await ref.read(notificationsActionsProvider).acceptEventInvite(
                eventId: meeting.id,
                requestId: requestId,
              );
      if (!mounted) {
        return;
      }
      setState(() {
        _localMeeting = updated;
        _joinBusy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joinBusy = false;
        _joinError = 'Не удалось принять';
      });
    }
  }

  Future<void> _declineInvite(
    WidgetRef ref,
    BackendCardItem meeting,
    String requestId,
  ) async {
    if (_joinBusy || meeting.id.isEmpty || requestId.isEmpty) {
      return;
    }
    setState(() {
      _joinBusy = true;
      _joinError = null;
    });
    try {
      await ref.read(notificationsActionsProvider).declineEventInvite(
            eventId: meeting.id,
            requestId: requestId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _joinBusy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joinBusy = false;
        _joinError = 'Не удалось отклонить';
      });
    }
  }

  void _openEntryRequirement(EventEntryRequirement requirement) {
    switch (requirement) {
      case EventEntryRequirement.verification:
        context.push('/verify');
        break;
      case EventEntryRequirement.frendlyPlus:
        context.push('/paywall');
        break;
      case EventEntryRequirement.gender:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Эта встреча ограничена по полу'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: DateasyColors.surface2,
          ),
        );
        break;
    }
  }

  Future<void> _showReportMeetingSheet(BackendCardItem meeting) async {
    if (_reportBusy || meeting.id.isEmpty) {
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DateasyColors.background,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _MeetingReportSheet(),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _reportBusy = true);
    try {
      await ref.read(reportActionsProvider).reportEvent(
            eventId: meeting.id,
            reason: 'bad_content',
            details: 'Жалоба на контент встречи',
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Жалоба отправлена'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: DateasyColors.surface2,
        ),
      );
      context.go('/meetings');
    } on BackendActionException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: DateasyColors.surface2,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _reportBusy = false);
      }
    }
  }

  Future<void> _showPromoteSheet(BackendCardItem meeting) async {
    final tier = await showModalBottomSheet<MeetingBoostTier>(
      context: context,
      backgroundColor: DateasyColors.background,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _PromoteMeetingSheet(
        currentTier: meetingBoostTierFromRaw(meeting.raw),
      ),
    );
    if (tier == null || !mounted) {
      return;
    }
    await _promoteMeeting(meeting, tier);
  }

  Future<void> _promoteMeeting(
    BackendCardItem meeting,
    MeetingBoostTier tier,
  ) async {
    if (_promoteBusy) {
      return;
    }
    setState(() => _promoteBusy = true);
    try {
      await ref.read(meetingActionsProvider).boostEvent(
            meeting.id,
            optionId: tier.optionId,
          );
      await _refreshMeetingDetail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Встреча продвигается ${tier.hours} ч'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: DateasyColors.surface2,
        ),
      );
    } on BackendActionException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_boostFailureMessage(error)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: DateasyColors.surface2,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _promoteBusy = false);
      }
    }
  }

  Future<void> _showHostRequestsSheet(BackendCardItem meeting) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DateasyColors.background,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _HostRequestsSheet(
        eventId: meeting.id,
        eventTitle: meeting.title,
        onChanged: () {
          ref.invalidate(meetingDetailProvider(meeting.id));
          unawaited(_refreshMeetingDetail());
        },
      ),
    );
  }

  Future<void> _showFinishMeetingSheet(BackendCardItem meeting) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DateasyColors.background,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _FinishMeetingSheet(
        eventId: meeting.id,
        eventTitle: meeting.title,
        currentUserId: ref.read(currentUserIdProvider),
        onFinished: () {
          ref.invalidate(meetingDetailProvider(meeting.id));
          ref.invalidate(hostDashboardProvider);
          unawaited(_refreshMeetingDetail());
        },
      ),
    );
  }

  String _boostFailureMessage(BackendActionException error) {
    return switch (error.code) {
      'token_wallet_insufficient_funds' ||
      'insufficient_tokens' ||
      'tokens_insufficient' =>
        'Не хватает FT для продвижения',
      'promotion_option_not_found' => 'Тариф продвижения недоступен',
      _ => 'Не удалось продвинуть встречу',
    };
  }
}

class _MeetingReportSheet extends StatelessWidget {
  const _MeetingReportSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Пожаловаться на встречу',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Мы отправим встречу на проверку. После жалобы она исчезнет из твоей ленты.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(LucideIcons.flag, size: 18),
                    label: const Text('Пожаловаться'),
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

class _BackendMeetingDetail extends StatelessWidget {
  const _BackendMeetingDetail({
    required this.meeting,
    required this.saved,
    required this.currentUserId,
    required this.onSaved,
    required this.onRequirementTap,
    required this.onRequests,
    required this.onPromote,
    required this.reportBusy,
    this.onReport,
  });

  final BackendCardItem meeting;
  final bool saved;
  final String? currentUserId;
  final VoidCallback onSaved;
  final ValueChanged<EventEntryRequirement> onRequirementTap;
  final VoidCallback onRequests;
  final VoidCallback onPromote;
  final VoidCallback? onReport;
  final bool reportBusy;

  @override
  Widget build(BuildContext context) {
    final host = _hostPreview(meeting.raw);
    final attachments = _detailAttachments(meeting);
    final routePoints = _detailRoutePoints(meeting);
    final tags = _detailTags(meeting);
    final isHost = _isHost(meeting, currentUserId: currentUserId);
    final community = _communityPreview(meeting.raw);
    return ListView(
      padding: EdgeInsets.only(
        bottom: DateasyBottomNavMetrics.reservedHeight(
          context,
          extraGap: 156,
        ),
      ),
      children: [
        _BackendMeetingHero(
          meeting: meeting,
          saved: saved,
          onSaved: onSaved,
          onReport: onReport,
          reportBusy: reportBusy,
        ),
        if (isHost)
          _HostActionsPanel(
            meetingId: meeting.id,
            onRequests: onRequests,
            onPromote: onPromote,
          ),
        if (host != null) _HostCard(host: host),
        if (community != null) _CommunityLinkCard(community: community),
        if (attachments.isNotEmpty)
          _MeetingAttachmentsSection(attachments: attachments),
        if (routePoints.isNotEmpty)
          _MeetingRoutePlanSection(points: routePoints),
        if (_entryLocked(meeting, currentUserId: currentUserId))
          _EntryRequirementsSection(
            requirements: _entryRequirements(meeting.raw),
            onTap: onRequirementTap,
          ),
        _AboutSection(meeting: meeting, tags: tags),
        _PeopleSection(meeting: meeting),
        if (_hasLocation(meeting)) _LocationSection(meeting: meeting),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StickyMeetingActions extends StatelessWidget {
  const _StickyMeetingActions({
    required this.meeting,
    required this.currentUserId,
    required this.joined,
    required this.isHost,
    required this.busy,
    required this.error,
    required this.onJoin,
    required this.onFinishHost,
    required this.onJoinRequest,
    required this.onCancelJoinRequest,
    required this.inviteRequestId,
    required this.onAcceptInvite,
    required this.onDeclineInvite,
    required this.onRequirementTap,
    required this.onInvite,
  });

  final BackendCardItem meeting;
  final String? currentUserId;
  final bool joined;
  final bool isHost;
  final bool busy;
  final String? error;
  final VoidCallback onJoin;
  final VoidCallback onFinishHost;
  final VoidCallback onJoinRequest;
  final VoidCallback onCancelJoinRequest;
  final String? inviteRequestId;
  final ValueChanged<String> onAcceptInvite;
  final ValueChanged<String> onDeclineInvite;
  final ValueChanged<EventEntryRequirement> onRequirementTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final chatId = joined ? _stringOrNull(meeting.raw['chatId']) : null;
    final canInvite = _canInvite(meeting, currentUserId: currentUserId);
    final pending = _hasPendingJoinRequest(meeting);
    final pendingInviteRequestId = _pendingInviteRequestId(
      meeting,
      explicitRequestId: inviteRequestId,
    );
    final hasPendingInvite = pendingInviteRequestId != null;
    final locked = _entryLocked(meeting, currentUserId: currentUserId);
    final primaryRequirement =
        _entryRequirements(meeting.raw).missing.firstOrNull;
    final primaryTap = isHost
        ? onFinishHost
        : locked && primaryRequirement != null
            ? () => onRequirementTap(primaryRequirement)
            : hasPendingInvite
                ? () => onAcceptInvite(pendingInviteRequestId)
                : pending
                    ? null
                    : joined
                        ? onJoin
                        : _requiresJoinRequest(meeting)
                            ? onJoinRequest
                            : onJoin;
    final secondaryRequirement =
        _entryRequirements(meeting.raw).missing.skip(1).firstOrNull;
    final secondaryLabel = hasPendingInvite
        ? 'Отклонить'
        : pending
            ? 'Отменить заявку'
            : locked && secondaryRequirement != null
                ? _entryRequirementActionLabel(secondaryRequirement)
                : null;
    final secondaryTap = hasPendingInvite
        ? () => onDeclineInvite(pendingInviteRequestId)
        : pending
            ? onCancelJoinRequest
            : locked && secondaryRequirement != null
                ? () => onRequirementTap(secondaryRequirement)
                : null;
    return Positioned(
      left: 16,
      right: 16,
      bottom: DateasyBottomNavMetrics.reservedHeight(
        context,
        extraGap: 24,
      ),
      child: _GlassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (chatId != null) ...[
              _StickyIconButton(
                icon: LucideIcons.messageCircle,
                label: 'Чат встречи',
                onTap: () => context.go(
                  '/chats/${Uri.encodeComponent(chatId)}',
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (canInvite) ...[
              _StickyIconButton(
                icon: LucideIcons.userPlus,
                label: 'Позвать друзей',
                onTap: onInvite,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: busy ? null : primaryTap,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: busy ? 0.65 : 1,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: joined || pending ? DateasyColors.glass : null,
                          gradient:
                              joined || pending ? null : dateasyLimeGradient,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: joined || pending
                                ? DateasyColors.lime.withValues(alpha: 0.45)
                                : Colors.transparent,
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                error ??
                                    _primaryMeetingActionLabel(
                                      meeting,
                                      joined: joined,
                                      isHost: isHost,
                                      locked: locked,
                                      inviteRequestId: pendingInviteRequestId,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: joined || pending
                                          ? DateasyColors.lime
                                          : DateasyColors.backgroundDeep,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                      ),
                    ),
                  ),
                  if (secondaryLabel != null && secondaryTap != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: busy ? null : secondaryTap,
                      child: Text(
                        secondaryLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyIconButton extends StatelessWidget {
  const _StickyIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: DateasyColors.glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DateasyColors.border),
          ),
          child: Icon(
            icon,
            color: DateasyColors.foreground,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _HostActionsPanel extends StatelessWidget {
  const _HostActionsPanel({
    required this.meetingId,
    required this.onRequests,
    required this.onPromote,
  });

  final String meetingId;
  final VoidCallback onRequests;
  final VoidCallback onPromote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: DateasyColors.lime.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: DateasyColors.lime.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _HostActionButton(
                icon: LucideIcons.pencil,
                iconColor: DateasyColors.lime,
                label: 'Редактировать',
                onTap: () => context.push(
                  '/meetings/new?editEventId=${Uri.encodeComponent(meetingId)}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HostActionButton(
                icon: LucideIcons.zap,
                iconColor: DateasyColors.pink,
                label: 'Продвинуть',
                onTap: onPromote,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HostActionButton(
                icon: LucideIcons.clipboardList,
                iconColor: DateasyColors.lilac,
                label: 'Заявки',
                onTap: onRequests,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostRequestsSheet extends ConsumerStatefulWidget {
  const _HostRequestsSheet({
    required this.eventId,
    required this.eventTitle,
    required this.onChanged,
  });

  final String eventId;
  final String eventTitle;
  final VoidCallback onChanged;

  @override
  ConsumerState<_HostRequestsSheet> createState() => _HostRequestsSheetState();
}

class _HostRequestsSheetState extends ConsumerState<_HostRequestsSheet> {
  final Set<String> _busyRequests = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostDashboardProvider);
    final dashboard = state.valueOrNull;
    final requests = (dashboard?.requests ?? const <HostJoinRequestData>[])
        .where((request) =>
            request.eventId == widget.eventId && _isPendingHostRequest(request))
        .toList(growable: false);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: DateasyColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Заявки на встречу',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DateasyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.eventTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 18),
            if (state.isLoading && dashboard == null)
              const _HostRequestsStatus(text: 'Загружаем заявки')
            else if (state.hasError && dashboard == null)
              const _HostRequestsStatus(text: 'Не удалось загрузить заявки')
            else if (requests.isEmpty)
              const _HostRequestsStatus(text: 'Новых заявок нет')
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _HostRequestTile(
                      request: request,
                      busy: _busyRequests.contains(request.id),
                      onApprove: () => _reviewRequest(request, true),
                      onReject: () => _reviewRequest(request, false),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewRequest(
    HostJoinRequestData request,
    bool approve,
  ) async {
    if (_busyRequests.contains(request.id)) {
      return;
    }
    setState(() => _busyRequests.add(request.id));
    try {
      final controller = ref.read(hostDashboardActionsProvider);
      if (approve) {
        await controller.approveRequest(request.id);
      } else {
        await controller.rejectRequest(request.id);
      }
      widget.onChanged();
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? 'Заявка одобрена' : 'Заявка отклонена'),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обработать заявку')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyRequests.remove(request.id));
      }
    }
  }
}

class _FinishMeetingSheet extends ConsumerStatefulWidget {
  const _FinishMeetingSheet({
    required this.eventId,
    required this.eventTitle,
    required this.currentUserId,
    required this.onFinished,
  });

  final String eventId;
  final String eventTitle;
  final String? currentUserId;
  final VoidCallback onFinished;

  @override
  ConsumerState<_FinishMeetingSheet> createState() =>
      _FinishMeetingSheetState();
}

class _FinishMeetingSheetState extends ConsumerState<_FinishMeetingSheet> {
  late Future<BackendCardItem> _eventFuture;
  final Set<String> _selectedUserIds = {};
  bool _initializedSelection = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _eventFuture =
        ref.read(meetingActionsProvider).fetchHostedEvent(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: FutureBuilder<BackendCardItem>(
          future: _eventFuture,
          builder: (context, snapshot) {
            final event = snapshot.data;
            final attendees = event == null
                ? const <_MeetingAttendanceCandidate>[]
                : _attendanceCandidates(
                    event,
                    currentUserId: widget.currentUserId,
                  );
            if (event != null && !_initializedSelection) {
              _initializedSelection = true;
              _selectedUserIds.addAll(
                attendees
                    .where(
                        (attendee) => attendee.attendanceStatus == 'checked_in')
                    .map((attendee) => attendee.userId),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DateasyColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Кто был на встрече',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DateasyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.eventTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DateasyColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState != ConnectionState.done)
                  const _HostRequestsStatus(text: 'Загружаем участников')
                else if (snapshot.hasError)
                  const _HostRequestsStatus(
                    text: 'Не удалось загрузить участников',
                  )
                else if (attendees.isEmpty)
                  const _HostRequestsStatus(text: 'Гостей пока нет')
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: attendees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final attendee = attendees[index];
                        final selected =
                            _selectedUserIds.contains(attendee.userId);
                        return _FinishMeetingAttendeeTile(
                          attendee: attendee,
                          selected: selected,
                          onTap: _busy
                              ? null
                              : () {
                                  setState(() {
                                    if (selected) {
                                      _selectedUserIds.remove(attendee.userId);
                                    } else {
                                      _selectedUserIds.add(attendee.userId);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                _FinishMeetingButton(
                  busy: _busy,
                  enabled: snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError,
                  onTap: _finish,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _finish() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(meetingActionsProvider).finishHostedEvent(
            eventId: widget.eventId,
            attendedUserIds: _selectedUserIds.toList(growable: false),
          );
      widget.onFinished();
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).maybePop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Встреча завершена')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось завершить встречу')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _FinishMeetingAttendeeTile extends StatelessWidget {
  const _FinishMeetingAttendeeTile({
    required this.attendee,
    required this.selected,
    required this.onTap,
  });

  final _MeetingAttendanceCandidate attendee;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DateasyColors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? DateasyColors.lime.withValues(alpha: 0.7)
                : DateasyColors.border,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 48,
                height: 48,
                child: DateasyRemoteImage(
                  imageUrl: attendee.avatarUrl,
                  usage: DateasyImageUsage.avatar,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                attendee.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Icon(
              selected ? LucideIcons.check : LucideIcons.circle,
              color: selected ? DateasyColors.lime : DateasyColors.muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishMeetingButton extends StatelessWidget {
  const _FinishMeetingButton({
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !busy ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled && !busy ? 1 : 0.6,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: dateasyLimeGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Завершить встречу',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: DateasyColors.backgroundDeep,
                        fontWeight: FontWeight.w900,
                      ),
                ),
        ),
      ),
    );
  }
}

class _HostRequestTile extends StatelessWidget {
  const _HostRequestTile({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final HostJoinRequestData request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DateasyColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 48,
              height: 48,
              child: DateasyRemoteImage(
                imageUrl: request.avatarUrl,
                usage: DateasyImageUsage.avatar,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      request.userName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (request.verified)
                      const Icon(
                        LucideIcons.badgeCheck,
                        color: DateasyColors.lime,
                        size: 16,
                      ),
                    if (request.frendlyPlus)
                      const Icon(
                        LucideIcons.crown,
                        color: DateasyColors.pink,
                        size: 16,
                      ),
                  ],
                ),
                if (request.note != null && request.note!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      request.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          _HostRequestActionButton(
            icon: LucideIcons.x,
            busy: busy,
            onTap: busy ? null : onReject,
          ),
          const SizedBox(width: 8),
          _HostRequestActionButton(
            icon: LucideIcons.check,
            color: DateasyColors.lime,
            busy: busy,
            onTap: busy ? null : onApprove,
          ),
        ],
      ),
    );
  }
}

class _HostRequestActionButton extends StatelessWidget {
  const _HostRequestActionButton({
    required this.icon,
    required this.busy,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (color ?? DateasyColors.surface2).withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(
            color: (color ?? DateasyColors.border).withValues(alpha: 0.7),
          ),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                icon,
                color: color ?? DateasyColors.foreground,
                size: 18,
              ),
      ),
    );
  }
}

class _HostRequestsStatus extends StatelessWidget {
  const _HostRequestsStatus({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DateasyColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DateasyColors.muted,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _HostActionButton extends StatelessWidget {
  const _HostActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showMeetingInviteSheet(
  BuildContext context, {
  required String eventId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    isScrollControlled: true,
    useSafeArea: false,
    builder: (_) => _MeetingInviteSheet(
      eventId: eventId,
      title: title,
    ),
  );
}

class _MeetingInviteSheet extends ConsumerStatefulWidget {
  const _MeetingInviteSheet({
    required this.eventId,
    required this.title,
  });

  final String eventId;
  final String title;

  @override
  ConsumerState<_MeetingInviteSheet> createState() =>
      _MeetingInviteSheetState();
}

class _MeetingInviteSheetState extends ConsumerState<_MeetingInviteSheet> {
  static const _pageLimit = 20;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _sentIds = <String>{};
  final _sendingIds = <String>{};

  Timer? _debounce;
  CancelToken? _cancelToken;
  List<BackendCardItem> _people = const [];
  String? _nextCursor;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel('meeting_invite_sheet_disposed');
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_loadFirstPage());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loadingInitial ||
        _loadingMore ||
        _nextCursor == null) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadFirstPage() async {
    _cancelToken?.cancel('meeting_invite_sheet_replaced');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    if (mounted) {
      setState(() {
        _loadingInitial = true;
        _loadingMore = false;
        _failed = false;
        _nextCursor = null;
      });
    }

    try {
      final result =
          await ref.read(backendRepositoryProvider).fetchFollowingPeople(
                eventId: widget.eventId,
                q: _query,
                limit: _pageLimit,
                cancelToken: cancelToken,
              );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      setState(() {
        _people = result.items;
        _nextCursor = result.nextCursor;
        _loadingInitial = false;
      });
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        return;
      }
      _markInitialFailed();
    } catch (_) {
      _markInitialFailed();
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) {
      return;
    }
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _loadingMore = true;
    });

    try {
      final result =
          await ref.read(backendRepositoryProvider).fetchFollowingPeople(
                eventId: widget.eventId,
                q: _query,
                cursor: cursor,
                limit: _pageLimit,
                cancelToken: cancelToken,
              );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      setState(() {
        _people = [..._people, ...result.items];
        _nextCursor = result.nextCursor;
        _loadingMore = false;
      });
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        return;
      }
      _markMoreFailed();
    } catch (_) {
      _markMoreFailed();
    }
  }

  Future<void> _invite(BackendCardItem person) async {
    if (_inviteDisabled(person)) {
      return;
    }
    setState(() {
      _sendingIds.add(person.id);
    });
    try {
      await ref.read(backendRepositoryProvider).inviteUserToEvent(
            widget.eventId,
            person.id,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _sentIds.add(person.id);
        _sendingIds.remove(person.id);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sendingIds.remove(person.id);
      });
      _showSnackBar('Не получилось отправить приглашение');
    }
  }

  bool _inviteDisabled(BackendCardItem person) {
    return _sendingIds.contains(person.id) ||
        _sentIds.contains(person.id) ||
        _inviteState(person) != 'available';
  }

  void _markInitialFailed() {
    if (!mounted) {
      return;
    }
    setState(() {
      _failed = true;
      _loadingInitial = false;
    });
  }

  void _markMoreFailed() {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingMore = false;
    });
    _showSnackBar('Не получилось загрузить ещё');
  }

  String? get _query {
    final value = _searchController.text.trim();
    return value.isEmpty ? null : value;
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
        child: _GlassPanel(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Кого позвать',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: DateasyColors.foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (widget.title.trim().isNotEmpty)
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: DateasyColors.muted),
                            ),
                        ],
                      ),
                    ),
                    _GlassIconButton(
                      icon: LucideIcons.x,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: DateasyColors.foreground),
                  decoration: InputDecoration(
                    hintText: 'Найти друга',
                    hintStyle: const TextStyle(color: DateasyColors.muted),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      color: DateasyColors.muted,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: DateasyColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadingInitial) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Не получилось загрузить друзей',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                  ),
            ),
            const SizedBox(height: 10),
            _SmallGlassButton(
              label: 'Повторить',
              onTap: () => unawaited(_loadFirstPage()),
            ),
          ],
        ),
      );
    }
    if (_people.isEmpty) {
      return Center(
        child: Text(
          'Пока некого пригласить',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _people.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _people.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final person = _people[index];
        return _InvitePersonRow(
          person: person,
          sending: _sendingIds.contains(person.id),
          sent: _sentIds.contains(person.id),
          disabled: _inviteDisabled(person),
          onInvite: () => unawaited(_invite(person)),
        );
      },
    );
  }
}

class _InvitePersonRow extends StatelessWidget {
  const _InvitePersonRow({
    required this.person,
    required this.sending,
    required this.sent,
    required this.disabled,
    required this.onInvite,
  });

  final BackendCardItem person;
  final bool sending;
  final bool sent;
  final bool disabled;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final label = _inviteButtonLabel(person, sent: sent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _SquareAvatar(imageUrl: person.imageUrl, size: 48, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.title.isEmpty ? 'Друг' : person.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DateasyColors.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if ((person.subtitle ?? '').isNotEmpty)
                  Text(
                    person.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: disabled ? null : onInvite,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: disabled && !sent ? 0.72 : 1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 112),
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: disabled ? DateasyColors.surface2 : null,
                  gradient: disabled ? null : dateasyLimeGradient,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: DateasyColors.border),
                ),
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: disabled
                                      ? DateasyColors.muted
                                      : DateasyColors.backgroundDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.host});

  final _PersonPreview host;

  @override
  Widget build(BuildContext context) {
    final rating = host.rating?.toStringAsFixed(1);
    final subtitle = [
      if (rating != null) rating,
      if (host.meetupCount != null) '${host.meetupCount} встреч',
      if (host.verified) 'проверен',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _SquareAvatar(imageUrl: host.avatarUrl, size: 62, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Хост',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: DateasyColors.lime,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    host.name.isEmpty ? 'Хост встречи' : host.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: DateasyColors.foreground,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (host.userId != null)
              _SmallGlassButton(
                label: 'Профиль',
                onTap: () =>
                    context.push('/u/${Uri.encodeComponent(host.userId!)}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityLinkCard extends StatelessWidget {
  const _CommunityLinkCard({required this.community});

  final _CommunityPreview community;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: GestureDetector(
        onTap: () => context.go(
          '/communities/${Uri.encodeComponent(community.id)}',
        ),
        child: _GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _SquareAvatar(
                  imageUrl: community.avatarUrl, size: 52, radius: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сообщество',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: DateasyColors.lime,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      community.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: DateasyColors.foreground,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: DateasyColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingAttachmentsSection extends StatelessWidget {
  const _MeetingAttachmentsSection({required this.attachments});

  final List<_AttachmentDetail> attachments;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Вложено во встречу',
            trailing: '${attachments.length}',
          ),
          const SizedBox(height: 10),
          for (final attachment in attachments) ...[
            _AttachmentCard(attachment: attachment),
            if (attachment != attachments.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MeetingRoutePlanSection extends StatelessWidget {
  const _MeetingRoutePlanSection({required this.points});

  final List<_RoutePointDetail> points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'План вечера'),
          const SizedBox(height: 10),
          _GlassPanel(
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < points.length; index++) ...[
                  _RoutePointRow(point: points[index], index: index),
                  if (index != points.length - 1)
                    Divider(
                      height: 1,
                      indent: 64,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePointRow extends StatelessWidget {
  const _RoutePointRow({
    required this.point,
    required this.index,
  });

  final _RoutePointDetail point;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isFirst = index == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isFirst ? dateasyLimeGradient : null,
              color: isFirst ? null : DateasyColors.surface2,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isFirst ? LucideIcons.check : LucideIcons.clock,
              color:
                  isFirst ? DateasyColors.backgroundDeep : DateasyColors.muted,
              size: isFirst ? 21 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DateasyColors.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (point.subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    point.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RoutePointActionButton(point: point),
        ],
      ),
    );
  }
}

class _RoutePointActionButton extends StatelessWidget {
  const _RoutePointActionButton({required this.point});

  final _RoutePointDetail point;

  @override
  Widget build(BuildContext context) {
    final hasExternalUrl = point.actionUrl != null;
    return GestureDetector(
      onTap: () => _openRoutePointAction(context, point),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 138),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: hasExternalUrl ? dateasyLimeGradient : null,
            color: hasExternalUrl ? null : DateasyColors.glass,
            borderRadius: BorderRadius.circular(999),
            border: hasExternalUrl
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasExternalUrl ? LucideIcons.ticket : LucideIcons.mapPin,
                size: 13,
                color: hasExternalUrl
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.lime,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  point.actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: hasExternalUrl
                            ? DateasyColors.backgroundDeep
                            : DateasyColors.foreground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
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

class _EntryRequirementsSection extends StatelessWidget {
  const _EntryRequirementsSection({
    required this.requirements,
    required this.onTap,
  });

  final EventEntryRequirements requirements;
  final ValueChanged<EventEntryRequirement> onTap;

  @override
  Widget build(BuildContext context) {
    if (requirements.missing.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'Доступ закрыт'),
            const SizedBox(height: 10),
            Text(
              'Эта встреча доступна после проверки условий.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            for (final requirement in requirements.missing) ...[
              _RequirementRow(requirement: requirement, onTap: onTap),
              if (requirement != requirements.missing.last)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.requirement,
    required this.onTap,
  });

  final EventEntryRequirement requirement;
  final ValueChanged<EventEntryRequirement> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: DateasyColors.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            requirement == EventEntryRequirement.verification
                ? LucideIcons.badgeCheck
                : requirement == EventEntryRequirement.frendlyPlus
                    ? LucideIcons.sparkles
                    : LucideIcons.users,
            color: DateasyColors.lime,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _entryRequirementTitle(requirement),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DateasyColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 8),
        _SmallGlassButton(
          label: _entryRequirementShortActionLabel(requirement),
          onTap: () => onTap(requirement),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment});

  final _AttachmentDetail attachment;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: attachment.gradient == null
                ? attachment.foreground.withValues(alpha: 0.18)
                : null,
            gradient: attachment.gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            attachment.icon,
            color: attachment.iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attachment.kindLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: DateasyColors.muted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                attachment.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: DateasyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (attachment.subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  attachment.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                        height: 1.25,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _AttachmentActionButton(attachment: attachment),
      ],
    );

    return _GlassPanel(
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      child: content,
    );
  }
}

class _AttachmentActionButton extends StatelessWidget {
  const _AttachmentActionButton({required this.attachment});

  final _AttachmentDetail attachment;

  @override
  Widget build(BuildContext context) {
    final hasGradient = attachment.gradient != null;
    final textColor =
        hasGradient ? DateasyColors.backgroundDeep : DateasyColors.background;
    return GestureDetector(
      onTap: () => _openAttachment(context, attachment),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasGradient ? null : DateasyColors.foreground,
          gradient: attachment.gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: hasGradient
              ? [
                  BoxShadow(
                    color: attachment.foreground.withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          attachment.actionLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.meeting, required this.tags});

  final BackendCardItem meeting;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final text = _detailDescription(meeting);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'О встрече'),
            const SizedBox(height: 10),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    height: 1.42,
                  ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags) _InfoChip(label: tag),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({required this.meeting});

  final BackendCardItem meeting;

  @override
  Widget build(BuildContext context) {
    final host = _hostPreview(meeting.raw);
    final attendees = _attendeePreviews(meeting.raw);
    if (host == null && attendees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Кто идёт',
              trailing: _peopleCountLabel(meeting.raw),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: (host == null ? 0 : 1) + attendees.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final person = host != null && index == 0
                      ? host
                      : attendees[index - (host == null ? 0 : 1)];
                  return _PersonTile(
                    person: person,
                    label: person == host ? 'Хост' : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, this.label});

  final _PersonPreview person;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SquareAvatar(imageUrl: person.avatarUrl, size: 64, radius: 18),
          const SizedBox(height: 7),
          Text(
            person.name.isEmpty ? 'Участник' : person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DateasyColors.foreground,
                ),
          ),
          if (label != null)
            Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: DateasyColors.lime,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.meeting});

  final BackendCardItem meeting;

  @override
  Widget build(BuildContext context) {
    final place = _locationTitle(meeting);
    final city = meeting.city;
    final routeId = _stringOrNull(meeting.raw['routeId']);
    final fallbackQuery = _locationSearchQuery(meeting);
    final mapTarget = dateasyMapChoiceUrls(
      latitude: meeting.latitude,
      longitude: meeting.longitude,
      label: place,
      fallbackQuery: fallbackQuery,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Локация'),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: mapTarget == null
                ? null
                : () => showDateasyMapChoiceSheet(
                      context,
                      latitude: meeting.latitude,
                      longitude: meeting.longitude,
                      label: place,
                      fallbackQuery: fallbackQuery,
                    ),
            child: Container(
              height: 168,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: DateasyColors.border),
                gradient: RadialGradient(
                  center: const Alignment(0.1, -0.2),
                  radius: 1.0,
                  colors: [
                    DateasyColors.lime.withValues(alpha: 0.34),
                    DateasyColors.pink.withValues(alpha: 0.14),
                    DateasyColors.glass,
                  ],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: dateasyLimeGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: DateasyColors.lime.withValues(alpha: 0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.mapPin,
                        color: DateasyColors.backgroundDeep,
                        size: 34,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _GlassPanel(
                      borderRadius: 20,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  place,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: DateasyColors.foreground,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                if (city != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: DateasyColors.muted,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (routeId != null)
                            _SmallGlassButton(
                              label: 'Маршрут',
                              onTap: () => context.go(
                                '/routes/${Uri.encodeComponent(routeId)}',
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
        ],
      ),
    );
  }
}

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({
    required this.imageUrl,
    required this.size,
    required this.radius,
  });

  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: DateasyColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: DateasyRemoteImage(
        imageUrl: imageUrl,
        usage: DateasyImageUsage.avatar,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: DateasyColors.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.lime,
                  fontWeight: FontWeight.w800,
                ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SmallGlassButton extends StatelessWidget {
  const _SmallGlassButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DateasyColors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: DateasyColors.foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _BackendMeetingHero extends StatelessWidget {
  const _BackendMeetingHero({
    required this.meeting,
    required this.saved,
    required this.onSaved,
    required this.reportBusy,
    this.onReport,
  });

  final BackendCardItem meeting;
  final bool saved;
  final VoidCallback onSaved;
  final VoidCallback? onReport;
  final bool reportBusy;

  @override
  Widget build(BuildContext context) {
    final boostTier = meetingBoostTierFromRaw(meeting.raw);
    return SizedBox(
      height: 288,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DateasyRemoteImage(
            imageUrl: meeting.imageUrl,
            imageVariants: meeting.raw['imageVariants'],
            usage: DateasyImageUsage.hero,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x661F0C3F),
                  Color(0x331F0C3F),
                  DateasyColors.background,
                ],
                stops: [0, 0.52, 1],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassIconButton(
                  icon: LucideIcons.arrowLeft,
                  onTap: () => context.go('/meetings'),
                ),
                Row(
                  children: [
                    _GlassIconButton(
                      icon: LucideIcons.images,
                      onTap: () => context.go(
                        '/stories?eventId=${Uri.encodeComponent(meeting.id)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _GlassIconButton(
                      icon: LucideIcons.share2,
                      onTap: () => context.go(
                        '/share?targetType=event&targetId=${Uri.encodeComponent(meeting.id)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onReport != null) ...[
                      _GlassIconButton(
                        key: const ValueKey('meeting-report-action'),
                        icon: reportBusy
                            ? LucideIcons.loaderCircle
                            : LucideIcons.flag,
                        onTap: reportBusy ? () {} : onReport!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _GlassIconButton(
                      icon: LucideIcons.bookmark,
                      active: saved,
                      onTap: onSaved,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _LimeBadge(
                        label: _formatDate(meeting.startsAt) ?? 'Встреча'),
                    if (boostTier != null) MeetingBoostBadge(tier: boostTier),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  meeting.title.isEmpty ? 'Встреча' : meeting.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 13,
                      color: DateasyColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        meeting.city ?? meeting.subtitle ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DateasyColors.muted,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoteMeetingSheet extends StatelessWidget {
  const _PromoteMeetingSheet({required this.currentTier});

  final MeetingBoostTier? currentTier;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  LucideIcons.zap,
                  color: DateasyColors.pink,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Продвинуть встречу',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _GlassIconButton(
                  icon: LucideIcons.x,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Выбери длительность, больше людей увидят встречу',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                  ),
            ),
            const SizedBox(height: 16),
            for (final tier in meetingBoostTiers) ...[
              _PromoteTierRow(
                tier: tier,
                active: currentTier?.optionId == tier.optionId,
                onTap: () => Navigator.of(context).pop(tier),
              ),
              const SizedBox(height: 10),
            ],
            Center(
              child: Text(
                'FT списываются с баланса',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.muted,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoteTierRow extends StatelessWidget {
  const _PromoteTierRow({
    required this.tier,
    required this.active,
    required this.onTap,
  });

  final MeetingBoostTier tier;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = meetingBoostVisual(tier);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              visual.primary.withValues(alpha: active ? 0.28 : 0.16),
              DateasyColors.surface.withValues(alpha: 0.74),
            ],
          ),
          border: Border.all(
            color: visual.primary.withValues(alpha: active ? 0.62 : 0.34),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: visual.gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(tier.icon, color: visual.foreground, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tier.label} · ${tier.hours}ч',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tier.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: DateasyColors.foreground,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                '${tier.price} FT',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.backgroundDeep,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStatus extends StatelessWidget {
  const _DetailStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? DateasyColors.lime : DateasyColors.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(
              active && icon == LucideIcons.bookmark ? Icons.bookmark : icon,
              color: active
                  ? DateasyColors.backgroundDeep
                  : DateasyColors.foreground,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _LimeBadge extends StatelessWidget {
  const _LimeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: dateasyLimeGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.backgroundDeep,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AttachmentDetail {
  const _AttachmentDetail({
    required this.kindLabel,
    required this.title,
    required this.icon,
    required this.foreground,
    required this.iconColor,
    required this.actionLabel,
    this.subtitle,
    this.gradient,
    this.actionUrl,
  });

  final String kindLabel;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color foreground;
  final Color iconColor;
  final String actionLabel;
  final Gradient? gradient;
  final String? actionUrl;
}

String? _formatDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

bool _isHost(BackendCardItem meeting, {String? currentUserId}) {
  if (meeting.raw['isHost'] == true ||
      meeting.raw['viewerState']?.toString().toLowerCase() == 'host' ||
      meeting.raw['participantState']?.toString().toLowerCase() == 'host') {
    return true;
  }
  final userId = currentUserId?.trim();
  if (userId == null || userId.isEmpty) {
    return false;
  }
  return _hostUserId(meeting.raw) == userId;
}

bool _canInvite(BackendCardItem meeting, {String? currentUserId}) {
  return meeting.id.isNotEmpty &&
      (_isHost(meeting, currentUserId: currentUserId) ||
          meetingViewerHasJoined(meeting));
}

String _inviteState(BackendCardItem person) {
  return _rawLower(person.raw, 'inviteState') ?? 'available';
}

String _inviteButtonLabel(BackendCardItem person, {required bool sent}) {
  if (sent) {
    return 'Отправлено';
  }
  return switch (_inviteState(person)) {
    'already_joined' || 'joined' => 'Уже идёт',
    'pending_invite' || 'invited' => 'Уже приглашён',
    'pending_request' => 'Заявка есть',
    _ => 'Пригласить',
  };
}

bool _requiresJoinRequest(BackendCardItem meeting) {
  final raw = meeting.raw;
  return _rawLower(raw, 'accessMode') == 'request' ||
      _rawLower(raw, 'joinMode') == 'request' ||
      _rawLower(raw, 'visibilityMode') == 'friends';
}

bool _hasPendingJoinRequest(BackendCardItem meeting) {
  final raw = meeting.raw;
  final status = _firstRawLower(raw, const [
    'joinRequestStatus',
    'requestStatus',
    'participantState',
    'viewerState',
  ]);
  return status == 'pending' ||
      status == 'pending_request' ||
      status == 'requested';
}

bool _isPendingHostRequest(HostJoinRequestData request) {
  final status = request.status.trim().toLowerCase();
  return status.isEmpty || status == 'pending' || status == 'requested';
}

bool _entryLocked(BackendCardItem meeting, {String? currentUserId}) {
  return !_isHost(meeting, currentUserId: currentUserId) &&
      !meetingViewerHasJoined(meeting) &&
      !_entryRequirements(meeting.raw).canJoin;
}

String _primaryMeetingActionLabel(
  BackendCardItem meeting, {
  required bool joined,
  required bool isHost,
  required bool locked,
  String? inviteRequestId,
}) {
  if (locked) {
    final requirement = _entryRequirements(meeting.raw).missing.firstOrNull;
    return requirement == null
        ? 'Доступ закрыт'
        : _entryRequirementActionLabel(requirement);
  }
  if (_hasPendingJoinRequest(meeting)) {
    if (inviteRequestId != null) {
      return 'Принять';
    }
    return 'Заявка отправлена';
  }
  if (joined) {
    return isHost ? 'Завершить встречу' : 'Выйти';
  }
  if (_requiresJoinRequest(meeting)) {
    return 'Отправить заявку';
  }
  return 'Присоединиться';
}

String? _pendingInviteRequestId(
  BackendCardItem meeting, {
  String? explicitRequestId,
}) {
  final explicit = explicitRequestId?.trim();
  if (explicit != null &&
      explicit.isNotEmpty &&
      _hasPendingJoinRequest(meeting)) {
    return explicit;
  }
  if (!_hasPendingEventInvite(meeting)) {
    return null;
  }
  return _stringOrNull(
    meeting.raw['joinRequestId'] ??
        meeting.raw['requestId'] ??
        meeting.raw['inviteRequestId'],
  );
}

bool _hasPendingEventInvite(BackendCardItem meeting) {
  if (!_hasPendingJoinRequest(meeting)) {
    return false;
  }
  final raw = meeting.raw;
  if (raw['invite'] == true || raw['isInvite'] == true) {
    return true;
  }
  final kind = _firstRawLower(raw, const [
    'joinRequestKind',
    'requestKind',
    'inviteState',
  ]);
  if (kind == 'invite' || kind == 'pending_invite' || kind == 'invited') {
    return true;
  }
  return _stringOrNull(raw['joinRequestReviewedById']) != null;
}

String _entryRequirementTitle(EventEntryRequirement requirement) {
  return switch (requirement) {
    EventEntryRequirement.verification => 'Нужна верификация',
    EventEntryRequirement.frendlyPlus => 'Нужен Frendly+',
    EventEntryRequirement.gender => 'Встреча не для вашего пола',
  };
}

String _entryRequirementActionLabel(EventEntryRequirement requirement) {
  return switch (requirement) {
    EventEntryRequirement.verification => 'Пройти верификацию',
    EventEntryRequirement.frendlyPlus => 'Открыть Frendly+',
    EventEntryRequirement.gender => 'Недоступно',
  };
}

String _entryRequirementShortActionLabel(EventEntryRequirement requirement) {
  return switch (requirement) {
    EventEntryRequirement.verification => 'Проверка',
    EventEntryRequirement.frendlyPlus => 'Frendly+',
    EventEntryRequirement.gender => 'Закрыто',
  };
}

EventEntryRequirements _entryRequirements(Map<String, Object?> raw) {
  final value = raw['entryRequirements'];
  if (value is Map) {
    final mapped = value.map((key, value) => MapEntry('$key', value));
    return EventEntryRequirements.fromJson(mapped);
  }
  final missing = <EventEntryRequirement>[
    if (raw['requiresVerification'] == true) EventEntryRequirement.verification,
    if (raw['requiresFrendlyPlus'] == true) EventEntryRequirement.frendlyPlus,
  ];
  return EventEntryRequirements(
    canJoin: missing.isEmpty,
    missing: missing,
  );
}

enum EventEntryRequirement { verification, frendlyPlus, gender }

class EventEntryRequirements {
  const EventEntryRequirements({
    required this.canJoin,
    required this.missing,
  });

  final bool canJoin;
  final List<EventEntryRequirement> missing;

  factory EventEntryRequirements.fromJson(Map<String, Object?> json) {
    final rawMissing = json['missing'];
    return EventEntryRequirements(
      canJoin: json['canJoin'] != false,
      missing: rawMissing is List
          ? rawMissing
              .map((item) => item.toString())
              .map(_entryRequirementFromString)
              .whereType<EventEntryRequirement>()
              .toList(growable: false)
          : const [],
    );
  }
}

EventEntryRequirement? _entryRequirementFromString(String value) {
  return switch (value) {
    'verification' || 'verified' => EventEntryRequirement.verification,
    'frendly_plus' ||
    'plus' ||
    'frendlyPlus' =>
      EventEntryRequirement.frendlyPlus,
    'gender' || 'gender_mode' => EventEntryRequirement.gender,
    _ => null,
  };
}

class _PersonPreview {
  const _PersonPreview({
    required this.name,
    this.avatarUrl,
    this.userId,
    this.rating,
    this.meetupCount,
    this.verified = false,
  });

  final String name;
  final String? avatarUrl;
  final String? userId;
  final double? rating;
  final int? meetupCount;
  final bool verified;
}

class _MeetingAttendanceCandidate {
  const _MeetingAttendanceCandidate({
    required this.userId,
    required this.displayName,
    required this.attendanceStatus,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String attendanceStatus;
  final String? avatarUrl;
}

class _CommunityPreview {
  const _CommunityPreview({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;
}

class _RoutePointDetail {
  const _RoutePointDetail({
    required this.title,
    required this.actionLabel,
    this.time,
    this.venue,
    this.address,
    this.actionUrl,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String? time;
  final String? venue;
  final String? address;
  final String actionLabel;
  final String? actionUrl;
  final double? latitude;
  final double? longitude;

  String? get subtitle {
    final parts = [
      if (time != null) time,
      venue ?? address,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get mapLabel => venue ?? title;

  String? get fallbackQuery {
    final parts = [
      venue,
      address,
      title,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}

_CommunityPreview? _communityPreview(Map<String, Object?> raw) {
  final community = raw['community'];
  if (community is! Map) {
    return null;
  }
  final id = _stringOrNull(
    community['id'] ?? community['communityId'],
  );
  if (id == null) {
    return null;
  }
  final name = _stringOrNull(
        community['name'] ?? community['title'],
      ) ??
      'Сообщество';
  return _CommunityPreview(
    id: id,
    name: name,
    avatarUrl: _stringOrNull(
      community['avatarUrl'] ?? community['avatar'] ?? community['imageUrl'],
    ),
  );
}

_PersonPreview? _hostPreview(Map<String, Object?> raw) {
  final host = raw['host'];
  if (host is! Map) {
    return null;
  }
  final profile = host['profile'];
  final media = host['media'];
  return _PersonPreview(
    name: _string(host['displayName'] ?? host['name']),
    userId: _stringOrNull(host['id'] ?? host['userId']),
    avatarUrl: _stringOrNull(
      host['avatarUrl'] ??
          host['photoUrl'] ??
          host['imageUrl'] ??
          (profile is Map
              ? profile['avatarUrl'] ??
                  profile['photoUrl'] ??
                  profile['imageUrl']
              : null) ??
          (media is Map ? media['url'] ?? media['downloadUrl'] : null),
    ),
    rating: _doubleOrNull(host['rating']),
    meetupCount: _intOrNull(host['meetupCount']),
    verified: host['verified'] == true,
  );
}

String? _hostUserId(Map<String, Object?> raw) {
  final host = raw['host'];
  if (host is Map) {
    return _stringOrNull(host['id'] ?? host['userId']);
  }
  return _stringOrNull(
    raw['hostId'] ?? raw['creatorId'] ?? raw['createdById'] ?? raw['ownerId'],
  );
}

List<_PersonPreview> _attendeePreviews(Map<String, Object?> raw) {
  final source = raw['attendees'] ?? raw['participants'];
  if (source is! List) {
    return const [];
  }
  return source
      .whereType<Map>()
      .map((item) {
        final user = item['user'];
        final profile = item['profile'];
        final userProfile = user is Map ? user['profile'] : null;
        final media = item['media'];
        return _PersonPreview(
          name: _string(
            item['displayName'] ??
                item['name'] ??
                (user is Map ? user['displayName'] ?? user['name'] : null),
          ),
          userId: _stringOrNull(
            item['userId'] ?? (user is Map ? user['id'] : null) ?? item['id'],
          ),
          avatarUrl: _stringOrNull(
            item['avatarUrl'] ??
                item['photoUrl'] ??
                item['imageUrl'] ??
                (profile is Map
                    ? profile['avatarUrl'] ??
                        profile['photoUrl'] ??
                        profile['imageUrl']
                    : null) ??
                (user is Map
                    ? user['avatarUrl'] ?? user['photoUrl'] ?? user['imageUrl']
                    : null) ??
                (userProfile is Map
                    ? userProfile['avatarUrl'] ??
                        userProfile['photoUrl'] ??
                        userProfile['imageUrl']
                    : null) ??
                (media is Map ? media['url'] ?? media['downloadUrl'] : null),
          ),
        );
      })
      .where((person) => person.name.isNotEmpty || person.avatarUrl != null)
      .toList(growable: false);
}

List<_MeetingAttendanceCandidate> _attendanceCandidates(
  BackendCardItem meeting, {
  required String? currentUserId,
}) {
  final raw = meeting.raw;
  final hostId = _hostUserId(raw);
  final source = raw['attendees'] ?? raw['participants'];
  if (source is! List) {
    return const [];
  }
  return source
      .whereType<Map>()
      .map((item) {
        final user = item['user'];
        final profile = item['profile'];
        final userProfile = user is Map ? user['profile'] : null;
        final media = item['media'];
        final userId = _stringOrNull(
          item['userId'] ?? (user is Map ? user['id'] : null) ?? item['id'],
        );
        if (userId == null || userId == currentUserId || userId == hostId) {
          return null;
        }
        final name = _string(
          item['displayName'] ??
              item['name'] ??
              (user is Map ? user['displayName'] ?? user['name'] : null),
        ).trim();
        return _MeetingAttendanceCandidate(
          userId: userId,
          displayName: name.isEmpty ? 'Гость' : name,
          attendanceStatus:
              _stringOrNull(item['attendanceStatus']) ?? 'not_checked_in',
          avatarUrl: _stringOrNull(
            item['avatarUrl'] ??
                item['photoUrl'] ??
                item['imageUrl'] ??
                (profile is Map
                    ? profile['avatarUrl'] ??
                        profile['photoUrl'] ??
                        profile['imageUrl']
                    : null) ??
                (user is Map
                    ? user['avatarUrl'] ?? user['photoUrl'] ?? user['imageUrl']
                    : null) ??
                (userProfile is Map
                    ? userProfile['avatarUrl'] ??
                        userProfile['photoUrl'] ??
                        userProfile['imageUrl']
                    : null) ??
                (media is Map ? media['url'] ?? media['downloadUrl'] : null),
          ),
        );
      })
      .nonNulls
      .toList(growable: false);
}

List<_RoutePointDetail> _detailRoutePoints(BackendCardItem meeting) {
  final source = meeting.raw['routePoints'];
  if (source is! List) {
    return const [];
  }
  return source
      .whereType<Map>()
      .map((item) {
        final raw = item.map((key, value) => MapEntry('$key', value));
        final title = _stringOrNull(raw['title'] ?? raw['name']);
        final venue = _stringOrNull(raw['venue'] ?? raw['place']);
        final address = _stringOrNull(raw['address']);
        final displayTitle = title ?? venue ?? address;
        if (displayTitle == null) {
          return null;
        }
        final ticketUrl = _stringOrNull(
          raw['ticketUrl'] ?? raw['actionUrl'] ?? raw['bookingUrl'],
        );
        final sourceCode =
            _stringOrNull(raw['ticketSourceCode'] ?? raw['sourceCode'])
                ?.toLowerCase();
        final actionLabel = ticketUrl == null
            ? 'На карте'
            : sourceCode == 'tomesto'
                ? 'Забронировать столик'
                : 'Купить билет';
        return _RoutePointDetail(
          title: displayTitle,
          time: _stringOrNull(raw['time'] ?? raw['timeLabel']),
          venue: venue,
          address: address,
          actionUrl: ticketUrl,
          actionLabel: actionLabel,
          latitude: _doubleOrNull(raw['latitude'] ?? raw['lat']),
          longitude: _doubleOrNull(raw['longitude'] ?? raw['lng']),
        );
      })
      .nonNulls
      .toList(growable: false);
}

List<_AttachmentDetail> _detailAttachments(BackendCardItem meeting) {
  final raw = meeting.raw;
  final attachments = <_AttachmentDetail>[];
  final ticketUrl = _stringOrNull(raw['ticketUrl']);
  if (ticketUrl != null) {
    attachments.add(
      _AttachmentDetail(
        kindLabel: 'Афиша',
        title: _stringOrNull(raw['ticketVenue']) ?? meeting.title,
        subtitle: _ticketSubtitle(raw),
        icon: LucideIcons.ticket,
        foreground: DateasyColors.pink,
        iconColor: DateasyColors.backgroundDeep,
        gradient: dateasyPinkGradient,
        actionLabel: 'Билет',
        actionUrl: ticketUrl,
      ),
    );
  }

  final bookingUrl = _stringOrNull(raw['bookingUrl']);
  final bookingPromo = _firstBookingPromo(raw);
  final partnerName = _stringOrNull(raw['partnerName']);
  final partnerOffer = _stringOrNull(raw['partnerOffer']);
  if (bookingUrl != null || bookingPromo != null || partnerName != null) {
    attachments.add(
      _AttachmentDetail(
        kindLabel: 'Заведение',
        title: partnerName ?? _locationTitle(meeting),
        subtitle: partnerOffer ??
            _stringOrNull(bookingPromo?['description']) ??
            _stringOrNull(bookingPromo?['title']) ??
            _bookingSubtitle(raw),
        icon: LucideIcons.percent,
        foreground: DateasyColors.lime,
        iconColor: DateasyColors.backgroundDeep,
        gradient: dateasyLimeGradient,
        actionLabel: bookingUrl == null ? 'Промо' : 'Забронировать',
        actionUrl: bookingUrl ?? _stringOrNull(bookingPromo?['bookingUrl']),
      ),
    );
  }

  return attachments;
}

List<String> _detailTags(BackendCardItem meeting) {
  final raw = meeting.raw;
  final tags = <String>[];
  for (final key in ['vibe', 'lifestyle', 'category', 'priceMode']) {
    final value = _stringOrNull(raw[key]);
    if (value != null && !tags.contains(value)) {
      tags.add(value);
    }
  }
  if (raw['requiresVerification'] == true) {
    tags.add('Верификация');
  }
  if (raw['requiresFrendlyPlus'] == true) {
    tags.add('Frendly+');
  }
  final genderLabel = _genderModeLabel(_stringOrNull(raw['genderMode']));
  if (genderLabel != null) {
    tags.add(genderLabel);
  }
  if (_requiresJoinRequest(meeting)) {
    tags.add('По заявке');
  }
  return tags.take(7).toList(growable: false);
}

String? _genderModeLabel(String? value) {
  return switch (value?.toLowerCase()) {
    'male' || 'men' || 'm' => 'Для парней',
    'female' || 'women' || 'f' => 'Для девушек',
    _ => null,
  };
}

String _detailDescription(BackendCardItem meeting) {
  return _stringOrNull(meeting.raw['description']) ??
      meeting.subtitle ??
      _stringOrNull(meeting.raw['hostNote']) ??
      'Описание появится, когда backend отдаст подробности встречи';
}

String _locationTitle(BackendCardItem meeting) {
  return _stringOrNull(meeting.raw['place']) ??
      _stringOrNull(meeting.raw['address']) ??
      meeting.city ??
      meeting.subtitle ??
      'Место встречи';
}

String? _locationSearchQuery(BackendCardItem meeting) {
  final parts = <String>[];
  for (final value in [
    _stringOrNull(meeting.raw['place']),
    _stringOrNull(meeting.raw['address']),
    _stringOrNull(meeting.raw['placeAddress']),
    meeting.subtitle,
    meeting.city,
  ]) {
    final clean = _stringOrNull(value);
    if (clean != null && !parts.contains(clean)) {
      parts.add(clean);
    }
  }
  return parts.isEmpty ? null : parts.join(', ');
}

bool _hasLocation(BackendCardItem meeting) {
  return _stringOrNull(meeting.raw['place']) != null ||
      _stringOrNull(meeting.raw['address']) != null ||
      meeting.latitude != null ||
      meeting.longitude != null;
}

String? _peopleCountLabel(Map<String, Object?> raw) {
  final going = _intOrNull(raw['going'] ?? raw['participantCount']);
  final capacity = _intOrNull(raw['capacity']);
  if (going == null && capacity == null) {
    return null;
  }
  if (going != null && capacity != null) {
    return '$going/$capacity';
  }
  if (going != null) {
    return '$going идут';
  }
  return 'до $capacity';
}

String? _ticketSubtitle(Map<String, Object?> raw) {
  final price = _intOrNull(raw['ticketPriceFrom']);
  final provider = _stringOrNull(raw['ticketProvider']);
  final parts = [
    if (price != null && price > 0) 'от $price ₽',
    if (provider != null) provider,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String? _bookingSubtitle(Map<String, Object?> raw) {
  final averageCheck = _intOrNull(raw['bookingAverageCheck']);
  final provider = _stringOrNull(raw['bookingProvider']);
  final parts = [
    if (averageCheck != null && averageCheck > 0) 'средний чек $averageCheck ₽',
    if (provider != null) provider,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

Map? _firstBookingPromo(Map<String, Object?> raw) {
  final promos = raw['bookingPromos'];
  if (promos is List && promos.isNotEmpty && promos.first is Map) {
    return promos.first as Map;
  }
  return null;
}

Future<void> _openAttachment(
  BuildContext context,
  _AttachmentDetail attachment,
) async {
  final url = attachment.actionUrl;
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${attachment.kindLabel} пока без ссылки')),
    );
    return;
  }
  await _openExternalUrl(context, url);
}

Future<void> _openRoutePointAction(
  BuildContext context,
  _RoutePointDetail point,
) async {
  final url = point.actionUrl;
  if (url != null) {
    await _openExternalUrl(context, url);
    return;
  }
  await showDateasyMapChoiceSheet(
    context,
    latitude: point.latitude,
    longitude: point.longitude,
    label: point.mapLabel,
    fallbackQuery: point.fallbackQuery,
  );
}

Future<void> _openExternalUrl(BuildContext context, String url) async {
  final parsed = Uri.tryParse(url);
  if (parsed == null || !parsed.hasScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть ссылку')),
    );
    return;
  }
  final opened = await launchUrl(parsed, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть ссылку')),
    );
  }
}

String _string(Object? value) => value?.toString() ?? '';

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _rawLower(Map<String, Object?> raw, String key) {
  return _stringOrNull(raw[key])?.toLowerCase();
}

String? _firstRawLower(Map<String, Object?> raw, List<String> keys) {
  for (final key in keys) {
    final value = _rawLower(raw, key);
    if (value != null) {
      return value;
    }
  }
  return null;
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleOrNull(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
