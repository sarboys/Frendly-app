import 'dart:async';

import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_social_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AnnouncementSeverity { info, warning, critical }

@immutable
class AnnouncementPayload {
  const AnnouncementPayload({
    required this.id,
    required this.severity,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.ctaUrl,
    this.force = false,
  });

  final String id;
  final AnnouncementSeverity severity;
  final String title;
  final String message;
  final String? ctaLabel;
  final String? ctaUrl;
  final bool force;
}

@immutable
class CityLimitToastPayload {
  const CityLimitToastPayload({
    required this.feature,
    required this.token,
  });

  final String feature;
  final int token;
}

final announcementProvider = StateProvider<AnnouncementPayload?>((ref) => null);

final cityLimitToastProvider = StateProvider<CityLimitToastPayload?>(
  (ref) => null,
);

void showCityLimitToast(WidgetRef ref, String feature) {
  ref.read(cityLimitToastProvider.notifier).state = CityLimitToastPayload(
    feature: feature,
    token: DateTime.now().microsecondsSinceEpoch,
  );
}

class BbSystemOverlays extends ConsumerWidget {
  const BbSystemOverlays({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcement = ref.watch(announcementProvider);
    final toast = ref.watch(cityLimitToastProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (announcement != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _AnnouncementBanner(
              data: announcement,
              onDismiss: () =>
                  ref.read(announcementProvider.notifier).state = null,
              onAction: () =>
                  ref.read(announcementProvider.notifier).state = null,
            ),
          ),
        _CityLimitToastLayer(
          payload: toast,
          onClose: () => ref.read(cityLimitToastProvider.notifier).state = null,
        ),
      ],
    );
  }
}

class _AnnouncementBanner extends StatelessWidget {
  const _AnnouncementBanner({
    required this.data,
    required this.onDismiss,
    this.onAction,
  });

  final AnnouncementPayload data;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = _announcementStyle(colors, data.severity);
    final label = switch (data.severity) {
      AnnouncementSeverity.critical => 'Обновление',
      AnnouncementSeverity.warning => 'Важно',
      AnnouncementSeverity.info => 'Объявление',
    };

