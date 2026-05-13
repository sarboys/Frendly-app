// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/chats/presentation/chats_providers.dart';
import 'package:big_break_mobile/features/communities/domain/community.dart';
import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/features/tonight/presentation/v5_search_modal.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/personal_chat.dart';
import 'package:big_break_mobile/shared/widgets/bb_avatar.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_promo.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(chatSegmentProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final meetupChatsAsync = ref.watch(meetupChatsProvider);
    final personalChatsAsync = ref.watch(personalChatsProvider);
    final communitiesAsync = ref.watch(communitiesProvider);
    final knownPersonalChats = ref.watch(knownPersonalChatsProvider);
    final wallet = ref.watch(tokenWalletProvider);
    final promotedIds = wallet.promoted.keys
        .where((eventId) => wallet.isPromoted(eventId))
        .toSet();
    ref.watch(chatRealtimeSyncProvider);
    final meetupChats = meetupChatsAsync.valueOrNull ?? const [];
    final personalChats = mergeKnownPersonalChats(
      personalChatsAsync.valueOrNull ?? const [],
      knownPersonalChats.values,
    );
    final communityChats = (communitiesAsync.valueOrNull ?? const <Community>[])
        .where(_isJoinedCommunityChat)
        .toList(growable: false);
    final allChatListHasRows = meetupChats.isNotEmpty ||
        personalChats.isNotEmpty ||
        communityChats.isNotEmpty;
    final liveChats = meetupChats
        .where((chat) => chat.phase == MeetupPhase.live)
        .toList(growable: false);
    final soonChats = meetupChats
        .where((chat) => chat.phase == MeetupPhase.soon)
        .toList(growable: false);
    final upcomingChats = meetupChats
        .where((chat) => chat.phase == MeetupPhase.upcoming)
        .toList(growable: false);
    final doneChats = meetupChats
        .where((chat) => chat.phase == MeetupPhase.done)
        .toList(growable: false);
    final meetupEntries = _buildMeetupChatEntries(
      liveChats: liveChats,
      soonChats: soonChats,
      upcomingChats: upcomingChats,
      doneChats: doneChats,
    );
    final nowRadarItems = _buildNowRadarItems(
      meetupChats: meetupChats,
      personalChats: personalChats,
      communityChats: communityChats,
    );

    return BbV5Scaffold(
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 204),
                  children: [
                    InkWell(
                      onTap: () => showV5SearchModal(context),
                      borderRadius: BorderRadius.circular(BbV5Radii.pill),
                      child: const _V5SearchLauncher(),
                    ),
                    const SizedBox(height: 24),
                    _V5ActiveChatsRail(
                      meetupChats: meetupChats,
                      personalChats: personalChats,
                      promotedIds: promotedIds,
                      onMeetupTap: (chat) => _openMeetupChat(context, chat),
                      onPersonalTap: (chat) => context.pushRoute(
                        AppRoute.personalChat,
                        pathParameters: {'chatId': chat.id},
                      ),
                    ),
                    const SizedBox(height: 18),
                    _V5NowRadarCard(
                      items: nowRadarItems,
                      onTap: (item) => _openNowRadarItem(context, item),
                    ),
                    const SizedBox(height: 18),
                    _V5IcebreakersCard(
                      onVoiceTap: () => context.pushRoute(AppRoute.aiVoice),
                    ),
                    const SizedBox(height: 24),
                    _V5ChatSegments(
                      segment: segment,
                      onAll: () => ref
                          .read(chatSegmentProvider.notifier)
                          .state = ChatSegment.all,
                      onMeetups: () => ref
                          .read(chatSegmentProvider.notifier)
                          .state = ChatSegment.meetup,
                      onDating: () => ref
                          .read(chatSegmentProvider.notifier)
                          .state = ChatSegment.dating,
                      onPersonal: () => ref
                          .read(chatSegmentProvider.notifier)
                          .state = ChatSegment.personal,
                      onClubs: () => ref
                          .read(chatSegmentProvider.notifier)
                          .state = ChatSegment.clubs,
                    ),
                    const SizedBox(height: 14),
                    if (segment == ChatSegment.all)
                      _V5AllChatList(
                        meetupChats: meetupChats,
                        personalChats: personalChats,
                        communityChats: communityChats,
                        promotedIds: promotedIds,
                        loading: meetupChatsAsync.isLoading ||
                            personalChatsAsync.isLoading ||
                            (communitiesAsync.isLoading && !allChatListHasRows),
                        error: meetupChatsAsync.hasError ||
                            personalChatsAsync.hasError ||
                            (communitiesAsync.hasError && !allChatListHasRows),
                        onMeetupOpen: (chat) => _openMeetupChat(context, chat),
                        onMeetupPinToggle: (chat) {
                          unawaited(_toggleMeetupChatPinned(ref, chat));
                        },
                        onPersonalOpen: (chat) => context.pushRoute(
                          AppRoute.personalChat,
                          pathParameters: {'chatId': chat.id},
                        ),
                        onPersonalPinToggle: (chat) {
                          unawaited(_togglePersonalChatPinned(ref, chat));
                        },
                        onCommunityOpen: (community) => context.pushRoute(
                          AppRoute.communityChat,
                          pathParameters: {'communityId': community.id},
                        ),
                      )
                    else if (segment == ChatSegment.meetup)
                      meetupChatsAsync.when(
                        data: (_) => _V5MeetupChatList(
                          entries: meetupEntries,
                          currentUserId: currentUserId,
                          onOpen: (chat) => _openMeetupChat(context, chat),
                          onPinToggle: (chat) {
                            unawaited(_toggleMeetupChatPinned(ref, chat));
                          },
                          onLaunch: (chat) => _startEveningFromChatList(
                            context,
                            chat,
                          ),
                        ),
                        loading: () => const _V5ChatState(
                          text: 'Загружаем чаты встреч',
                          loading: true,
                        ),
                        error: (_, __) => const _V5ChatState(
                          text: 'Не получилось загрузить чаты встреч',
                        ),
                      )
                    else if (segment == ChatSegment.clubs)
                      communitiesAsync.when(
                        data: (_) => _V5CommunityChatList(
                          communities: communityChats,
                          onOpen: (community) => context.pushRoute(
                            AppRoute.communityChat,
                            pathParameters: {'communityId': community.id},
                          ),
                        ),
                        loading: () => const _V5ChatState(
                          text: 'Загружаем клубы',
                          loading: true,
                        ),
                        error: (_, __) => const _V5ChatState(
                          text: 'Не получилось загрузить клубы',
                        ),
                      )
                    else
                      personalChatsAsync.when(
                        data: (_) => _V5PersonalChatList(
                          chats: personalChats,
                          onOpen: (chat) => context.pushRoute(
                            AppRoute.personalChat,
                            pathParameters: {'chatId': chat.id},
                          ),
                          onPinToggle: (chat) {
                            unawaited(_togglePersonalChatPinned(ref, chat));
                          },
                        ),
                        loading: () => const _V5ChatState(
                          text: 'Загружаем личные чаты',
                          loading: true,
                        ),
                        error: (_, __) => const _V5ChatState(
                          text: 'Не получилось загрузить личные чаты',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 86,
            child: _V5AiCompassDock(
              onTap: () => context.pushRoute(AppRoute.aiVoice),
            ),
          ),
        ],
      ),
    );
  }
}

