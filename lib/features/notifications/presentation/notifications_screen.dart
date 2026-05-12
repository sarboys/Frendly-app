import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/notification_item.dart';
import 'package:big_break_mobile/shared/widgets/async_value_view.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _NotificationTab { all, invites, chats }

String? notificationDestinationLocation(NotificationItem item) {
  if (item.payload['source'] != 'dating') {
    return null;
  }
  if (item.payload['action'] != 'super_like') {
    return null;
  }

  final userId = item.payload['userId'];
  if (userId is! String || userId.trim().isEmpty) {
    return null;
  }

  return Uri(
    path: AppRoute.dating.path,
    queryParameters: {'profileId': userId.trim()},
  ).toString();
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _NotificationsView();
  }
}

class _NotificationsView extends ConsumerStatefulWidget {
  const _NotificationsView();

  @override
  ConsumerState<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<_NotificationsView> {
  var _tab = _NotificationTab.all;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final localItems = ref.watch(notificationsLocalStateProvider);

    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 80),
        child: Column(
          children: [
            BbV5TopBar(
              kicker: 'Активность',
              title: 'Твои',
              accent: 'уведомления',
              right: BbV5PillButton(
                label: 'Всё',
                icon: LucideIcons.check,
                height: 36,
                fontSize: 11.5,
                iconSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: _markAllRead,
              ),
            ),
            const SizedBox(height: 20),
            _Tabs(
              value: _tab,
              onChanged: (value) => setState(() {
                _tab = value;
              }),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: AsyncValueView(
                value: notificationsAsync,
                data: (items) {
                  final effectiveItems = localItems ?? items;
                  final now = DateTime.now();
                  final visible = effectiveItems
                      .where((item) => _matchesTab(item, _tab))
                      .toList(growable: false);
                  final today = visible
                      .where((item) => _isSameDay(item.createdAt, now))
                      .toList(growable: false);
                  final earlier = visible
                      .where((item) => !_isSameDay(item.createdAt, now))
                      .toList(growable: false);

                  if (visible.isEmpty) {
                    return const _EmptyState();
                  }

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (today.isNotEmpty)
                        _NotificationGroupCard(title: 'Сегодня', items: today),
                      if (earlier.isNotEmpty)
                        _NotificationGroupCard(title: 'Раньше', items: earlier),
                      const SizedBox(height: 20),
                      BbV5PillButton(
                        label: 'Настроить уведомления',
                        icon: LucideIcons.bell,
                        height: 48,
                        fontSize: 12,
                        expanded: true,
                        onPressed: () => context.pushRoute(AppRoute.settings),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime left, DateTime right) {
    final leftLocal = left.toLocal();
    final rightLocal = right.toLocal();
    return leftLocal.year == rightLocal.year &&
        leftLocal.month == rightLocal.month &&
        leftLocal.day == rightLocal.day;
  }

  bool _matchesTab(NotificationItem item, _NotificationTab tab) {
    return switch (tab) {
      _NotificationTab.all => true,
      _NotificationTab.invites => _isInvite(item) || item.kind == 'join',
      _NotificationTab.chats => item.kind == 'message',
    };
  }

  bool _isInvite(NotificationItem item) {
    return item.payload['invite'] == true ||
        item.kind == 'invite' ||
        item.kind == 'event_invite';
  }

  Future<void> _markAllRead() async {
    final repository = ref.read(backendRepositoryProvider);
    final refreshHandles = _notificationRefreshHandles();
    final currentItems = ref.read(notificationsLocalStateProvider) ??
        ref.read(notificationsProvider).valueOrNull;
    if (currentItems == null || currentItems.isEmpty) {
      return;
    }

    final readAt = DateTime.now();
    final nextItems = currentItems
        .map((item) => item.copyWith(readAt: item.readAt ?? readAt))
        .toList(growable: false);

    refreshHandles.localNotifications.state = nextItems;
    refreshHandles.unreadOverride.state = 0;

    try {
      await repository.markAllNotificationsRead();
      if (!mounted) {
        return;
      }
      _refreshNotificationsFromServer(refreshHandles);
    } catch (_) {
      if (!mounted) {
        return;
      }
      refreshHandles.localNotifications.state = currentItems;
      refreshHandles.unreadOverride.state =
          currentItems.where((item) => item.unread).length;
      rethrow;
    }
  }

  _NotificationRefreshHandles _notificationRefreshHandles() {
    return _NotificationRefreshHandles(
      container: ProviderScope.containerOf(context, listen: false),
      localNotifications: ref.read(notificationsLocalStateProvider.notifier),
      unreadOverride:
          ref.read(notificationUnreadCountOverrideProvider.notifier),
    );
  }

  void _refreshNotificationsFromServer(
    _NotificationRefreshHandles refreshHandles,
  ) {
    if (!mounted) {
      return;
    }
    refreshHandles.localNotifications.state = null;
    refreshHandles.unreadOverride.state = null;
    refreshHandles.container.invalidate(notificationsProvider);
    refreshHandles.container.invalidate(notificationUnreadCountProvider);
  }
}

class _NotificationRefreshHandles {
  const _NotificationRefreshHandles({
    required this.container,
    required this.localNotifications,
    required this.unreadOverride,
  });

  final ProviderContainer container;
  final StateController<List<NotificationItem>?> localNotifications;
  final StateController<int?> unreadOverride;
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.value,
    required this.onChanged,
  });

  final _NotificationTab value;
  final ValueChanged<_NotificationTab> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (_NotificationTab.all, 'Все'),
      (_NotificationTab.invites, 'Приглашения'),
      (_NotificationTab.chats, 'Чаты'),
    ];

    return BbV5Card(
      radius: BbV5Radii.pill,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _TabButton(
                  label: item.$2,
                  active: value == item.$1,
                  onTap: () => onChanged(item.$1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationGroupCard extends StatelessWidget {
  const _NotificationGroupCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<NotificationItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: BbV5Kicker(title),
          ),
          BbV5Card(
            radius: BbV5Radii.md,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _NotificationTile(item: items[index]),
                  if (index != items.length - 1)
                    const Divider(height: 1, color: BbV5Colors.hairSoft),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerStatefulWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  ConsumerState<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends ConsumerState<_NotificationTile> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final actorName = _actorName(item);
    final isInvite = _isInvite(item);
    final icon = _iconFor(item);
    final accent = _accentFor(item);

    return Material(
      color: item.unread
          ? BbV5Colors.accent.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (actorName != null)
                            TextSpan(
                              text: '$actorName ',
                              style: AppTextStyles.body.copyWith(
                                fontFamily: 'Sora',
                                fontSize: 13,
                                height: 1.28,
                                fontWeight: FontWeight.w600,
                                color: BbV5Colors.ink,
                              ),
                            ),
                          TextSpan(text: _notificationText(item, actorName)),
                        ],
                      ),
                      style: AppTextStyles.bodySoft.copyWith(
                        fontSize: 13,
                        height: 1.28,
                        color: BbV5Colors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatTime(item.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                    if (isInvite) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ActionPill(
                            label: 'Принять',
                            filled: true,
                            enabled: !_submitting,
                            onTap: _acceptInvite,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _ActionPill(
                            label: 'Отказаться',
                            enabled: !_submitting,
                            onTap: _declineInvite,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (item.unread)
                Container(
                  key: ValueKey('notification-unread-dot-${item.id}'),
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 8, left: 8),
                  decoration: const BoxDecoration(
                    color: BbV5Colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevron_right,
                size: 16,
                color: BbV5Colors.inkMute,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(NotificationItem item) {
    final kind = _isInvite(item) ? 'invite' : item.kind;
    return switch (kind) {
      'message' => LucideIcons.message_circle,
      'join' => LucideIcons.users,
      'invite' || 'event_invite' => LucideIcons.calendar,
      'event_starting' => LucideIcons.clock,
      'like' => LucideIcons.heart,
      'subscription_expiring' => LucideIcons.sparkles,
      _ => LucideIcons.bell,
    };
  }

  Color _accentFor(NotificationItem item) {
    final kind = _isInvite(item) ? 'invite' : item.kind;
    return switch (kind) {
      'message' => BbV5Colors.brandDeep,
      'join' => BbV5Colors.brand,
      'like' => BbV5Colors.rose,
      'subscription_expiring' => BbV5Colors.gold,
      _ => BbV5Colors.terra,
    };
  }

  Future<void> _open() async {
    final item = widget.item;
    if (item.unread) {
      await _markNotificationRead(item.id);
    }
    if (!mounted || !context.mounted) {
      return;
    }
    final destination = notificationDestinationLocation(item);
    if (item.payload['source'] == 'dating') {
      if (destination != null) {
        context.push(destination);
      }
      return;
    }
    final chatId = item.payload['chatId'] as String?;
    final eventId = item.payload['eventId'] as String?;
    final personId = (item.payload['userId'] ??
        item.payload['personId'] ??
        item.payload['targetUserId']) as String?;
    if (chatId != null) {
      context.pushRoute(
        AppRoute.meetupChat,
        pathParameters: {'chatId': chatId},
      );
    } else if (eventId != null) {
      context.pushRoute(
        AppRoute.eventDetail,
        pathParameters: {'eventId': eventId},
      );
    } else if (personId != null) {
      context.pushRoute(
        AppRoute.userProfile,
        pathParameters: {'userId': personId},
      );
    }
  }

  String? _actorName(NotificationItem item) {
    for (final key in const ['personName', 'userName', 'name']) {
      final value = item.payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    if (item.kind == 'message') {
      final separator = item.body.indexOf(':');
      if (separator > 0) {
        return item.body.substring(0, separator).trim();
      }
    }
    return null;
  }

  bool _isInvite(NotificationItem item) {
    return item.payload['invite'] == true ||
        item.kind == 'invite' ||
        item.kind == 'event_invite';
  }

  Future<void> _acceptInvite() async {
    final item = widget.item;
    final eventId = item.payload['eventId'] as String?;
    final requestId = item.payload['requestId'] as String?;

    if (_submitting || eventId == null || requestId == null) {
      return;
    }

    final repository = ref.read(backendRepositoryProvider);
    final refreshHandles = _notificationRefreshHandles();
    setState(() {
      _submitting = true;
    });

    try {
      await repository.acceptInvite(eventId, requestId);
      if (!mounted) {
        return;
      }
      _refreshNotificationsFromServer(refreshHandles);
      refreshHandles.container.invalidate(eventsProvider('nearby'));
      refreshHandles.container.invalidate(mapEventsProvider);
      refreshHandles.container.invalidate(eventDetailProvider(eventId));
      refreshHandles.container.invalidate(meetupChatsProvider);
      refreshHandles.container.invalidate(hostDashboardProvider);
      refreshHandles.container.invalidate(hostEventProvider(eventId));
      refreshHandles.container.invalidate(notificationUnreadCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Приглашение принято')),
      );
      context.pushRoute(
        AppRoute.eventDetail,
        pathParameters: {'eventId': eventId},
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось принять приглашение')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _declineInvite() async {
    final item = widget.item;
    final eventId = item.payload['eventId'] as String?;
    final requestId = item.payload['requestId'] as String?;

    if (_submitting || eventId == null || requestId == null) {
      return;
    }

    final repository = ref.read(backendRepositoryProvider);
    final refreshHandles = _notificationRefreshHandles();
    setState(() {
      _submitting = true;
    });

    try {
      await repository.declineInvite(eventId, requestId);
      if (!mounted) {
        return;
      }
      _refreshNotificationsFromServer(refreshHandles);
      refreshHandles.container.invalidate(eventDetailProvider(eventId));
      refreshHandles.container.invalidate(meetupChatsProvider);
      refreshHandles.container.invalidate(hostDashboardProvider);
      refreshHandles.container.invalidate(hostEventProvider(eventId));
      refreshHandles.container.invalidate(notificationUnreadCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Приглашение отклонено')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не получилось отклонить приглашение')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _markNotificationRead(String notificationId) async {
    final repository = ref.read(backendRepositoryProvider);
    final refreshHandles = _notificationRefreshHandles();
    final currentItems = ref.read(notificationsLocalStateProvider) ??
        ref.read(notificationsProvider).valueOrNull;
    if (currentItems == null) {
      refreshHandles.container.invalidate(notificationsProvider);
      return;
    }

    final readAt = DateTime.now();
    final nextItems = currentItems
        .map(
          (item) => item.id == notificationId
              ? item.copyWith(readAt: item.readAt ?? readAt)
              : item,
        )
        .toList(growable: false);

    refreshHandles.localNotifications.state = nextItems;
    refreshHandles.unreadOverride.state =
        nextItems.where((item) => item.unread).length;

    try {
      await repository.markNotificationRead(notificationId);
      if (!mounted) {
        return;
      }
      _refreshNotificationsFromServer(refreshHandles);
    } catch (_) {
      if (!mounted) {
        return;
      }
      refreshHandles.localNotifications.state = currentItems;
      refreshHandles.unreadOverride.state =
          currentItems.where((item) => item.unread).length;
      rethrow;
    }
  }

  _NotificationRefreshHandles _notificationRefreshHandles() {
    return _NotificationRefreshHandles(
      container: ProviderScope.containerOf(context, listen: false),
      localNotifications: ref.read(notificationsLocalStateProvider.notifier),
      unreadOverride:
          ref.read(notificationUnreadCountOverrideProvider.notifier),
    );
  }

  void _refreshNotificationsFromServer(
    _NotificationRefreshHandles refreshHandles,
  ) {
    if (!mounted) {
      return;
    }
    refreshHandles.localNotifications.state = null;
    refreshHandles.unreadOverride.state = null;
    refreshHandles.container.invalidate(notificationsProvider);
    refreshHandles.container.invalidate(notificationUnreadCountProvider);
  }

  String _notificationText(NotificationItem item, String? actorName) {
    final body = item.body.trim();
    if (actorName != null && body.startsWith('$actorName:')) {
      return body.substring(actorName.length + 1).trim();
    }
    if (body.isNotEmpty) {
      return body;
    }
    return item.title.trim();
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) {
      return 'сейчас';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ч';
    }
    if (diff.inDays == 1) {
      return 'вчера';
    }
    return '${diff.inDays} дня';
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(BbV5Radii.pill),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? BbV5Colors.accent : BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(BbV5Radii.pill),
              border: Border.all(
                color: filled ? BbV5Colors.accent : BbV5Colors.hair,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontFamily: 'Sora',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: filled ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BbV5Card(
        radius: BbV5Radii.md,
        padding: const EdgeInsets.all(20),
        child: Text(
          'Пока здесь тихо',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySoft.copyWith(color: BbV5Colors.inkMute),
        ),
      ),
    );
  }
}
