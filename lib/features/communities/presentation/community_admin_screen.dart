import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/features/meetings/application/new_meeting_payload.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';

class CommunityAdminScreen extends ConsumerStatefulWidget {
  const CommunityAdminScreen({
    super.key,
    required this.communityId,
  });

  final String communityId;

  @override
  ConsumerState<CommunityAdminScreen> createState() =>
      _CommunityAdminScreenState();
}

class _CommunityAdminScreenState extends ConsumerState<CommunityAdminScreen> {
  final _newsTitleController = TextEditingController();
  final _newsBodyController = TextEditingController();
  final _nameController = TextEditingController();
  final _rulesController = TextEditingController();
  final _transferController = TextEditingController();
  final _meetupTitleController = TextEditingController();
  final _meetupDescriptionController = TextEditingController();
  final _meetupDateController = TextEditingController(
    text: _adminDateInput(_adminDefaultStart()),
  );
  final _meetupTimeController = TextEditingController(
    text: _adminTimeInput(_adminDefaultStart()),
  );
  final _meetupPlaceController = TextEditingController();
  final _meetupCapacityController = TextEditingController(text: '12');
  final _meetupIdempotency = NewMeetingCreateIdempotency();
  var _meetupVisibility = 'public';
  var _meetupComposerOpen = false;
  String? _meetupError;
  var _reloadKey = 0;
  var _busy = false;