    return IgnorePointer(
      ignoring: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: -1, end: 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(0, value * 96),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.7),
                ),
                boxShadow: AppShadows.card,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: style.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: style.iconBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(style.icon, size: 16, color: style.tone),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  label,
                                  style: AppTextStyles.caption.copyWith(
                                    color: style.tone,
                                    fontSize: 10,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'сейчас',
                                  style: AppTextStyles.caption.copyWith(
                                    color: colors.inkMute,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data.title,
                              style: AppTextStyles.itemTitle.copyWith(
                                color: colors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data.message,
                              style: AppTextStyles.meta.copyWith(
                                color: colors.inkSoft,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                            if (data.ctaLabel case final ctaLabel?) ...[
                              const SizedBox(height: AppSpacing.xs),
                              SizedBox(
                                height: 32,
                                child: FilledButton(
                                  onPressed: onAction,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.foreground,
                                    foregroundColor: colors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        ctaLabel,
                                        style: AppTextStyles.meta.copyWith(
                                          color: colors.background,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        LucideIcons.arrow_right,
                                        size: 14,
                                        color: colors.background,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!data.force)
                        IconButton(
                          onPressed: onDismiss,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          icon: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: colors.inkMute,
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
    );
  }

  ({
    Color accent,
    Color tone,
    Color iconBackground,
    IconData icon,
  }) _announcementStyle(
    BigBreakThemeColors colors,
    AnnouncementSeverity severity,
  ) {
    return switch (severity) {
      AnnouncementSeverity.info => (
          accent: colors.primary,
          tone: colors.primary,
          iconBackground: colors.primary.withValues(alpha: 0.12),
          icon: LucideIcons.megaphone,
        ),
      AnnouncementSeverity.warning => (
          accent: const Color(0xfff59e0b),
          tone: const Color(0xffd97706),
          iconBackground: const Color(0xfff59e0b).withValues(alpha: 0.12),
          icon: LucideIcons.triangle_alert,
        ),
      AnnouncementSeverity.critical => (
          accent: colors.destructive,
          tone: colors.destructive,
          iconBackground: colors.destructive.withValues(alpha: 0.12),
          icon: LucideIcons.download,
        ),
    };
  }
}

class _CityLimitToastLayer extends StatefulWidget {
  const _CityLimitToastLayer({
    required this.payload,
    required this.onClose,
  });

  final CityLimitToastPayload? payload;
  final VoidCallback onClose;

  @override
  State<_CityLimitToastLayer> createState() => _CityLimitToastLayerState();
}

class _CityLimitToastLayerState extends State<_CityLimitToastLayer> {
  Timer? _timer;
  int? _scheduledToken;

  @override
  void didUpdateWidget(covariant _CityLimitToastLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    final payload = widget.payload;
    if (payload == null) {
      _timer?.cancel();
      _timer = null;
      _scheduledToken = null;
      return;
    }

    if (_scheduledToken == payload.token) {
      return;
    }

    _timer?.cancel();
    _scheduledToken = payload.token;
    _timer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) {
        return;
      }
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;

    if (payload == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 96,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(payload.token),
        tween: Tween(begin: 24, end: 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: 1 - (value / 24),
          child: Transform.translate(offset: Offset(0, value), child: child),
        ),
        child: _CityLimitToast(
          feature: payload.feature,
          onClose: widget.onClose,
        ),
      ),
    );
  }
}

class _CityLimitToast extends StatelessWidget {
  const _CityLimitToast({
    required this.feature,
    required this.onClose,
  });

  final String feature;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: colors.foreground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.background.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.map_pin,
                      size: 16,
                      color: colors.background,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$feature — пока только в Москве и СПб',
                          style: AppTextStyles.itemTitle.copyWith(
                            color: colors.background,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Извините! Мы скоро расширимся в другие города.',
                          style: AppTextStyles.meta.copyWith(
                            color: colors.background.withValues(alpha: 0.8),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: colors.background,
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

Future<void> showChatMembersSheet(
  BuildContext context, {
  required String title,
  required List<String> members,
  List<MeetupMember> memberProfiles = const [],
  String? hostUserId,
  String? hostName,
  ValueChanged<MeetupMember>? onOpenProfile,
  ValueChanged<MeetupMember>? onMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    isScrollControlled: true,
    useSafeArea: false,
    builder: (context) => _ChatMembersSheet(
      title: title,
      members: members,
      memberProfiles: memberProfiles,
      hostUserId: hostUserId,
      hostName: hostName,
      onOpenProfile: onOpenProfile,
      onMessage: onMessage,
    ),
  );
}

class _ChatMembersSheet extends StatelessWidget {
  const _ChatMembersSheet({
    required this.title,
    required this.members,
    required this.memberProfiles,
    this.hostUserId,
    this.hostName,
    this.onOpenProfile,
    this.onMessage,
  });

  final String title;
  final List<String> members;
  final List<MeetupMember> memberProfiles;
  final String? hostUserId;
  final String? hostName;
  final ValueChanged<MeetupMember>? onOpenProfile;
  final ValueChanged<MeetupMember>? onMessage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sorted = _sortedMembers();

    return FractionallySizedBox(
      heightFactor: 0.85,
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.inkMute.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Участники',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sectionTitle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$title · ${sorted.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.meta.copyWith(
                              color: colors.inkMute,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.muted,
                        fixedSize: const Size(36, 36),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: colors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.search,
                        size: 18,
                        color: colors.inkMute,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Найти участника',
                            hintStyle: AppTextStyles.bodySoft.copyWith(
                              color: colors.inkMute,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: AppTextStyles.bodySoft.copyWith(
                            color: colors.foreground,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _InviteFriendsRow(colors: colors),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final member = sorted[index];
                    final isHost = _isHost(member);
                    return _MemberRow(
                      member: member,
                      isHost: isHost,
                      online: member.online ||
                          index == 0 ||
                          index == sorted.length - 1,
                      onOpenProfile: member.userId == null ||
                              member.isCurrentUser ||
                              onOpenProfile == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onOpenProfile?.call(member);
                            },
                      onMessage: member.userId == null ||
                              member.isCurrentUser ||
                              onMessage == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onMessage?.call(member);
                            },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.shield,
                        size: 13,
                        color: colors.inkMute,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Уважай других участников. Жалобы — в профиле.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: colors.inkMute,
                            fontSize: 11,
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
    );
  }

  List<MeetupMember> _sortedMembers() {
    final values = memberProfiles.isNotEmpty
        ? memberProfiles.toList(growable: false)
        : members.map(MeetupMember.fromName).toList(growable: false);
    values.sort((a, b) {
      if (_isHost(a)) return -1;
      if (_isHost(b)) return 1;
      if (a.isCurrentUser) return -1;
      if (b.isCurrentUser) return 1;
      return 0;
    });
    return values;
  }

  bool _isHost(MeetupMember member) {
    if (hostUserId != null && member.userId == hostUserId) {
      return true;
    }
    return hostName != null &&
        (member.name == hostName || member.displayName == hostName);
  }
}

class _InviteFriendsRow extends StatelessWidget {
  const _InviteFriendsRow({required this.colors});

  final BigBreakThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.user_plus,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Пригласить друзей',
                      style: AppTextStyles.itemTitle.copyWith(
                        color: colors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Поделиться ссылкой на встречу',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        fontSize: 12,
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isHost,
    required this.online,
    this.onOpenProfile,
    this.onMessage,
  });

  final MeetupMember member;
  final bool isHost;
  final bool online;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isYou = member.isCurrentUser;
    final actionKey = member.userId ?? member.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenProfile,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              BbAvatar(
                name: member.displayName,
                size: BbAvatarSize.lg,
                online: online,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isYou
                              ? '${member.displayName} · ты'
                              : member.displayName,
                          style: AppTextStyles.itemTitle.copyWith(
                            color: colors.foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.crown,
                                  size: 10,
                                  color: Color(0xFFC46A19),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Хост',
                                  style: AppTextStyles.caption.copyWith(
                                    color: const Color(0xFFC46A19),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHost
                          ? 'Организатор встречи'
                          : isYou
                              ? 'В сети'
                              : 'Участник',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        fontSize: 12,
                      ),
                    ),
                    if (member.userId != null && member.social.hasSignal) ...[
                      const SizedBox(height: 6),
                      BbSocialActions(
                        userId: member.userId!,
                        initialSocial: member.social,
                        variant: BbSocialActionsVariant.row,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isYou)
                IconButton(
                  key: Key('chat-member-message-${_actionKey(actionKey)}'),
                  tooltip: 'Написать',
                  onPressed: onMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.muted,
                    fixedSize: const Size(36, 36),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    LucideIcons.message_circle,
                    size: 16,
                    color: onMessage == null
                        ? colors.inkMute.withValues(alpha: 0.55)
                        : colors.inkSoft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _actionKey(String value) {
  final normalized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
  return normalized.isEmpty ? 'member' : normalized;
}
