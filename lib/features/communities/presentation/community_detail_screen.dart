import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/features/communities/application/community_access.dart';
import 'package:mobile2/features/communities/presentation/community_chat_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.communityId,
  });

  final String communityId;

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final _newsTitleController = TextEditingController();
  final _newsBodyController = TextEditingController();
  BackendCardItem? _overrideCommunity;
  bool _busy = false;
  bool _newsBusy = false;
  bool _showNewsComposer = false;
  var _tab = 0;
  String? _actionError;
  String? _newsError;

  @override
  void dispose() {
    _newsTitleController.dispose();
    _newsBodyController.dispose();
    super.dispose();
  }

  Future<void> _toggleJoin(BackendCardItem community) async {
    if (_busy) {
      return;
    }
    final joined = community.raw['joined'] as bool? ?? false;
    final privacy = _stringOrNull(community.raw['privacy']) ??
        _stringOrNull(community.raw['visibility']);
    final requestStatus = _stringOrNull(community.raw['joinRequestStatus']);
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final actions = ref.read(communityActionsProvider);
      final BackendCardItem next;
      if (requestStatus == 'pending') {
        next = await actions.cancelJoinRequest(communityId: community.id);
      } else if (!joined &&
          (privacy == 'private' ||
              privacy == 'closed' ||
              privacy == 'Закрытое')) {
        next = await actions.requestJoin(communityId: community.id);
      } else {
        next = await actions.setJoined(
          communityId: community.id,
          joined: !joined,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() => _overrideCommunity = next);
    } on BackendActionException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _actionError = error.code == 'community_owner_cannot_leave'
            ? 'Владелец не может выйти из своего сообщества'
            : 'Действие не удалось';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Действие не удалось');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createNews(BackendCardItem community) async {
    if (_newsBusy) {
      return;
    }
    final title = _newsTitleController.text.trim();
    final body = _newsBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _newsError = 'Добавь заголовок и текст');
      return;
    }
    setState(() {
      _newsBusy = true;
      _newsError = null;
    });
    try {
      final next = await ref.read(communityActionsProvider).createNews(
            communityId: community.id,
            title: title,
            body: body,
          );
      if (!mounted) {
        return;
      }
      _newsTitleController.clear();
      _newsBodyController.clear();
      setState(() {
        _overrideCommunity = next;
        _showNewsComposer = false;
      });
    } on BackendActionException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _newsError = error.code == 'community_owner_required'
            ? 'Новости может публиковать только владелец'
            : 'Не удалось опубликовать новость';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _newsError = 'Не удалось опубликовать новость');
      }
    } finally {
      if (mounted) {
        setState(() => _newsBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DateasyPhoneFrame(
      child: Builder(
        builder: (context) {
          final state = ref.watch(communityDetailProvider(widget.communityId));
          final community = _overrideCommunity ?? state.valueOrNull;

          if (state.isLoading && community == null) {
            return const _CommunityStatus(message: 'Загружаем сообщество');
          }
          if (community == null) {
            return _CommunityStatus(
              message: state.hasError
                  ? 'Не удалось загрузить сообщество'
                  : 'Сообщество не найдено',
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 56),
            children: [
              _HeroCover(
                community: community,
                onReportGap: () {
                  setState(() {
                    _actionError =
                        'Жалобу на сообщество можно отправить через профиль автора или поддержку.';
                  });
                },
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommunityHeader(
                      community: community,
                      onCreateMeeting: () => _openCommunityMeetingCreate(
                        context,
                        community.id,
                      ),
                    ),
                    _JoinAction(
                      community: community,
                      busy: _busy,
                      error: _actionError,
                      onTap: () => _toggleJoin(community),
                    ),
                    _CommunityTabs(
                      community: community,
                      selectedTab: _tab,
                      showNewsComposer: _showNewsComposer,
                      newsBusy: _newsBusy,
                      newsError: _newsError,
                      titleController: _newsTitleController,
                      bodyController: _newsBodyController,
                      onCreateMeeting: () => _openCommunityMeetingCreate(
                        context,
                        community.id,
                      ),
                      onToggleNewsComposer: () {
                        setState(
                          () => _showNewsComposer = !_showNewsComposer,
                        );
                      },
                      onTabChanged: (value) => setState(() => _tab = value),
                      onCreateNews: () => _createNews(community),
                    ),
                    const SizedBox(height: 56),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

void _openCommunityMeetingCreate(BuildContext context, String communityId) {
  context.go(
    '/meetings/new?communityId=${Uri.encodeComponent(communityId)}',
  );
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.community,
    required this.onReportGap,
  });

  final BackendCardItem community;
  final VoidCallback onReportGap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 224,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DateasyRemoteImage(
            imageUrl: community.imageUrl,
            usage: DateasyImageUsage.hero,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x4D1F0C3F),
                  DateasyColors.background,
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => context.go('/communities'),
                  child: const _GlassSquare(
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 21,
                      color: DateasyColors.foreground,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onReportGap,
                  child: const _GlassSquare(
                    child: Icon(
                      LucideIcons.flag,
                      size: 20,
                      color: DateasyColors.foreground,
                    ),
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

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.community,
    required this.onCreateMeeting,
  });

  final BackendCardItem community;
  final VoidCallback onCreateMeeting;

  @override
  Widget build(BuildContext context) {
    final privacy = _stringOrNull(community.raw['privacy']) ??
        _stringOrNull(community.raw['visibility']) ??
        'Доступ не указан';
    final members = _stringOrNull(community.raw['membersCount']) ??
        _stringOrNull(community.raw['memberCount']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: DateasyColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: DateasyColors.background,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: DateasyColors.lime.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: DateasyRemoteImage(
              imageUrl: community.imageUrl,
              usage: DateasyImageUsage.avatar,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                community.title.isEmpty ? 'Сообщество' : community.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      height: 1.12,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (_canManageCommunity(community)) const _HostBadge(),
              if (_canManageCommunity(community))
                _HeaderCreateMeetingButton(onTap: onCreateMeeting),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              const Icon(
                LucideIcons.lock,
                size: 14,
                color: DateasyColors.muted,
              ),
              Text(
                privacy,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.muted,
                      fontSize: 14,
                    ),
              ),
              if (members != null) ...[
                Text(
                  ',',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                      ),
                ),
                const Icon(
                  LucideIcons.users,
                  size: 14,
                  color: DateasyColors.muted,
                ),
                Text(
                  '$members участников',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                        fontSize: 14,
                      ),
                ),
              ],
            ],
          ),
          if (community.subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              community.subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _JoinAction extends StatelessWidget {
  const _JoinAction({
    required this.community,
    required this.busy,
    required this.error,
    required this.onTap,
  });

  final BackendCardItem community;
  final bool busy;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final joined = community.raw['joined'] as bool? ?? false;
    final canManage = _canManageCommunity(community);
    final requestStatus = _stringOrNull(community.raw['joinRequestStatus']);
    final label = canManage
        ? 'Админка'
        : requestStatus == 'pending'
            ? 'Заявка отправлена'
            : joined
                ? 'Выйти из сообщества'
                : 'Вступить';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: busy
                      ? null
                      : canManage
                          ? () =>
                              context.push('/communities/${community.id}/admin')
                          : onTap,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          canManage || (!joined && requestStatus != 'pending')
                              ? dateasyLimeGradient
                              : null,
                      color:
                          canManage || (!joined && requestStatus != 'pending')
                              ? null
                              : DateasyColors.glass,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          canManage || (!joined && requestStatus != 'pending')
                              ? null
                              : Border.all(color: DateasyColors.border),
                      boxShadow: canManage ||
                              (!joined && requestStatus != 'pending')
                          ? [
                              BoxShadow(
                                color:
                                    DateasyColors.lime.withValues(alpha: 0.24),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canManage
                              ? LucideIcons.shield
                              : joined
                                  ? LucideIcons.check
                                  : LucideIcons.plus,
                          size: 17,
                          color: canManage ||
                                  (!joined && requestStatus != 'pending')
                              ? DateasyColors.backgroundDeep
                              : DateasyColors.foreground,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          busy ? 'Синхронизируем' : label,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: canManage ||
                                        (!joined && requestStatus != 'pending')
                                    ? DateasyColors.backgroundDeep
                                    : DateasyColors.foreground,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CommunityActionSquare(
                icon: LucideIcons.messageCircle,
                active: joined || canManage,
                onTap: joined || canManage
                    ? () => context.push(communityChatRouteFor(community))
                    : null,
              ),
              const SizedBox(width: 8),
              _CommunityActionSquare(
                icon: LucideIcons.sparkles,
                active: true,
                onTap: () => context.go('/ai-builder'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            _InlineNotice(text: error!),
          ],
        ],
      ),
    );
  }
}

class _CommunityActionSquare extends StatelessWidget {
  const _CommunityActionSquare({
    required this.icon,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: DateasyColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DateasyColors.border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? DateasyColors.lime : DateasyColors.muted,
        ),
      ),
    );
  }
}

class _HostBadge extends StatelessWidget {
  const _HostBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: DateasyColors.lime,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.shield,
            size: 12,
            color: DateasyColors.backgroundDeep,
          ),
          const SizedBox(width: 4),
          Text(
            'Хост',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DateasyColors.backgroundDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCreateMeetingButton extends StatelessWidget {
  const _HeaderCreateMeetingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: DateasyColors.lime,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '+ Встреча',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.backgroundDeep,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _CommunityTabs extends StatelessWidget {
  const _CommunityTabs({
    required this.community,
    required this.selectedTab,
    required this.showNewsComposer,
    required this.newsBusy,
    required this.newsError,
    required this.titleController,
    required this.bodyController,
    required this.onCreateMeeting,
    required this.onToggleNewsComposer,
    required this.onTabChanged,
    required this.onCreateNews,
  });

  final BackendCardItem community;
  final int selectedTab;
  final bool showNewsComposer;
  final bool newsBusy;
  final String? newsError;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final VoidCallback onCreateMeeting;
  final VoidCallback onToggleNewsComposer;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onCreateNews;

  @override
  Widget build(BuildContext context) {
    final news = _list(community.raw['news']);
    final meetups = _list(community.raw['meetups']);
    final members = _memberNames(community.raw);
    final canManage = _canManageCommunity(community);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailTabBar(
            selected: selectedTab,
            onChanged: onTabChanged,
          ),
          const SizedBox(height: 18),
          if (selectedTab == 0) ...[
            if (canManage) ...[
              _NewsComposer(
                visible: showNewsComposer,
                busy: newsBusy,
                error: newsError,
                titleController: titleController,
                bodyController: bodyController,
                onToggle: onToggleNewsComposer,
                onSubmit: onCreateNews,
              ),
              const SizedBox(height: 12),
            ],
            _NewsFeedSection(news: news),
          ] else if (selectedTab == 1) ...[
            _MeetupsFeedSection(
              meetups: meetups,
              canManage: canManage,
              onCreateMeeting: onCreateMeeting,
            ),
          ] else if (selectedTab == 2) ...[
            _MembersFeedSection(members: members),
          ] else ...[
            _RulesFeedSection(community: community),
          ],
        ],
      ),
    );
  }
}

const _detailTabs = ['Лента', 'Встречи', 'Участники', 'Правила'];

class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _detailTabs.length; index++) ...[
            _DetailTabPill(
              label: _detailTabs[index],
              active: selected == index,
              onTap: () => onChanged(index),
            ),
            if (index != _detailTabs.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DetailTabPill extends StatelessWidget {
  const _DetailTabPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? DateasyColors.foreground : DateasyColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: DateasyColors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: active
                    ? DateasyColors.backgroundDeep
                    : DateasyColors.foreground,
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _NewsFeedSection extends StatelessWidget {
  const _NewsFeedSection({required this.news});

  final List<Map<String, Object?>> news;

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return const _InlineNotice(text: 'Новостей пока нет');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'Лента'),
        const SizedBox(height: 8),
        for (final item in news.take(8)) ...[
          _NewsFeedCard(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NewsFeedCard extends StatelessWidget {
  const _NewsFeedCard({required this.item});

  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final title = _stringOrNull(item['title']) ?? 'Новость';
    final body = _stringOrNull(item['body'] ?? item['blurb'] ?? item['text']);
    final when =
        _stringOrNull(item['when'] ?? item['time'] ?? item['timeLabel']);
    return _GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: DateasyColors.lime.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.megaphone,
                  size: 16,
                  color: DateasyColors.lime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (when != null)
                Text(
                  when,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                        fontSize: 10,
                      ),
                ),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 9),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                    fontSize: 14,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeetupsFeedSection extends StatelessWidget {
  const _MeetupsFeedSection({
    required this.meetups,
    required this.canManage,
    required this.onCreateMeeting,
  });

  final List<Map<String, Object?>> meetups;
  final bool canManage;
  final VoidCallback onCreateMeeting;

  @override
  Widget build(BuildContext context) {
    if (meetups.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canManage) ...[
            _CreateCommunityMeetingButton(onTap: onCreateMeeting),
            const SizedBox(height: 12),
          ],
          const _InlineNotice(text: 'Встреч пока нет'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canManage) ...[
          _CreateCommunityMeetingButton(onTap: onCreateMeeting),
          const SizedBox(height: 12),
        ],
        const _SectionLabel(text: 'Ближайшие встречи'),
        const SizedBox(height: 8),
        for (final item in meetups.take(8)) ...[
          _MeetupFeedCard(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CreateCommunityMeetingButton extends StatelessWidget {
  const _CreateCommunityMeetingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: dateasyLimeGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: DateasyColors.lime.withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: DateasyColors.background.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                LucideIcons.calendarPlus,
                color: DateasyColors.backgroundDeep,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Создать встречу сообщества',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DateasyColors.backgroundDeep,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.plus,
              color: DateasyColors.backgroundDeep,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetupFeedCard extends StatelessWidget {
  const _MeetupFeedCard({required this.item});

  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final id = _stringOrNull(item['id']);
    final title = _stringOrNull(item['title']) ?? 'Встреча';
    final when =
        _stringOrNull(item['time'] ?? item['timeLabel'] ?? item['when']);
    final place = _stringOrNull(item['place']);
    return GestureDetector(
      onTap: id == null ? null : () => context.push('/meetings/$id'),
      child: _GlassPanel(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: dateasyPinkGradient,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
              child: const Icon(
                LucideIcons.calendar,
                color: DateasyColors.foreground,
                size: 24,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (when != null) when,
                        if (place != null) place,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_intValue(item['going']) ?? 0} идут',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersFeedSection extends StatelessWidget {
  const _MembersFeedSection({required this.members});

  final List<String> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const _InlineNotice(text: 'Участники пока не показаны');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'Участники'),
        const SizedBox(height: 8),
        for (final member in members.take(12)) ...[
          _GlassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DateasyColors.lilac.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    color: DateasyColors.lilac,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    member,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RulesFeedSection extends StatelessWidget {
  const _RulesFeedSection({required this.community});

  final BackendCardItem community;

  @override
  Widget build(BuildContext context) {
    final rules = _stringOrNull(community.raw['rules']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'Правила'),
        const SizedBox(height: 8),
        _GlassPanel(
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          child: Text(
            rules ?? 'Правила пока не заполнены',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DateasyColors.muted,
                  height: 1.4,
                ),
          ),
        ),
        const SizedBox(height: 12),
        _CommunityMediaSection(communityId: community.id),
      ],
    );
  }
}

class _NewsComposer extends StatelessWidget {
  const _NewsComposer({
    required this.visible,
    required this.busy,
    required this.error,
    required this.titleController,
    required this.bodyController,
    required this.onToggle,
    required this.onSubmit,
  });

  final bool visible;
  final bool busy;
  final String? error;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final VoidCallback onToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Row(
              children: [
                const Icon(
                  LucideIcons.megaphone,
                  size: 16,
                  color: DateasyColors.lime,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Новость сообщества',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  visible ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: DateasyColors.muted,
                ),
              ],
            ),
          ),
          if (visible) ...[
            const SizedBox(height: 12),
            _ComposerField(
              controller: titleController,
              hint: 'Заголовок',
              maxLines: 1,
            ),
            const SizedBox(height: 10),
            _ComposerField(
              controller: bodyController,
              hint: 'Текст новости',
              maxLines: 3,
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.pink,
                      fontSize: 12,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: busy ? null : onSubmit,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: dateasyLimeGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  busy ? 'Публикуем' : 'Опубликовать',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.backgroundDeep,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerField extends StatelessWidget {
  const _ComposerField({
    required this.controller,
    required this.hint,
    required this.maxLines,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      cursorColor: DateasyColors.lime,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DateasyColors.foreground,
            fontSize: 14,
          ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DateasyColors.muted,
            ),
        filled: true,
        fillColor: DateasyColors.background.withValues(alpha: 0.44),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _CommunityMediaSection extends ConsumerWidget {
  const _CommunityMediaSection({required this.communityId});

  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityMediaProvider(communityId));
    final firstPage = state.valueOrNull;
    final pagination = ref.watch(communityMediaPaginationProvider(communityId));
    if (firstPage != null) {
      Future<void>.microtask(() {
        ref
            .read(communityMediaPaginationProvider(communityId).notifier)
            .primeNextCursor(firstPage.nextCursor);
      });
    }
    final items = [
      ...firstPage?.items ?? const <BackendCardItem>[],
      ...pagination.items,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'Медиа'),
        const SizedBox(height: 8),
        if (state.isLoading && items.isEmpty)
          const _InlineNotice(text: 'Загружаем медиа'),
        if (state.hasError && items.isEmpty)
          const _InlineNotice(text: 'Не удалось загрузить медиа'),
        if (!state.isLoading && !state.hasError && items.isEmpty)
          const _InlineNotice(text: 'Медиа пока нет'),
        for (final item in items) ...[
          _InfoRow(
            icon: LucideIcons.image,
            label: item.raw['kind']?.toString() ?? 'media',
            value: item.title.isEmpty ? item.id : item.title,
          ),
          const SizedBox(height: 10),
        ],
        if (pagination.error) ...[
          const _InlineNotice(text: 'Не удалось загрузить еще медиа'),
          const SizedBox(height: 10),
        ],
        if (pagination.hasNextPage || pagination.loading)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: pagination.loading
                  ? null
                  : () => ref
                      .read(
                        communityMediaPaginationProvider(communityId).notifier,
                      )
                      .loadNextPage(),
              child: Text(
                pagination.loading ? 'Загружаем' : 'Показать еще',
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: DateasyColors.lime),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.muted,
                      fontSize: 11,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DateasyColors.foreground,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.info, size: 18, color: DateasyColors.lime),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DateasyColors.muted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityStatus extends StatelessWidget {
  const _CommunityStatus({required this.message});

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

class _GlassSquare extends StatelessWidget {
  const _GlassSquare({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(width: 44, height: 44, child: child),
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
        border: Border.all(color: DateasyColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DateasyColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.1,
          ),
    );
  }
}

String? _stringOrNull(Object? value) {
  final result = value?.toString().trim();
  if (result == null || result.isEmpty) {
    return null;
  }
  return result;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}

bool _canManageCommunity(BackendCardItem community) {
  return canManageCommunityRaw(community.raw);
}

List<String> _memberNames(Map<String, Object?> raw) {
  final source = raw['memberNames'] ?? raw['members'];
  if (source is! List) {
    return const [];
  }
  return source
      .map((item) {
        if (item is String) {
          return item;
        }
        if (item is Map) {
          return item['name'] ??
              item['displayName'] ??
              item['title'] ??
              (item['user'] is Map
                  ? (item['user'] as Map)['displayName'] ??
                      (item['user'] as Map)['name']
                  : null);
        }
        return null;
      })
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

List<Map<String, Object?>> _list(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList(growable: false);
}