  @override
  void dispose() {
    _newsTitleController.dispose();
    _newsBodyController.dispose();
    _nameController.dispose();
    _rulesController.dispose();
    _transferController.dispose();
    _meetupTitleController.dispose();
    _meetupDescriptionController.dispose();
    _meetupDateController.dispose();
    _meetupTimeController.dispose();
    _meetupPlaceController.dispose();
    _meetupCapacityController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _reloadKey += 1);
    ref.invalidate(communityDetailProvider(widget.communityId));
    ref.invalidate(communitiesProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      _reload();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyInviteLink() async {
    await Clipboard.setData(
      ClipboardData(text: 'https://frendly.app/c/${widget.communityId}'),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }

  void _openAdvancedCommunityMeetingCreate() {
    context.go(
      '/meetings/new?communityId=${Uri.encodeComponent(widget.communityId)}',
    );
  }

  Future<void> _publishInlineMeetup() async {
    if (_busy) {
      return;
    }

    final title = _meetupTitleController.text.trim();
    final description = _meetupDescriptionController.text.trim();
    final place = _meetupPlaceController.text.trim();
    final startsAt = _parseAdminStartsAt(
      _meetupDateController.text,
      _meetupTimeController.text,
    );
    final validation = validateNewMeetingDraft(
      title: title,
      description: description,
      place: place,
      startsAt: startsAt,
    );
    if (validation != NewMeetingDraftValidation.valid) {
      setState(() => _meetupError = validation.message);
      return;
    }

    final capacity = int.tryParse(_meetupCapacityController.text.trim()) ?? 12;
    if (capacity < 2 || capacity > 100) {
      setState(() => _meetupError = 'Лимит должен быть от 2 до 100');
      return;
    }

    setState(() {
      _busy = true;
      _meetupError = null;
    });
    try {
      final currentCity = ref.read(currentUserProvider)?.city?.trim();
      await ref.read(meetingActionsProvider).createEvent(
        idempotencyKey: _meetupIdempotency.currentKey(),
        data: {
          ...buildNewMeetingBasePayload(
            title: title,
            description: description,
            vibe: 'Сообщество',
            place: place,
            address: '',
            startsAt: startsAt!,
            capacity: capacity,
            gender: 'any',
            visibility: _meetupVisibility,
            city:
                currentCity == null || currentCity.isEmpty ? null : currentCity,
          ),
          ...buildNewMeetingSourcePayload(communityId: widget.communityId),
        },
      );
      if (!mounted) {
        return;
      }
      final nextStart = _adminDefaultStart();
      _meetupTitleController.clear();
      _meetupDescriptionController.clear();
      _meetupPlaceController.clear();
      _meetupCapacityController.text = '12';
      _meetupDateController.text = _adminDateInput(nextStart);
      _meetupTimeController.text = _adminTimeInput(nextStart);
      setState(() {
        _meetupVisibility = 'public';
        _meetupComposerOpen = false;
      });
      _reload();
    } on BackendActionException catch (error) {
      if (mounted) {
        setState(() => _meetupError = _adminMeetupError(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _meetupError = 'Не удалось создать встречу');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: DefaultTabController(
        length: 6,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top + 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/communities/${widget.communityId}');
                      }
                    },
                    child:
                        const _AdminIconButton(icon: LucideIcons.chevronLeft),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Админка',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DateasyColors.muted,
                                    fontSize: 10,
                                    letterSpacing: 1.1,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Сообщество',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  _AdminIconButton(
                    icon: LucideIcons.userPlus,
                    lime: true,
                    onTap: _copyInviteLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AdminTabs(
              communityId: widget.communityId,
              reloadKey: _reloadKey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(
                    key: ValueKey('overview-$_reloadKey'),
                    communityId: widget.communityId,
                    onCopyInviteLink: _copyInviteLink,
                  ),
                  _MeetupsTab(
                    key: ValueKey('meetups-$_reloadKey'),
                    communityId: widget.communityId,
                    busy: _busy,
                    titleController: _meetupTitleController,
                    descriptionController: _meetupDescriptionController,
                    dateController: _meetupDateController,
                    timeController: _meetupTimeController,
                    placeController: _meetupPlaceController,
                    capacityController: _meetupCapacityController,
                    visibility: _meetupVisibility,
                    composerOpen: _meetupComposerOpen,
                    error: _meetupError,
                    onToggleComposer: () => setState(
                      () => _meetupComposerOpen = !_meetupComposerOpen,
                    ),
                    onVisibilityChanged: (value) =>
                        setState(() => _meetupVisibility = value),
                    onCreate: _publishInlineMeetup,
                    onAdvanced: _openAdvancedCommunityMeetingCreate,
                    onCancel: (eventId) => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .cancelCommunityAdminMeetup(
                            communityId: widget.communityId,
                            eventId: eventId,
                          )
                          .then((_) {}),
                    ),
                  ),
                  _NewsTab(
                    key: ValueKey('news-$_reloadKey'),
                    communityId: widget.communityId,
                    titleController: _newsTitleController,
                    bodyController: _newsBodyController,
                    busy: _busy,
                    onCreate: () => _run(() async {
                      final title = _newsTitleController.text.trim();
                      final body = _newsBodyController.text.trim();
                      if (title.isEmpty || body.isEmpty) {
                        return;
                      }
                      await ref
                          .read(backendRepositoryProvider)
                          .createCommunityAdminNews(
                            communityId: widget.communityId,
                            title: title,
                            body: body,
                          );
                      _newsTitleController.clear();
                      _newsBodyController.clear();
                    }),
                    onTogglePinned: (newsId, pinned) => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .updateCommunityAdminNews(
                            communityId: widget.communityId,
                            newsId: newsId,
                            pinned: !pinned,
                          )
                          .then((_) {}),
                    ),
                    onDelete: (newsId) => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .deleteCommunityAdminNews(
                            communityId: widget.communityId,
                            newsId: newsId,
                          )
                          .then((_) {}),
                    ),
                  ),
                  _MembersTab(
                    key: ValueKey('members-$_reloadKey'),
                    communityId: widget.communityId,
                    busy: _busy,
                    onRole: (memberId, role) => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .updateCommunityAdminMemberRole(
                            communityId: widget.communityId,
                            memberId: memberId,
                            role: role,
                          )
                          .then((_) {}),
                    ),
                    onRemove: (memberId) => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .removeCommunityAdminMember(
                            communityId: widget.communityId,
                            memberId: memberId,
                          )
                          .then((_) {}),
                    ),
                  ),
                  _RequestsTab(
                    key: ValueKey('requests-$_reloadKey'),
                    communityId: widget.communityId,
                    busy: _busy,
                    onReview: (requestId, approve) => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .reviewCommunityAdminJoinRequest(
                            communityId: widget.communityId,
                            requestId: requestId,
                            approve: approve,
                          )
                          .then((_) {}),
                    ),
                  ),
                  _SettingsTab(
                    key: ValueKey('settings-$_reloadKey'),
                    communityId: widget.communityId,
                    nameController: _nameController,
                    rulesController: _rulesController,
                    transferController: _transferController,
                    busy: _busy,
                    onSave: () => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .updateCommunityAdminSettings(
                        communityId: widget.communityId,
                        data: {
                          'name': _nameController.text.trim(),
                          'rules': _rulesController.text.trim(),
                        },
                      ).then((_) {}),
                    ),
                    onArchive: () => _run(
                      () => ref
                          .read(backendRepositoryProvider)
                          .archiveCommunityAdmin(widget.communityId)
                          .then((_) {}),
                    ),
                    onTransfer: () => _run(() async {
                      final userId = _transferController.text.trim();
                      if (userId.isEmpty) {
                        return;
                      }
                      await ref
                          .read(backendRepositoryProvider)
                          .transferCommunityAdminOwner(
                            communityId: widget.communityId,
                            userId: userId,
                          );
                      _transferController.clear();
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    super.key,
    required this.communityId,
    required this.onCopyInviteLink,
  });