void _openNowRadarItem(BuildContext context, _V5NowRadarItem item) {
  final meetupChat = item.meetupChat;
  if (meetupChat != null) {
    _openMeetupChat(context, meetupChat);
    return;
  }

  final personalChat = item.personalChat;
  if (personalChat != null) {
    context.pushRoute(
      AppRoute.personalChat,
      pathParameters: {'chatId': personalChat.id},
    );
    return;
  }

  final community = item.community;
  if (community != null) {
    context.pushRoute(
      AppRoute.communityChat,
      pathParameters: {'communityId': community.id},
    );
  }
}

List<_V5NowRadarItem> _buildNowRadarItems({
  required List<MeetupChat> meetupChats,
  required List<PersonalChat> personalChats,
  required List<Community> communityChats,
}) {
  final meetupItems = meetupChats
      .where((chat) => chat.phase == MeetupPhase.live)
      .map(_V5NowRadarItem.meetup);
  final soonItems = meetupChats
      .where((chat) => chat.phase == MeetupPhase.soon)
      .map(_V5NowRadarItem.meetup);
  final onlineItems =
      personalChats.where((chat) => chat.online).map(_V5NowRadarItem.personal);
  final clubItems = communityChats
      .where((community) => community.online > 0)
      .map(_V5NowRadarItem.community);

  return [
    ...meetupItems,
    ...soonItems,
    ...onlineItems,
    ...clubItems,
  ].take(5).toList(growable: false);
}

class _V5NowRadarItem {
  const _V5NowRadarItem.meetup(MeetupChat chat)
      : meetupChat = chat,
        personalChat = null,
        community = null;

  const _V5NowRadarItem.personal(PersonalChat chat)
      : meetupChat = null,
        personalChat = chat,
        community = null;

  const _V5NowRadarItem.community(Community value)
      : meetupChat = null,
        personalChat = null,
        community = value;

  final MeetupChat? meetupChat;
  final PersonalChat? personalChat;
  final Community? community;

  String get title =>
      meetupChat?.title ?? personalChat?.name ?? community!.name;

  String get subtitle {
    final meetup = meetupChat;
    if (meetup != null) {
      final place = (meetup.currentPlace ?? meetup.area ?? '').trim();
      if (place.isNotEmpty) {
        return place;
      }
      return meetup.phase == MeetupPhase.live ? 'идет сейчас' : 'скоро старт';
    }

    final personal = personalChat;
    if (personal != null) {
      final source = personal.fromMeetup?.trim();
      return source == null || source.isEmpty ? 'онлайн' : source;
    }

    final online = community!.online;
    return online > 0 ? '$online онлайн' : 'клуб';
  }

  String get meta {
    final meetup = meetupChat;
    if (meetup != null) {
      final count = _meetupMembersCount(meetup);
      if (count != null) {
        return '$count чел.';
      }
      return meetup.lastTime;
    }

    final personal = personalChat;
    if (personal != null) {
      return personal.lastTime.isEmpty ? 'сейчас' : personal.lastTime;
    }

    final unread = community!.unread;
    return unread > 0 ? '$unread новых' : 'live';
  }

  Color get color {
    final meetup = meetupChat;
    if (meetup != null) {
      return meetup.phase == MeetupPhase.live
          ? BbV5Colors.terra
          : BbV5Colors.gold;
    }
    if (personalChat != null) {
      return BbV5Colors.rose;
    }
    return BbV5Colors.brand;
  }
}

Future<void> _toggleMeetupChatPinned(WidgetRef ref, MeetupChat chat) async {
  final previous = ref.read(meetupChatsProvider).valueOrNull;
  if (previous == null) {
    return;
  }

  final nextPinned = !chat.isPinned;
  ref.read(meetupChatsLocalStateProvider.notifier).state =
      sortMeetupChatsByPinned(
    previous
        .map(
          (item) =>
              item.id == chat.id ? item.copyWith(isPinned: nextPinned) : item,
        )
        .toList(growable: false),
  );

  try {
    await ref
        .read(backendRepositoryProvider)
        .setChatPinned(chat.id, isPinned: nextPinned);
    ref.invalidate(meetupChatsProvider);
  } catch (_) {
    ref.read(meetupChatsLocalStateProvider.notifier).state = previous;
  }
}

Future<void> _togglePersonalChatPinned(WidgetRef ref, PersonalChat chat) async {
  final previous = ref.read(personalChatsProvider).valueOrNull;
  if (previous == null) {
    return;
  }

  final nextPinned = !chat.isPinned;
  ref.read(personalChatsLocalStateProvider.notifier).state =
      sortPersonalChatsByPinned(
    previous
        .map(
          (item) =>
              item.id == chat.id ? item.copyWith(isPinned: nextPinned) : item,
        )
        .toList(growable: false),
  );

  try {
    await ref
        .read(backendRepositoryProvider)
        .setChatPinned(chat.id, isPinned: nextPinned);
    ref.invalidate(personalChatsProvider);
  } catch (_) {
    ref.read(personalChatsLocalStateProvider.notifier).state = previous;
  }
}

