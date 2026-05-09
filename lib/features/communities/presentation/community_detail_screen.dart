import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/communities/domain/community.dart';
import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/features/communities/presentation/community_widgets.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _CommunityTab { overview, meetups, members }

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({
    required this.communityId,
    super.key,
  });

  final String communityId;

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  _CommunityTab _tab = _CommunityTab.overview;
  bool? _joinedOverride;

  @override
  void didUpdateWidget(covariant CommunityDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.communityId != widget.communityId) {
      _joinedOverride = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityAsync = ref.watch(communityProvider(widget.communityId));

    return communityAsync.when(
      loading: () => const BbV5Scaffold(
        child: Center(
          child: BbV5Card(
            padding: EdgeInsets.all(24),
            radius: 24,
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                color: BbV5Colors.ink,
                strokeWidth: 2.4,
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => const CommunityMissingState(),
      data: (community) {
        if (community == null) {
          return const CommunityMissingState();
        }
        final joined = _joinedOverride ?? community.joined;

        return BbV5Scaffold(
          child: BbV5Page(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Column(
              children: [
                _CommunityDetailHeader(community: community),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                    children: [
                      _CommunityHeroCard(
                        community: community,
                        joined: joined,
                        onToggleJoin: () => setState(() {
                          _joinedOverride = !joined;
                        }),
                        onOpenChat: () => context.pushRoute(
                          AppRoute.communityChat,
                          pathParameters: {'communityId': community.id},
                        ),
                      ),
                      const SizedBox(height: 20),
                      _CommunityTabs(
                        meetupCount: community.meetups.length,
                        selected: _tab,
                        onChanged: (value) {
                          setState(() {
                            _tab = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      switch (_tab) {
                        _CommunityTab.overview =>
                          _CommunityOverview(community: community),
                        _CommunityTab.meetups =>
                          _CommunityMeetups(community: community),
                        _CommunityTab.members =>
                          _CommunityMembers(community: community),
                      },
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommunityDetailHeader extends StatelessWidget {
  const _CommunityDetailHeader({
    required this.community,
  });

  final Community community;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: () async {
            final popped = await Navigator.of(context).maybePop();
            if (!popped && context.mounted) {
              context.goRoute(AppRoute.communities);
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BbV5Kicker('Клуб'),
              const SizedBox(height: 3),
              Text(
                community.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bbV5DisplayStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        BbV5IconButton(
          icon: LucideIcons.crown,
          onPressed: () => context.pushRoute(
            AppRoute.editCommunity,
            pathParameters: {'communityId': community.id},
          ),
        ),
        const SizedBox(width: 8),
        BbV5IconButton(
          icon: LucideIcons.share_2,
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: '/community/${community.id}'),
            );
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ссылка скопирована')),
            );
          },
        ),
      ],
    );
  }
}

class _CommunityHeroCard extends StatelessWidget {
  const _CommunityHeroCard({
    required this.community,
    required this.joined,
    required this.onToggleJoin,
    required this.onOpenChat,
  });

  final Community community;
  final bool joined;
  final VoidCallback onToggleJoin;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final private = community.privacy == CommunityPrivacy.private;
    final tone = _communityDetailTone(community);

    return BbV5Card(
      tint: tone,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommunityDetailAvatar(community: community, tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          community.name,
                          style: bbV5DisplayStyle(fontSize: 20, height: 1.25),
                        ),
                        if (private)
                          const _CommunityV5Badge(
                            icon: LucideIcons.lock,
                            label: 'ЗАКРЫТЫЙ',
                            tone: BbV5Colors.inkSoft,
                          ),
                        if (community.premiumOnly)
                          const _CommunityV5Badge(
                            icon: LucideIcons.crown,
                            label: '+',
                            tone: BbV5Colors.terra,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      community.mood,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkMute,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            community.description,
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkSoft,
              fontSize: 13,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CommunityDetailStat(
                  value: '${community.members}',
                  label: 'участников',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CommunityDetailStat(
                  value: '${community.online}',
                  label: 'онлайн',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CommunityDetailStat(
                  value: '${community.meetups.length}',
                  label: 'встреч',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BbV5PillButton(
                  label: joined ? 'Выйти' : 'Вступить',
                  icon: joined ? LucideIcons.log_out : LucideIcons.plus,
                  height: 48,
                  fontSize: 13,
                  expanded: true,
                  dark: !joined,
                  onPressed: private && !joined ? null : onToggleJoin,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BbV5PillButton(
                  label: 'Открыть чат',
                  icon: LucideIcons.message_circle,
                  height: 48,
                  fontSize: 13,
                  expanded: true,
                  dark: true,
                  onPressed: onOpenChat,
                ),
              ),
            ],
          ),
          if (private && !joined) ...[
            const SizedBox(height: 6),
            Text(
              'Вступление по заявке',
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.inkMute,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityDetailAvatar extends StatelessWidget {
  const _CommunityDetailAvatar({
    required this.community,
    required this.tone,
  });

  final Community community;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final avatar = community.avatar.trim();
    final useEmoji = avatar.isNotEmpty && avatar.length <= 4;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BbV5Colors.hair),
      ),
      alignment: Alignment.center,
      child: useEmoji
          ? Text(avatar, style: const TextStyle(fontSize: 30))
          : Text(
              _communityInitials(community.name),
              style: bbV5DisplayStyle(fontSize: 18, color: tone),
            ),
    );
  }
}

class _CommunityV5Badge extends StatelessWidget {
  const _CommunityV5Badge({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tone),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: tone,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityDetailStat extends StatelessWidget {
  const _CommunityDetailStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

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
        children: [
          Text(
            value,
            style: bbV5DisplayStyle(fontSize: 18, height: 1).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _SocialPill extends StatelessWidget {
  const _SocialPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BbV5Colors.paper,
          border: Border.all(color: BbV5Colors.hair),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: BbV5Colors.inkSoft),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: BbV5Colors.inkMute,
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.meta.copyWith(
                color: BbV5Colors.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityTabs extends StatelessWidget {
  const _CommunityTabs({
    required this.meetupCount,
    required this.selected,
    required this.onChanged,
  });

  final int meetupCount;
  final _CommunityTab selected;
  final ValueChanged<_CommunityTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CommunityTabButton(
              label: 'Обзор',
              active: selected == _CommunityTab.overview,
              onTap: () => onChanged(_CommunityTab.overview),
            ),
          ),
          Expanded(
            child: _CommunityTabButton(
              label: 'Встречи · $meetupCount',
              active: selected == _CommunityTab.meetups,
              onTap: () => onChanged(_CommunityTab.meetups),
            ),
          ),
          Expanded(
            child: _CommunityTabButton(
              label: 'Участники',
              active: selected == _CommunityTab.members,
              onTap: () => onChanged(_CommunityTab.members),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityTabButton extends StatelessWidget {
  const _CommunityTabButton({
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
      color: active ? BbV5Colors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(BbV5Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            boxShadow: active ? BbV5Shadows.ink : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.itemTitle.copyWith(
              color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
              fontFamily: 'Sora',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityOverview extends StatelessWidget {
  const _CommunityOverview({
    required this.community,
  });

  final Community community;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BbV5Kicker('Новости'),
        if (community.isOwner) ...[
          const SizedBox(height: 8),
          BbV5PillButton(
            key: const Key('community-detail-publish-post-button'),
            label: 'Опубликовать',
            icon: LucideIcons.send,
            dark: true,
            expanded: true,
            height: 42,
            fontSize: 12,
            onPressed: () => context.pushRoute(
              AppRoute.createCommunityPost,
              pathParameters: {'communityId': community.id},
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final item in community.news) ...[
          BbV5Card(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTextStyles.body.copyWith(
                          color: BbV5Colors.ink,
                          fontFamily: 'Sora',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      item.time,
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.blurb,
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkSoft,
                    fontSize: 12,
                    height: 1.625,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const BbV5Kicker('Соцсети'),
        const SizedBox(height: 8),
        Row(
          children: [
            _SocialPill(
              icon: LucideIcons.send,
              label: _socialLabel(community, 0, fallback: 'Telegram'),
              value: _socialHandle(community, 0),
            ),
            const SizedBox(width: 8),
            _SocialPill(
              icon: LucideIcons.camera,
              label: _socialLabel(community, 1, fallback: 'Instagram'),
              value: _socialHandle(community, 1),
            ),
            const SizedBox(width: 8),
            _SocialPill(
              icon: LucideIcons.music_2,
              label: _socialLabel(community, 2, fallback: 'TikTok'),
              value: _socialHandle(community, 2),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommunityMembers extends StatelessWidget {
  const _CommunityMembers({
    required this.community,
  });

  final Community community;

  @override
  Widget build(BuildContext context) {
    final tone = _communityDetailTone(community);
    final names = community.memberNames.isEmpty
        ? const <String>['Участник клуба']
        : List<String>.generate(
            community.members > 30 ? 30 : community.memberNames.length * 2,
            (index) =>
                community.memberNames[index % community.memberNames.length],
          );

    return Column(
      children: [
        for (var i = 0; i < names.length; i++) ...[
          BbV5Card(
            radius: 18,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: BbV5Colors.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BbV5Colors.hair),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _memberInitials(names[i]),
                    style: bbV5DisplayStyle(
                      fontSize: 12,
                      color: tone,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[i],
                        style: AppTextStyles.meta.copyWith(
                          color: BbV5Colors.ink,
                          fontFamily: 'Sora',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        i % 3 == 0 ? 'онлайн' : 'был(а) недавно',
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: BbV5Colors.accent,
                      shape: BoxShape.circle,
                      boxShadow: BbV5Shadows.ink,
                    ),
                    child: Icon(
                      LucideIcons.message_circle,
                      size: 16,
                      color: BbV5Colors.paperHi,
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

class _CommunityMeetups extends StatelessWidget {
  const _CommunityMeetups({
    required this.community,
  });

  final Community community;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final meetup in community.meetups) ...[
          _CommunityMeetupCard(meetup: meetup),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CommunityMeetupCard extends StatelessWidget {
  const _CommunityMeetupCard({
    required this.meetup,
  });

  final CommunityMeetupItem meetup;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.pushRoute(
          AppRoute.eventDetail,
          pathParameters: {'eventId': meetup.id},
        ),
        child: BbV5Card(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: BbV5Colors.paper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BbV5Colors.hair),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      meetup.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meetup.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            color: BbV5Colors.ink,
                            fontFamily: 'Sora',
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${meetup.time} · ${meetup.place}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkMute,
                            fontSize: 11.5,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${meetup.format} · ${meetup.going} идут',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkSoft,
                            fontSize: 10.5,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BbV5PillButton(
                label: 'В чат встречи',
                icon: LucideIcons.message_circle,
                dark: true,
                expanded: true,
                height: 40,
                fontSize: 12,
                onPressed: () => context.pushRoute(
                  AppRoute.meetupChat,
                  pathParameters: {'chatId': meetup.id},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _communityDetailTone(Community community) {
  return switch (community.id.hashCode.abs() % 3) {
    0 => BbV5Colors.brand,
    1 => BbV5Colors.terra,
    _ => BbV5Colors.gold,
  };
}

String _socialHandle(Community community, int index) {
  if (community.socialLinks.length <= index) {
    return '@frendly';
  }
  return community.socialLinks[index].handle;
}

String _socialLabel(
  Community community,
  int index, {
  required String fallback,
}) {
  if (community.socialLinks.length <= index) {
    return fallback;
  }
  return community.socialLinks[index].label;
}

String _communityInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return 'CL';
  }
  return words.take(2).map((word) => word.substring(0, 1)).join().toUpperCase();
}

String _memberInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }
  return trimmed
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word.substring(0, 1))
      .join()
      .toUpperCase();
}