  final String communityId;
  final VoidCallback onCopyInviteLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminFuture<Map<String, Object?>>(
      future: ref.read(backendRepositoryProvider).fetchCommunityAdminOverview(
            communityId,
          ),
      builder: (context, data) {
        final stats = _map(data['stats']);
        final counters = stats.isEmpty ? _map(data['counters']) : stats;
        return _AdminList(
          children: [
            _KpiGrid(
              values: [
                _Kpi('Участники', _text(counters['members'])),
                _Kpi(
                  'Заявки',
                  _text(counters['requests'] ?? counters['pendingRequests']),
                ),
                _Kpi('Встречи', _text(counters['meetups'])),
                _Kpi('Посты', _text(counters['posts'] ?? counters['news'])),
              ],
            ),
            const SizedBox(height: 14),
            _QuickActionGrid(
              requests: _intFrom(
                counters['requests'] ?? counters['pendingRequests'],
              ),
              onCopyInviteLink: onCopyInviteLink,
            ),
          ],
        );
      },
    );
  }
}

class _AdminTabs extends ConsumerWidget {
  const _AdminTabs({
    required this.communityId,
    required this.reloadKey,
  });

  final String communityId;
  final int reloadKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, Object?>>>(
      key: ValueKey('request-badge-$reloadKey'),
      future:
          ref.read(backendRepositoryProvider).fetchCommunityAdminJoinRequests(
                communityId,
              ),
      builder: (context, snapshot) {
        final requestCount = snapshot.data?.length ?? 0;
        return TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          labelPadding: const EdgeInsets.only(right: 8),
          indicatorColor: Colors.transparent,
          dividerColor: Colors.transparent,
          tabs: [
            const _AdminTab(label: 'Обзор', icon: LucideIcons.crown),
            const _AdminTab(label: 'Встречи', icon: LucideIcons.calendar),
            const _AdminTab(label: 'Новости', icon: LucideIcons.megaphone),
            const _AdminTab(label: 'Участники', icon: LucideIcons.users),
            _AdminTab(
              label: 'Заявки',
              icon: LucideIcons.userPlus,
              badge: requestCount,
            ),
            const _AdminTab(label: 'Настройки', icon: LucideIcons.settings),
          ],
        );
      },
    );
  }
}