class _V5SearchLauncher extends StatelessWidget {
  const _V5SearchLauncher();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 16,
            color: BbV5Colors.inkMute,
          ),
          const SizedBox(width: 10),
          Text(
            'Поиск по чатам и людям',
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _V5NowRadarCard extends StatelessWidget {
  const _V5NowRadarCard({
    required this.items,
    required this.onTap,
  });

  final List<_V5NowRadarItem> items;
  final ValueChanged<_V5NowRadarItem> onTap;

  @override
  Widget build(BuildContext context) {
    final entries = items.isEmpty
        ? const [
            _V5NowRadarEntry(
              title: 'Тихий вечер',
              subtitle: 'чаты появятся после встреч',
              meta: '0 live',
              color: BbV5Colors.inkMute,
            ),
          ]
        : items
            .map(
              (item) => _V5NowRadarEntry(
                title: item.title,
                subtitle: item.subtitle,
                meta: item.meta,
                color: item.color,
                item: item,
              ),
            )
            .toList(growable: false);

    return BbV5Card(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      radius: 26,
      tint: BbV5Colors.terraSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: BbV5Kicker('Сейчас')),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: BbV5Colors.ink,
                  borderRadius: BorderRadius.circular(BbV5Radii.pill),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${items.length} live',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.paperHi,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 118,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              BbV5Colors.paperHi.withValues(alpha: 0.72),
                              BbV5Colors.paper.withValues(alpha: 0.42),
                            ],
                          ),
                          border: Border.all(color: BbV5Colors.hairSoft),
                        ),
                      ),
                    ),
                    for (final mark in _radarMarks(
                      entries,
                      constraints.maxWidth,
                    ))
                      Positioned(
                        left: mark.left,
                        top: mark.top,
                        child: _V5RadarPulse(
                          color: mark.entry.color,
                          active: mark.entry.item != null,
                        ),
                      ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BbV5Colors.paperHi.withValues(alpha: 0.78),
                            border: Border.all(color: BbV5Colors.hair),
                          ),
                          child: const Icon(
                            LucideIcons.radar,
                            size: 23,
                            color: BbV5Colors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _V5NowRadarChip(
                  entry: entry,
                  onTap: entry.item == null ? null : () => onTap(entry.item!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_V5RadarMark> _radarMarks(
    List<_V5NowRadarEntry> entries,
    double width,
  ) {
    const positions = [
      Offset(0.08, 18),
      Offset(0.7, 16),
      Offset(0.2, 74),
      Offset(0.86, 70),
      Offset(0.47, 40),
    ];
    final availableWidth = width > 24 ? width - 24 : width;
    return [
      for (var index = 0;
          index < entries.length && index < positions.length;
          index++)
        _V5RadarMark(
          entry: entries[index],
          left: availableWidth * positions[index].dx,
          top: positions[index].dy,
        ),
    ];
  }
}

class _V5NowRadarEntry {
  const _V5NowRadarEntry({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.color,
    this.item,
  });

  final String title;
  final String subtitle;
  final String meta;
  final Color color;
  final _V5NowRadarItem? item;
}

class _V5RadarMark {
  const _V5RadarMark({
    required this.entry,
    required this.left,
    required this.top,
  });

  final _V5NowRadarEntry entry;
  final double left;
  final double top;
}

class _V5RadarPulse extends StatelessWidget {
  const _V5RadarPulse({
    required this.color,
    required this.active,
  });

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 22 : 18,
      height: active ? 22 : 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: active ? 0.18 : 0.1),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Center(
        child: Container(
          width: active ? 8 : 6,
          height: active ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5NowRadarChip extends StatelessWidget {
  const _V5NowRadarChip({
    required this.entry,
    this.onTap,
  });

  final _V5NowRadarEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        children: [
          _PulseDot(color: entry.color, size: 8),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5DisplayStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.subtitle} · ${entry.meta}',
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
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }
}

class _V5IcebreakersCard extends StatelessWidget {
  const _V5IcebreakersCard({required this.onVoiceTap});

  final VoidCallback onVoiceTap;

  static const _prompts = [
    'Кто рядом на кофе?',
    'Куда после встречи?',
    'Позови двоих из чата',
    'Собери вечер без неловкости',
  ];

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(16),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: BbV5Kicker('Ледоколы')),
              const Icon(
                LucideIcons.sparkles,
                size: 15,
                color: BbV5Colors.terra,
              ),
              const SizedBox(width: 6),
              Text(
                'для первого сообщения',
                style: AppTextStyles.caption.copyWith(
                  color: BbV5Colors.inkMute,
                  fontSize: 10.5,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in _prompts)
                _V5IcebreakerChip(
                  text: prompt,
                  onTap: onVoiceTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _V5IcebreakerChip extends StatelessWidget {
  const _V5IcebreakerChip({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Text(
            text,
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _V5AiCompassDock extends StatelessWidget {
  const _V5AiCompassDock({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(BbV5Radii.pill),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: BbV5Colors.ink,
                    borderRadius: BorderRadius.circular(BbV5Radii.pill),
                    border: Border.all(
                      color: BbV5Colors.paperHi.withValues(alpha: 0.24),
                    ),
                    boxShadow: BbV5Shadows.ink,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: BbV5Colors.accent,
                          borderRadius: BorderRadius.circular(BbV5Radii.pill),
                        ),
                        child: const Icon(
                          LucideIcons.mic,
                          size: 18,
                          color: BbV5Colors.paperHi,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'AI compass',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bbV5DisplayStyle(
                                fontSize: 14,
                                color: BbV5Colors.paperHi,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'подскажет, что написать',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color:
                                    BbV5Colors.paperHi.withValues(alpha: 0.66),
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: BbV5Colors.paperHi.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(BbV5Radii.pill),
                        ),
                        child: const Icon(
                          LucideIcons.arrow_up_right,
                          size: 17,
                          color: BbV5Colors.paperHi,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _V5ActiveChatsRail extends StatelessWidget {
  const _V5ActiveChatsRail({
    required this.meetupChats,
    required this.personalChats,
    required this.promotedIds,
    required this.onMeetupTap,
    required this.onPersonalTap,
  });

  final List<MeetupChat> meetupChats;
  final List<PersonalChat> personalChats;
  final Set<String> promotedIds;
  final ValueChanged<MeetupChat> onMeetupTap;
  final ValueChanged<PersonalChat> onPersonalTap;

  @override
  Widget build(BuildContext context) {
    final activeMeetups = [
      ..._promotedFirstMeetupChats(
        meetupChats.where((chat) => chat.phase == MeetupPhase.live),
        promotedIds,
      ),
      ..._promotedFirstMeetupChats(
        meetupChats.where((chat) => chat.phase == MeetupPhase.soon),
        promotedIds,
      ),
      ..._promotedFirstMeetupChats(
        meetupChats.where((chat) => chat.phase == MeetupPhase.upcoming),
        promotedIds,
      ),
    ].take(5).toList(growable: false);
    final activePersonal =
        personalChats.where((chat) => chat.online).take(3).toList();

    if (activeMeetups.isEmpty && activePersonal.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Expanded(child: BbV5Kicker('Сейчас идут')),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _PulseDot(color: BbV5Colors.terra, size: 7),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: bbV5KickerStyle(
                      color: BbV5Colors.inkSoft,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: activeMeetups.length + activePersonal.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index < activeMeetups.length) {
                final chat = activeMeetups[index];
                return _V5ActiveBubble(
                  label: _shortLabel(chat.title),
                  initials: _initials(chat.title),
                  color: _toneColor(index),
                  promoted: _isPromotedMeetupChat(chat, promotedIds),
                  onTap: () => onMeetupTap(chat),
                );
              }
              final chat = activePersonal[index - activeMeetups.length];
              return _V5ActiveBubble(
                label: _shortLabel(chat.name),
                initials: _initials(chat.name),
                color: BbV5Colors.rose,
                promoted: false,
                onTap: () => onPersonalTap(chat),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _V5ActiveBubble extends StatelessWidget {
  const _V5ActiveBubble({
    required this.label,
    required this.initials,
    required this.color,
    required this.promoted,
    required this.onTap,
  });

  final String label;
  final String initials;
  final Color color;
  final bool promoted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Column(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _V5InitialsAvatar(
                    initials: initials,
                    color: promoted ? BbV5Colors.terra : color,
                    size: 56,
                    dot: true,
                    ringColor:
                        promoted ? BbV5Colors.accent : BbV5Colors.paperHi,
                  ),
                  if (promoted)
                    const Positioned(
                      right: -6,
                      top: -4,
                      child: _V5ActivePromotedBadge(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: BbV5Colors.inkSoft,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _V5ActivePromotedBadge extends StatelessWidget {
  const _V5ActivePromotedBadge();

  @override
  Widget build(BuildContext context) {
    return const BbV5PromoBadge(compact: true);
  }
}

class _V5ChatSegments extends StatelessWidget {
  const _V5ChatSegments({
    required this.segment,
    required this.onAll,
    required this.onMeetups,
    required this.onDating,
    required this.onPersonal,
    required this.onClubs,
  });

  final ChatSegment segment;
  final VoidCallback onAll;
  final VoidCallback onMeetups;
  final VoidCallback onDating;
  final VoidCallback onPersonal;
  final VoidCallback onClubs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _V5ChatSegmentChip(
              label: 'Все',
              active: segment == ChatSegment.all,
              onTap: onAll,
            ),
            const SizedBox(width: 6),
            _V5ChatSegmentChip(
              label: 'Клубы',
              active: segment == ChatSegment.clubs,
              onTap: onClubs,
            ),
            const SizedBox(width: 6),
            _V5ChatSegmentChip(
              label: 'Встречи',
              active: segment == ChatSegment.meetup,
              onTap: onMeetups,
            ),
            const SizedBox(width: 6),
            _V5ChatSegmentChip(
              label: 'Дейтинг',
              active: segment == ChatSegment.dating,
              onTap: onDating,
            ),
            const SizedBox(width: 6),
            _V5ChatSegmentChip(
              label: 'Личные',
              active: segment == ChatSegment.personal,
              onTap: onPersonal,
            ),
          ],
        ),
      ),
    );
  }
}

class _V5ChatSegmentChip extends StatelessWidget {
  const _V5ChatSegmentChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = active ? BbV5Colors.ink : BbV5Colors.paperHi;
    final foreground = active ? BbV5Colors.paperHi : BbV5Colors.inkSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.ink : BbV5Colors.hair,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x661F241D),
                      blurRadius: 16,
                      spreadRadius: -10,
                      offset: Offset(0, 8),
                    ),
                  ]
                : BbV5Shadows.pill,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 0,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _V5AllChatList extends StatelessWidget {
  const _V5AllChatList({
    required this.meetupChats,
    required this.personalChats,
    required this.communityChats,
    required this.promotedIds,
    required this.loading,
    required this.error,
    required this.onMeetupOpen,
    required this.onMeetupPinToggle,
    required this.onPersonalOpen,
    required this.onPersonalPinToggle,
    required this.onCommunityOpen,
  });

  final List<MeetupChat> meetupChats;
  final List<PersonalChat> personalChats;
  final List<Community> communityChats;
  final Set<String> promotedIds;
  final bool loading;
  final bool error;
  final ValueChanged<MeetupChat> onMeetupOpen;
  final ValueChanged<MeetupChat> onMeetupPinToggle;
  final ValueChanged<PersonalChat> onPersonalOpen;
  final ValueChanged<PersonalChat> onPersonalPinToggle;
  final ValueChanged<Community> onCommunityOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _V5ChatState(
        text: 'Загружаем чаты',
        loading: true,
      );
    }
    if (error) {
      return const _V5ChatState(text: 'Не получилось загрузить чаты');
    }

    if (meetupChats.isEmpty &&
        personalChats.isEmpty &&
        communityChats.isEmpty) {
      return const _V5ChatState(
        text: 'Пока нет чатов. Они появятся после встреч и мэтчей.',
      );
    }

    final entries = [
      for (var index = 0; index < meetupChats.length; index++)
        _V5AllChatEntry.meetup(meetupChats[index], index),
      for (var index = 0; index < personalChats.length; index++)
        _V5AllChatEntry.personal(
            personalChats[index], meetupChats.length + index),
      for (var index = 0; index < communityChats.length; index++)
        _V5AllChatEntry.community(
          communityChats[index],
          meetupChats.length + personalChats.length + index,
        ),
    ];
    entries.sort(_compareAllChatEntries);
    final visibleEntries = entries.take(9).toList(growable: false);

    return BbV5Card(
      radius: BbV5Radii.lg,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < visibleEntries.length; index++) ...[
            visibleEntries[index].buildRow(
              promotedIds: promotedIds,
              onMeetupOpen: onMeetupOpen,
              onMeetupPinToggle: onMeetupPinToggle,
              onPersonalOpen: onPersonalOpen,
              onPersonalPinToggle: onPersonalPinToggle,
              onCommunityOpen: onCommunityOpen,
            ),
            if (index < visibleEntries.length - 1) const _V5RowDivider(),
          ],
        ],
      ),
    );
  }
}

class _V5AllChatEntry {
  const _V5AllChatEntry.meetup(this.meetup, this.order)
      : personal = null,
        community = null;

  const _V5AllChatEntry.personal(this.personal, this.order)
      : meetup = null,
        community = null;

  const _V5AllChatEntry.community(this.community, this.order)
      : meetup = null,
        personal = null;

  final MeetupChat? meetup;
  final PersonalChat? personal;
  final Community? community;
  final int order;

  String get time =>
      meetup?.lastTime ?? personal?.lastTime ?? _communityLastTime(community);

  Widget buildRow({
    required Set<String> promotedIds,
    required ValueChanged<MeetupChat> onMeetupOpen,
    required ValueChanged<MeetupChat> onMeetupPinToggle,
    required ValueChanged<PersonalChat> onPersonalOpen,
    required ValueChanged<PersonalChat> onPersonalPinToggle,
    required ValueChanged<Community> onCommunityOpen,
  }) {
    final meetupChat = meetup;
    if (meetupChat != null) {
      final promoted = _isPromotedMeetupChat(meetupChat, promotedIds);
      return _V5ChatRow(
        item: _V5ChatRowItem(
          id: meetupChat.id,
          title: meetupChat.title,
          initials: _initials(meetupChat.title),
          color: _meetupToneColor(meetupChat),
          last: _meetupPreview(meetupChat),
          time: meetupChat.lastTime,
          unread: meetupChat.unread,
          pinned: meetupChat.isPinned,
          promoted: promoted,
          kind: _meetupKind(meetupChat),
          members: _meetupMembersCount(meetupChat),
          dot: meetupChat.phase == MeetupPhase.live || meetupChat.unread > 0,
        ),
        onTap: () => onMeetupOpen(meetupChat),
        onPinToggle: () => onMeetupPinToggle(meetupChat),
      );
    }

    final personalChat = personal;
    if (personalChat != null) {
      return _V5ChatRow(
        item: _V5ChatRowItem(
          id: personalChat.id,
          title: personalChat.name,
          initials: _initials(personalChat.name),
          color: personalChat.online ? BbV5Colors.brand : BbV5Colors.rose,
          last: personalChat.lastMessage,
          time: personalChat.lastTime,
          unread: personalChat.unread,
          pinned: personalChat.isPinned,
          kind: personalChat.fromMeetup == null ? 'дейтинг' : 'личные',
          dot: personalChat.online || personalChat.unread > 0,
        ),
        onTap: () => onPersonalOpen(personalChat),
        onPinToggle: () => onPersonalPinToggle(personalChat),
      );
    }

    final communityChat = community!;
    return _V5CommunityChatRow(
      community: communityChat,
      onTap: () => onCommunityOpen(communityChat),
    );
  }
}

int _compareAllChatEntries(_V5AllChatEntry left, _V5AllChatEntry right) {
  final leftPinned = left.meetup?.isPinned ?? left.personal?.isPinned ?? false;
  final rightPinned =
      right.meetup?.isPinned ?? right.personal?.isPinned ?? false;
  if (leftPinned != rightPinned) {
    return leftPinned ? -1 : 1;
  }

  final leftRank = _chatRecencyRank(left.time);
  final rightRank = _chatRecencyRank(right.time);
  if (leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }
  return left.order.compareTo(right.order);
}

int _chatRecencyRank(String label) {
  final value = label.trim().toLowerCase();
  if (value.isEmpty) {
    return 10000;
  }
  if (value.contains('сейчас')) {
    return 0;
  }
  final minutes = RegExp(r'(\d+)\s*мин').firstMatch(value);
  if (minutes != null) {
    return int.parse(minutes.group(1)!);
  }
  final hours = RegExp(r'(\d+)\s*ч').firstMatch(value);
  if (hours != null) {
    return int.parse(hours.group(1)!) * 60;
  }
  if (value.contains('позавчера')) {
    return 2880;
  }
  if (value.contains('вчера')) {
    return 1440;
  }
  return 5000;
}

Color _meetupToneColor(MeetupChat chat) {
  if (chat.phase == MeetupPhase.live) {
    return BbV5Colors.terra;
  }
  return _toneColor(chat.title.hashCode);
}

String _meetupPreview(MeetupChat chat) {
  final author = chat.lastAuthor.trim();
  final message = chat.lastMessage.trim();
  if (chat.typing) {
    return author.isEmpty ? 'печатает…' : '$author печатает…';
  }
  if (author.isEmpty) {
    return message;
  }
  if (message.isEmpty) {
    return author;
  }
  return '$author: $message';
}

String _meetupKind(MeetupChat chat) {
  if (chat.ticketSourceKind != null || (chat.ticketUrl ?? '').isNotEmpty) {
    return 'афиша';
  }
  if (chat.isCurated || chat.routeTemplateId != null || chat.routeId != null) {
    return 'маршрут';
  }
  return 'встреча';
}

int? _meetupMembersCount(MeetupChat chat) {
  final count = chat.joinedCount ??
      (chat.memberProfiles.isNotEmpty
          ? chat.memberProfiles.length
          : chat.members.length);
  return count > 0 ? count : null;
}

bool _isJoinedCommunityChat(Community community) {
  return community.chatId.trim().isNotEmpty &&
      (community.joined || community.isOwner);
}

CommunityChatPreview? _communityLastPreview(Community? community) {
  final previews = community?.chatPreview ?? const <CommunityChatPreview>[];
  if (previews.isEmpty) {
    return null;
  }
  return previews.last;
}

String _communityLastTime(Community? community) {
  return _communityLastPreview(community)?.time ?? '';
}

String _communityPreview(Community community) {
  final preview = _communityLastPreview(community);
  if (preview == null) {
    final description = community.description.trim();
    return description.isEmpty ? 'Чат клуба' : description;
  }

  final author = preview.author.trim();
  final text = preview.text.trim();
  if (author.isEmpty) {
    return text;
  }
  if (text.isEmpty) {
    return author;
  }
  return '$author: $text';
}

class _V5ChatRowItem {
  const _V5ChatRowItem({
    required this.id,
    required this.title,
    required this.initials,
    required this.color,
    required this.last,
    required this.time,
    required this.kind,
    this.unread = 0,
    this.pinned = false,
    this.promoted = false,
    this.members,
    this.dot = true,
  });

  final String id;
  final String title;
  final String initials;
  final Color color;
  final String last;
  final String time;
  final String kind;
  final int unread;
  final bool pinned;
  final bool promoted;
  final int? members;
  final bool dot;
}

class _V5ChatRow extends StatelessWidget {
  const _V5ChatRow({
    required this.item,
    this.onTap,
    this.onPinToggle,
  });

  final _V5ChatRowItem item;
  final VoidCallback? onTap;
  final VoidCallback? onPinToggle;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _V5InitialsAvatar(
                initials: item.initials,
                color: item.promoted ? BbV5PromoColors.gold : item.color,
                dot: item.dot,
                ringColor: item.promoted
                    ? BbV5PromoColors.goldSoft
                    : BbV5Colors.paperHi,
              ),
              if (item.promoted)
                const Positioned(
                  left: -4,
                  top: -7,
                  child: BbV5PromoBadge(compact: true),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bbV5DisplayStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onPinToggle != null)
                      _V5ChatPinButton(
                        key: Key('chat-pin-${item.id}'),
                        pinned: item.pinned,
                        onTap: onPinToggle!,
                      ),
                    if (onPinToggle != null) const SizedBox(width: 4),
                    Text(
                      item.time,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: item.unread > 0
                            ? BbV5Colors.ink
                            : BbV5Colors.inkMute,
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: item.unread > 0
                        ? BbV5Colors.inkSoft
                        : BbV5Colors.inkMute,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (item.promoted) ...[
                      const BbV5PromoBadge(compact: true, dark: false),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      item.kind,
                      style: AppTextStyles.caption.copyWith(
                        color: BbV5Colors.inkMute,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.62,
                      ),
                    ),
                    if (item.members != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 10,
                        color: BbV5Colors.hair,
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        LucideIcons.users,
                        size: 10,
                        color: BbV5Colors.inkMute,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${item.members}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: BbV5Colors.inkMute,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                    if (item.unread > 0) ...[
                      const Spacer(),
                      _V5MiniCounter(count: item.unread),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _V5RowDivider extends StatelessWidget {
  const _V5RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: BbV5Colors.hairSoft,
    );
  }
}

class _V5ChatPinButton extends StatelessWidget {
  const _V5ChatPinButton({
    required this.pinned,
    required this.onTap,
    super.key,
  });

  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: pinned ? 'Открепить чат' : 'Закрепить чат',
      child: SizedBox(
        width: 28,
        height: 28,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
          icon: Icon(
            pinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 15,
            color: pinned ? BbV5Colors.accent : BbV5Colors.inkMute,
          ),
        ),
      ),
    );
  }
}

class _V5MeetupChatList extends StatelessWidget {
  const _V5MeetupChatList({
    required this.entries,
    required this.currentUserId,
    required this.onOpen,
    required this.onPinToggle,
    required this.onLaunch,
  });

  final List<_MeetupChatEntry> entries;
  final String? currentUserId;
  final ValueChanged<MeetupChat> onOpen;
  final ValueChanged<MeetupChat> onPinToggle;
  final ValueChanged<MeetupChat> onLaunch;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _V5ChatState(
        text: 'Пока тихо. Создай встречу, чат появится сам.',
      );
    }

    return BbV5Card(
      radius: BbV5Radii.lg,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++)
            _buildEntry(context, entries[index], index),
        ],
      ),
    );
  }

  Widget _buildEntry(BuildContext context, _MeetupChatEntry entry, int index) {
    final sectionLabel = entry.sectionLabel;
    if (sectionLabel != null) {
      return _V5SectionLabel(sectionLabel);
    }

    final chat = entry.chat!;
    final canLaunch = entry.type == _MeetupChatEntryType.soon &&
        chat.routeId != null &&
        chat.sessionId != null &&
        chat.hostUserId == currentUserId;

    return _V5MeetupChatRow(
      chat: chat,
      type: entry.type,
      onTap: () => onOpen(chat),
      onPinToggle: () => onPinToggle(chat),
      onLaunch: canLaunch ? () => onLaunch(chat) : null,
    );
  }
}

class _V5PersonalChatList extends StatelessWidget {
  const _V5PersonalChatList({
    required this.chats,
    required this.onOpen,
    required this.onPinToggle,
  });

  final List<PersonalChat> chats;
  final ValueChanged<PersonalChat> onOpen;
  final ValueChanged<PersonalChat> onPinToggle;

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return const _V5ChatState(
        text: 'Личные чаты появляются после встреч.',
      );
    }
    return BbV5Card(
      radius: BbV5Radii.lg,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final chat in chats)
            _V5PersonalChatRow(
              chat: chat,
              onTap: () => onOpen(chat),
              onPinToggle: () => onPinToggle(chat),
            ),
        ],
      ),
    );
  }
}