class _AdminTab extends StatelessWidget {
  const _AdminTab({
    required this.label,
    required this.icon,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 38,
      child: AnimatedBuilder(
        animation: DefaultTabController.of(context),
        builder: (context, _) {
          final controller = DefaultTabController.of(context);
          final index = _adminTabLabels.indexOf(label);
          final active = controller.index == index;
          return Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? DateasyColors.foreground : DateasyColors.glass,
              borderRadius: BorderRadius.circular(999),
              border: active ? null : Border.all(color: DateasyColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active
                      ? DateasyColors.backgroundDeep
                      : DateasyColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: active
                            ? DateasyColors.backgroundDeep
                            : DateasyColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: DateasyColors.pink,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badge',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.foreground,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

const _adminTabLabels = [
  'Обзор',
  'Встречи',
  'Новости',
  'Участники',
  'Заявки',
  'Настройки',
];

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.requests,
    required this.onCopyInviteLink,
  });

  final int requests;
  final VoidCallback onCopyInviteLink;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _QuickActionCard(
          icon: LucideIcons.calendar,
          title: 'Создать встречу',
          subtitle: 'для участников',
          color: DateasyColors.lime,
          onTap: () => DefaultTabController.of(context).animateTo(1),
        ),
        _QuickActionCard(
          icon: LucideIcons.megaphone,
          title: 'Новость',
          subtitle: 'в ленту',
          color: DateasyColors.pink,
          onTap: () => DefaultTabController.of(context).animateTo(2),
        ),
        _QuickActionCard(
          icon: LucideIcons.copy,
          title: 'Ссылка',
          subtitle: 'пригласить',
          color: DateasyColors.lilac,
          onTap: onCopyInviteLink,
        ),
        _QuickActionCard(
          icon: LucideIcons.userPlus,
          title: 'Заявки',
          subtitle: '$requests ждут',
          color: DateasyColors.lime,
          onTap: () => DefaultTabController.of(context).animateTo(4),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetupsTab extends ConsumerWidget {
  const _MeetupsTab({
    super.key,
    required this.communityId,
    required this.busy,
    required this.titleController,
    required this.descriptionController,
    required this.dateController,
    required this.timeController,
    required this.placeController,
    required this.capacityController,
    required this.visibility,
    required this.composerOpen,
    required this.error,
    required this.onToggleComposer,
    required this.onVisibilityChanged,
    required this.onCreate,
    required this.onAdvanced,
    required this.onCancel,
  });

  final String communityId;
  final bool busy;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController dateController;
  final TextEditingController timeController;
  final TextEditingController placeController;
  final TextEditingController capacityController;
  final String visibility;
  final bool composerOpen;
  final String? error;
  final VoidCallback onToggleComposer;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onCreate;
  final VoidCallback onAdvanced;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminFuture<List<Map<String, Object?>>>(
      future: ref.read(backendRepositoryProvider).fetchCommunityAdminMeetups(
            communityId,
          ),
      builder: (context, items) => _AdminList(
        children: [
          _PrimaryAdminButton(
            label: 'Создать встречу сообщества',
            icon: LucideIcons.calendarPlus,
            onTap: onToggleComposer,
          ),
          if (composerOpen) ...[
            const SizedBox(height: 12),
            _AdminMeetupComposer(
              titleController: titleController,
              descriptionController: descriptionController,
              dateController: dateController,
              timeController: timeController,
              placeController: placeController,
              capacityController: capacityController,
              visibility: visibility,
              busy: busy,
              error: error,
              onVisibilityChanged: onVisibilityChanged,
              onCreate: onCreate,
              onAdvanced: onAdvanced,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Встречи сообщества',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              _TinyAction(label: 'Расширенно', onTap: onAdvanced),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            _AdminRow(
              title: _text(item['title'] ?? item['name'], fallback: 'Встреча'),
              subtitle: _text(item['status'] ?? item['startsAt']),
              trailing: _TinyAction(
                label: busy ? '...' : 'Удалить',
                onTap: busy ? null : () => onCancel(_text(item['id'])),
              ),
            ),
          if (items.isEmpty) const _InlineState(text: 'Встреч пока нет'),
        ],
      ),
    );
  }
}

class _AdminMeetupComposer extends StatelessWidget {
  const _AdminMeetupComposer({
    required this.titleController,
    required this.descriptionController,
    required this.dateController,
    required this.timeController,
    required this.placeController,
    required this.capacityController,
    required this.visibility,
    required this.busy,
    required this.error,
    required this.onVisibilityChanged,
    required this.onCreate,
    required this.onAdvanced,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController dateController;
  final TextEditingController timeController;
  final TextEditingController placeController;
  final TextEditingController capacityController;
  final String visibility;
  final bool busy;
  final String? error;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onCreate;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdminInput(controller: titleController, hint: 'Название встречи'),
          const SizedBox(height: 10),
          _AdminInput(
            controller: descriptionController,
            hint: 'Описание',
            lines: 3,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdminInput(
                  controller: dateController,
                  hint: 'Дата YYYY-MM-DD',
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                child: _AdminInput(
                  controller: timeController,
                  hint: 'HH:mm',
                  keyboardType: TextInputType.datetime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AdminInput(controller: placeController, hint: 'Место'),
          const SizedBox(height: 10),
          _AdminInput(
            controller: capacityController,
            hint: 'Лимит участников',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AdminChoicePill(
                  label: 'Открытая',
                  active: visibility == 'public',
                  onTap: () => onVisibilityChanged('public'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AdminChoicePill(
                  label: 'По заявке',
                  active: visibility == 'private',
                  onTap: () => onVisibilityChanged('private'),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.pink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PrimaryAdminButton(
                  label: busy ? 'Публикуем' : 'Опубликовать',
                  icon: LucideIcons.send,
                  onTap: busy ? null : onCreate,
                ),
              ),
              const SizedBox(width: 10),
              _TinyAction(label: 'Расширенно', onTap: onAdvanced),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminChoicePill extends StatelessWidget {
  const _AdminChoicePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active ? dateasyLimeGradient : null,
          color: active ? null : DateasyColors.surface2,
          borderRadius: BorderRadius.circular(13),
          border: active ? null : Border.all(color: DateasyColors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: active
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _NewsTab extends ConsumerWidget {
  const _NewsTab({
    super.key,
    required this.communityId,
    required this.titleController,
    required this.bodyController,
    required this.busy,
    required this.onCreate,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final String communityId;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool busy;
  final VoidCallback onCreate;
  final void Function(String newsId, bool pinned) onTogglePinned;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminFuture<List<Map<String, Object?>>>(
      future: ref.read(backendRepositoryProvider).fetchCommunityAdminNews(
            communityId,
          ),
      builder: (context, items) => _AdminList(
        children: [
          _AdminCard(
            child: Column(
              children: [
                _AdminInput(controller: titleController, hint: 'Заголовок'),
                const SizedBox(height: 10),
                _AdminInput(
                    controller: bodyController, hint: 'Текст', lines: 3),
                const SizedBox(height: 12),
                _PrimaryAdminButton(
                  label: busy ? 'Публикуем' : 'Опубликовать',
                  icon: LucideIcons.send,
                  onTap: busy ? null : onCreate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            _AdminRow(
              title: _text(item['title'], fallback: 'Новость'),
              subtitle: _text(item['body']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TinyAction(
                    label: item['pinned'] == true ? 'Открепить' : 'Закрепить',
                    onTap: busy
                        ? null
                        : () => onTogglePinned(
                            _text(item['id']), item['pinned'] == true),
                  ),
                  const SizedBox(width: 8),
                  _TinyAction(
                    label: 'Удалить',
                    onTap: busy ? null : () => onDelete(_text(item['id'])),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({
    super.key,
    required this.communityId,
    required this.busy,
    required this.onRole,
    required this.onRemove,
  });

  final String communityId;
  final bool busy;
  final void Function(String memberId, String role) onRole;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminFuture<List<Map<String, Object?>>>(
      future: ref.read(backendRepositoryProvider).fetchCommunityAdminMembers(
            communityId,
          ),
      builder: (context, items) => _AdminList(
        children: [
          const _AdminCard(
            child: Text(
              'Ссылка приглашения будет добавлена после backend invite contract.',
              style: TextStyle(color: DateasyColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            _AdminRow(
              title: _text(_map(item['user'])['name'], fallback: 'Участник'),
              subtitle: _text(item['role']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TinyAction(
                    label: 'Модер',
                    onTap: busy
                        ? null
                        : () => onRole(_text(item['id']), 'moderator'),
                  ),
                  const SizedBox(width: 8),
                  _TinyAction(
                    label: 'Убрать',
                    onTap: busy ? null : () => onRemove(_text(item['id'])),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({
    super.key,
    required this.communityId,
    required this.busy,
    required this.onReview,
  });

  final String communityId;
  final bool busy;
  final void Function(String requestId, bool approve) onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminFuture<List<Map<String, Object?>>>(
      future:
          ref.read(backendRepositoryProvider).fetchCommunityAdminJoinRequests(
                communityId,
              ),
      builder: (context, items) => _AdminList(
        children: [
          for (final item in items)
            _AdminRow(
              title: _text(_map(item['user'])['name'], fallback: 'Заявка'),
              subtitle: _text(item['status']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TinyAction(
                    label: 'Принять',
                    onTap:
                        busy ? null : () => onReview(_text(item['id']), true),
                  ),
                  const SizedBox(width: 8),
                  _TinyAction(
                    label: 'Отклонить',
                    onTap:
                        busy ? null : () => onReview(_text(item['id']), false),
                  ),
                ],
              ),
            ),
          if (items.isEmpty) const _InlineState(text: 'Заявок нет'),
        ],
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({
    super.key,
    required this.communityId,
    required this.nameController,
    required this.rulesController,
    required this.transferController,
    required this.busy,
    required this.onSave,
    required this.onArchive,
    required this.onTransfer,
  });

  final String communityId;
  final TextEditingController nameController;
  final TextEditingController rulesController;
  final TextEditingController transferController;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onArchive;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityDetailProvider(communityId));
    final item = community.valueOrNull;
    nameController.text =
        nameController.text.isEmpty ? item?.title ?? '' : nameController.text;
    rulesController.text = rulesController.text.isEmpty
        ? _text(item?.raw['rules'])
        : rulesController.text;
    return _AdminList(
      children: [
        _AdminCard(
          child: Column(
            children: [
              _AdminInput(controller: nameController, hint: 'Название'),
              const SizedBox(height: 10),
              _AdminInput(
                  controller: rulesController, hint: 'Правила', lines: 4),
              const SizedBox(height: 12),
              _PrimaryAdminButton(
                label: busy ? 'Сохраняем' : 'Сохранить',
                icon: LucideIcons.save,
                onTap: busy ? null : onSave,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AdminCard(
          child: Column(
            children: [
              _AdminInput(
                controller: transferController,
                hint: 'ID нового владельца',
              ),
              const SizedBox(height: 12),
              _PrimaryAdminButton(
                label: 'Передать сообщество',
                icon: LucideIcons.userRoundCog,
                onTap: busy ? null : onTransfer,
              ),
              const SizedBox(height: 10),
              _TinyAction(
                label: 'Архивировать',
                onTap: busy ? null : onArchive,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.values});

  final List<_Kpi> values;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = values[index];
        return _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.muted,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;
}

class _AdminFuture<T> extends StatelessWidget {
  const _AdminFuture({
    required this.future,
    required this.builder,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: DateasyColors.lime),
          );
        }
        if (!snapshot.hasData) {
          return const _AdminList(
            children: [_InlineState(text: 'Данные недоступны')],
          );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

class _AdminList extends StatelessWidget {
  const _AdminList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: children,
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DateasyColors.border),
      ),
      child: child,
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _AdminCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _AdminInput extends StatelessWidget {
  const _AdminInput({
    required this.controller,
    required this.hint,
    this.lines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final int lines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: DateasyColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PrimaryAdminButton extends StatelessWidget {
  const _PrimaryAdminButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: onTap == null ? null : dateasyLimeGradient,
          color: onTap == null ? DateasyColors.surface2 : null,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: DateasyColors.backgroundDeep,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.backgroundDeep,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyAction extends StatelessWidget {
  const _TinyAction({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: onTap == null ? DateasyColors.muted : DateasyColors.lime,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _AdminIconButton extends StatelessWidget {
  const _AdminIconButton({
    required this.icon,
    this.lime = false,
    this.onTap,
  });

  final IconData icon;
  final bool lime;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: lime ? DateasyColors.lime : DateasyColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: lime ? null : Border.all(color: DateasyColors.border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: lime ? DateasyColors.backgroundDeep : DateasyColors.foreground,
        ),
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DateasyColors.muted,
            ),
      ),
    );
  }
}

DateTime _adminDefaultStart() {
  return DateTime.now().add(const Duration(hours: 3));
}

String _adminDateInput(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _adminTimeInput(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

DateTime? _parseAdminStartsAt(String date, String time) {
  final cleanDate = date.trim();
  final cleanTime = time.trim();
  if (cleanDate.isEmpty || cleanTime.isEmpty) {
    return null;
  }
  return DateTime.tryParse('${cleanDate}T$cleanTime:00');
}

String _adminMeetupError(BackendActionException error) {
  return switch (error.code) {
    'community_not_found' => 'Сообщество недоступно',
    'invalid_event_payload' => 'Проверь поля встречи',
    'event_entry_requirements_not_met' => 'Нет доступа к таким условиям',
    _ => 'Не удалось создать встречу',
  };
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map((key, value) => MapEntry('$key', value));
}

int _intFrom(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}