class _V5CommunityChatList extends StatelessWidget {
  const _V5CommunityChatList({
    required this.communities,
    required this.onOpen,
  });

  final List<Community> communities;
  final ValueChanged<Community> onOpen;

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) {
      return const _V5ChatState(
        text: 'Клубные чаты появятся после вступления в клуб.',
      );
    }

    return BbV5Card(
      radius: BbV5Radii.lg,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < communities.length; index++) ...[
            _V5CommunityChatRow(
              community: communities[index],
              onTap: () => onOpen(communities[index]),
            ),
            if (index < communities.length - 1) const _V5RowDivider(),
          ],
        ],
      ),
    );
  }
}

class _V5MeetupChatRow extends StatelessWidget {
  const _V5MeetupChatRow({
    required this.chat,
    required this.type,
    required this.onTap,
    required this.onPinToggle,
    this.onLaunch,
  });

  final MeetupChat chat;
  final _MeetupChatEntryType type;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    final isLive = type == _MeetupChatEntryType.live;
    final isSoon = type == _MeetupChatEntryType.soon;
    final isDone = type == _MeetupChatEntryType.done;
    final preview = chat.typing
        ? '${chat.lastAuthor} печатает…'
        : '${chat.lastAuthor}: ${chat.lastMessage}';
    final titleColor = isDone ? BbV5Colors.inkSoft : BbV5Colors.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _V5InitialsAvatar(
                    initials: _initials(chat.title),
                    color: isLive
                        ? BbV5Colors.terra
                        : _toneColor(chat.title.hashCode),
                    dot: isLive || chat.unread > 0,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bbV5DisplayStyle(
                                  fontSize: 14,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _V5ChatPinButton(
                              key: Key('chat-pin-${chat.id}'),
                              pinned: chat.isPinned,
                              onTap: onPinToggle,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              chat.lastTime,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10.5,
                                color: chat.unread > 0
                                    ? BbV5Colors.ink
                                    : BbV5Colors.inkMute,
                                letterSpacing: 0,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isLive)
                              Text(
                                '● LIVE',
                                style: AppTextStyles.caption.copyWith(
                                  color: BbV5Colors.terra,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            if (isSoon)
                              Text(
                                '⏰ ${(chat.startsInLabel ?? 'Скоро').toUpperCase()}',
                                style: AppTextStyles.caption.copyWith(
                                  color: BbV5Colors.gold,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            if (chat.currentStep != null &&
                                chat.totalSteps != null)
                              Text(
                                'Шаг ${chat.currentStep} из ${chat.totalSteps}',
                                style: AppTextStyles.meta.copyWith(
                                  color: BbV5Colors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (_curatedChatLabel(chat) case final label?)
                              _V5TinyPill(label),
                          ],
                        ),
                        if (chat.currentPlace != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Сейчас: ${chat.currentPlace}${chat.endTime == null ? '' : ' · до ${chat.endTime}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.meta.copyWith(
                              color: BbV5Colors.inkSoft,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta.copyWith(
                                  color: chat.unread > 0
                                      ? BbV5Colors.inkSoft
                                      : BbV5Colors.inkMute,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            if (chat.unread > 0) ...[
                              const SizedBox(width: 8),
                              _V5MiniCounter(count: chat.unread),
                            ],
                          ],
                        ),
                        if (onLaunch != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: onLaunch,
                              icon: const Icon(LucideIcons.play, size: 14),
                              label: const Text('Поехали'),
                              style: FilledButton.styleFrom(
                                backgroundColor: BbV5Colors.accent,
                                foregroundColor: BbV5Colors.paperHi,
                                shape: const StadiumBorder(),
                                textStyle: AppTextStyles.button.copyWith(
                                  fontFamily: 'Sora',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5CommunityChatRow extends StatelessWidget {
  const _V5CommunityChatRow({
    required this.community,
    required this.onTap,
  });

  final Community community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _V5ChatRow(
      item: _V5ChatRowItem(
        id: community.chatId,
        title: community.name,
        initials: _initials(community.name),
        color: _toneColor(community.name.hashCode),
        last: _communityPreview(community),
        time: _communityLastTime(community),
        unread: community.unread,
        kind: 'клуб',
        members: community.members > 0 ? community.members : null,
        dot: community.unread > 0 || community.online > 0,
      ),
      onTap: onTap,
    );
  }
}

class _V5PersonalChatRow extends StatelessWidget {
  const _V5PersonalChatRow({
    required this.chat,
    required this.onTap,
    required this.onPinToggle,
  });

  final PersonalChat chat;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              _V5InitialsAvatar(
                initials: _initials(chat.name),
                color: chat.online ? BbV5Colors.brand : BbV5Colors.rose,
                dot: chat.online,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bbV5DisplayStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _V5ChatPinButton(
                          key: Key('chat-pin-${chat.id}'),
                          pinned: chat.isPinned,
                          onTap: onPinToggle,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          chat.lastTime,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            color: BbV5Colors.inkMute,
                            letterSpacing: 0,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.meta.copyWith(
                              color: chat.unread > 0
                                  ? BbV5Colors.inkSoft
                                  : BbV5Colors.inkMute,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (chat.unread > 0) ...[
                          const SizedBox(width: 8),
                          _V5MiniCounter(count: chat.unread),
                        ],
                      ],
                    ),
                    if (chat.fromMeetup != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'из встречи · ${chat.fromMeetup}',
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
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

class _V5InitialsAvatar extends StatelessWidget {
  const _V5InitialsAvatar({
    required this.initials,
    required this.color,
    this.size = 44,
    this.dot = false,
    this.ringColor = BbV5Colors.hair,
  });

  final String initials;
  final Color color;
  final double size;
  final bool dot;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi,
                shape: BoxShape.circle,
                border: Border.all(color: ringColor),
                boxShadow: BbV5Shadows.pill,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Sora',
                    fontSize: size > 50 ? 13 : 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: size > 50 ? 0.52 : 0.5,
                    color: BbV5Colors.ink,
                  ),
                ),
              ),
            ),
          ),
          if (dot)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.paperHi, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _V5MiniCounter extends StatelessWidget {
  const _V5MiniCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: BbV5Colors.accent,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: AppTextStyles.caption.copyWith(
          fontFamily: 'Sora',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: BbV5Colors.paperHi,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _V5TinyPill extends StatelessWidget {
  const _V5TinyPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: BbV5Colors.inkMute,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _V5SectionLabel extends StatelessWidget {
  const _V5SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: BbV5Colors.inkMute,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _V5ChatState extends StatelessWidget {
  const _V5ChatState({
    required this.text,
    this.loading = false,
  });

  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BbV5Colors.ink,
              ),
            )
          else
            const Icon(
              LucideIcons.message_circle,
              size: 24,
              color: BbV5Colors.inkMute,
            ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkMute,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _V5AiChatCard extends StatelessWidget {
  const _V5AiChatCard();

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BbV5Kicker('AI compass'),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Соберу чат\n'),
                TextSpan(
                  text: 'за тебя.',
                  style: bbV5DisplayStyle(
                    fontSize: 22,
                    color: BbV5Colors.terra,
                  ),
                ),
              ],
            ),
            style: bbV5DisplayStyle(fontSize: 22),
          ),
          const SizedBox(height: 12),
          Text(
            'Знакомства, предложения встреч, ответы — на автопилоте.',
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkSoft,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 20),
          BbV5PillButton(
            label: 'Включить',
            icon: LucideIcons.sparkles,
            dark: true,
            height: 44,
            fontSize: 13,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

String _initials(String value) {
  final words = value
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return 'FR';
  }
  final first = words.first.characters.first.toUpperCase();
  if (words.length == 1) {
    final chars = words.first.characters.take(2).toList();
    return chars.join().toUpperCase();
  }
  return '$first${words[1].characters.first.toUpperCase()}';
}

String _shortLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Чат';
  }
  final split = trimmed.split(RegExp(r'\s+|·'));
  return split.first.trim().isEmpty ? trimmed : split.first.trim();
}

List<MeetupChat> _promotedFirstMeetupChats(
  Iterable<MeetupChat> chats,
  Set<String> promotedIds,
) {
  final source = chats.toList(growable: false);
  if (promotedIds.isEmpty || source.isEmpty) {
    return source;
  }
  return [
    ...source.where((chat) => _isPromotedMeetupChat(chat, promotedIds)),
    ...source.where((chat) => !_isPromotedMeetupChat(chat, promotedIds)),
  ];
}

bool _isPromotedMeetupChat(MeetupChat chat, Set<String> promotedIds) {
  final eventId = chat.eventId;
  return promotedIds.contains(chat.id) ||
      (eventId != null && promotedIds.contains(eventId));
}

Color _toneColor(int seed) {
  const colors = [
    BbV5Colors.terra,
    BbV5Colors.brand,
    BbV5Colors.gold,
    BbV5Colors.rose,
    BbV5Colors.brandDeep,
  ];
  return colors[seed.abs() % colors.length];
}

List<_MeetupChatEntry> _buildMeetupChatEntries({
  required List<MeetupChat> liveChats,
  required List<MeetupChat> soonChats,
  required List<MeetupChat> upcomingChats,
  required List<MeetupChat> doneChats,
}) {
  return [
    for (final chat in liveChats)
      _MeetupChatEntry.chat(chat, _MeetupChatEntryType.live),
    if (soonChats.isNotEmpty) const _MeetupChatEntry.section('СКОРО'),
    for (final chat in soonChats)
      _MeetupChatEntry.chat(chat, _MeetupChatEntryType.soon),
    if (upcomingChats.isNotEmpty) const _MeetupChatEntry.section('ПРЕДСТОЯЩИЕ'),
    for (final chat in upcomingChats)
      _MeetupChatEntry.chat(chat, _MeetupChatEntryType.upcoming),
    if (doneChats.isNotEmpty) const _MeetupChatEntry.section('АРХИВ'),
    for (final chat in doneChats)
      _MeetupChatEntry.chat(chat, _MeetupChatEntryType.done),
  ];
}

enum _MeetupChatEntryType { section, live, soon, upcoming, done }

_MeetupChatEntryType _entryTypeForPhase(MeetupPhase phase) {
  return switch (phase) {
    MeetupPhase.live => _MeetupChatEntryType.live,
    MeetupPhase.soon => _MeetupChatEntryType.soon,
    MeetupPhase.upcoming => _MeetupChatEntryType.upcoming,
    MeetupPhase.done => _MeetupChatEntryType.done,
  };
}

class _MeetupChatEntry {
  const _MeetupChatEntry.section(this.sectionLabel)
      : chat = null,
        type = _MeetupChatEntryType.section;

  const _MeetupChatEntry.chat(this.chat, this.type) : sectionLabel = null;

  final MeetupChat? chat;
  final String? sectionLabel;
  final _MeetupChatEntryType type;
}

void _openMeetupChat(BuildContext context, MeetupChat chat) {
  context.pushRoute(
    AppRoute.meetupChat,
    pathParameters: {'chatId': chat.id},
  );
}

Future<void> _startEveningFromChatList(
  BuildContext context,
  MeetupChat chat,
) async {
  final routeId = chat.routeId;
  final sessionId = chat.sessionId;
  if (routeId == null || sessionId == null) {
    return;
  }

  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = container.read(backendRepositoryProvider);
    await repository.startEveningSession(sessionId);
    if (!context.mounted) {
      return;
    }
    container.invalidate(meetupChatsProvider);
    container.invalidate(eveningSessionsProvider);
    container.invalidate(eveningSessionProvider(sessionId));
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не получилось запустить live')),
    );
    return;
  }

  if (!context.mounted) {
    return;
  }
  context.pushRoute(
    AppRoute.eveningLive,
    pathParameters: {'routeId': routeId},
    queryParameters: {
      'sessionId': sessionId,
      'mode': chat.mode.name,
    },
  );
}

String? _curatedChatLabel(MeetupChat chat) {
  if (!chat.isCurated && chat.routeTemplateId == null) {
    return null;
  }
  final label = chat.badgeLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return 'Маршрут от команды Frendly';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: colors.inkMute,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = Curves.easeOut.transform(_controller.value);
          final pulseSize = widget.size + widget.size * 1.2 * progress;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                width: pulseSize,
                height: pulseSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(
                      alpha: (1 - progress) * 0.45,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
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

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.active,
    required this.label,
    required this.count,
    required this.showLiveDot,
    required this.onTap,
  });

  final bool active;
  final String label;
  final int count;
  final bool showLiveDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: active ? colors.background : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: active ? AppShadows.soft : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTextStyles.itemTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: active ? colors.foreground : colors.inkMute,
                ),
              ),
              if (showLiveDot) ...[
                const SizedBox(width: 6),
                _PulseDot(color: colors.destructive),
              ] else if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? colors.primary
                        : colors.inkMute.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: AppTextStyles.caption.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: active ? colors.primaryForeground : colors.inkSoft,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveChatTile extends StatelessWidget {
  const _LiveChatTile({
    required this.chat,
    required this.onTap,
  });

  final MeetupChat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final preview = chat.typing
        ? '${chat.lastAuthor} печатает…'
        : '${chat.lastAuthor}: ${chat.lastMessage}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Material(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(chat.emoji,
                              style: const TextStyle(fontSize: 28)),
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: _PulseDot(
                                color: colors.destructive,
                                size: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '● LIVE',
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.destructive,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                              if (chat.currentStep != null &&
                                  chat.totalSteps != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '· Шаг ${chat.currentStep} из ${chat.totalSteps}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.meta.copyWith(
                                      color: colors.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (_curatedChatLabel(chat) != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: _CuratedChatBadge(
                                    label: _curatedChatLabel(chat)!,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTextStyles.itemTitle.copyWith(fontSize: 15),
                          ),
                          if (chat.currentPlace != null) ...[
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Сейчас: '),
                                  TextSpan(
                                    text: chat.currentPlace!,
                                    style: AppTextStyles.meta.copyWith(
                                      color: colors.foreground,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (chat.endTime != null)
                                    TextSpan(text: ' · до ${chat.endTime}'),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(
                                color: colors.inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (chat.unread > 0) _UnreadBadge(count: chat.unread),
                        const SizedBox(height: 6),
                        Icon(
                          LucideIcons.chevron_right,
                          size: 18,
                          color: colors.inkMute,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: colors.primary.withValues(alpha: 0.15)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.meta.copyWith(
                          color:
                              chat.typing ? colors.secondary : colors.inkSoft,
                          fontWeight:
                              chat.typing ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      chat.lastTime,
                      style: AppTextStyles.caption.copyWith(
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
    );
  }
}

class _SoonChatTile extends StatelessWidget {
  const _SoonChatTile({
    required this.chat,
    required this.onTap,
    required this.onLaunch,
  });

  final MeetupChat chat;
  final VoidCallback onTap;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final startsInLabel = chat.startsInLabel ?? 'Скоро';
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.background.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child:
                        Text(chat.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⏰ $startsInLabel',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.secondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        if (_curatedChatLabel(chat) != null) ...[
                          const SizedBox(height: 3),
                          _CuratedChatBadge(label: _curatedChatLabel(chat)!),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.itemTitle.copyWith(fontSize: 15),
                        ),
                        Text(
                          '${chat.lastAuthor}: ${chat.lastMessage}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.meta
                              .copyWith(color: colors.inkMute),
                        ),
                      ],
                    ),
                  ),
                  if (chat.unread > 0) _UnreadBadge(count: chat.unread),
                ],
              ),
            ),
          ),
          if (onLaunch != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: onLaunch,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.foreground,
                  foregroundColor: colors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(LucideIcons.play, size: 14),
                label: Text(
                  'Поехали',
                  style: AppTextStyles.button.copyWith(
                    fontSize: 13,
                    color: colors.background,
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: AppTextStyles.caption.copyWith(
          color: colors.primaryForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CuratedChatBadge extends StatelessWidget {
  const _CuratedChatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PersonalChatTile extends StatelessWidget {
  const _PersonalChatTile({
    required this.name,
    required this.lastTime,
    required this.preview,
    required this.unread,
    required this.online,
    required this.onTap,
    this.fromMeetup,
  });

  final String name;
  final String lastTime;
  final String preview;
  final int unread;
  final bool online;
  final String? fromMeetup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              BbAvatar(name: name, size: BbAvatarSize.lg, online: online),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTextStyles.itemTitle.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          lastTime,
                          style: AppTextStyles.meta.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            style: AppTextStyles.meta.copyWith(
                              fontSize: 13,
                              color: unread > 0
                                  ? colors.foreground
                                  : colors.inkMute,
                              fontWeight: unread > 0
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            constraints: const BoxConstraints(
                                minWidth: 20, minHeight: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$unread',
                              style: AppTextStyles.caption
                                  .copyWith(color: colors.primaryForeground),
                            ),
                          ),
                      ],
                    ),
                    if (fromMeetup != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'из встречи · $fromMeetup',
                        style: AppTextStyles.meta.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: colors.inkMute,
                        ),
                      ),
                    ],
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.borderColor,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                borderColor == null ? null : Border.all(color: borderColor!),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }
}
