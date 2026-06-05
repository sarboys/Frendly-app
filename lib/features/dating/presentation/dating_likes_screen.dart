import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_refresh_indicator.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class DatingLikesScreen extends ConsumerWidget {
  const DatingLikesScreen({this.initialCount, super.key});

  final int? initialCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final subscription = subscriptionState.valueOrNull;
    final hasPlus =
        subscription?.status == 'active' || subscription?.status == 'trial';

    if (subscriptionState.isLoading && subscription == null) {
      return DateasyPhoneFrame(
        child: _DatingLikesScaffold(
          count: 0,
          onRefresh: () => _refreshDatingLikes(ref),
          bodySlivers: const [
            _PaddedBodySliver(
              child: _LikesStateCard(message: 'Проверяем Frendly+'),
            ),
          ],
        ),
      );
    }

    if (!hasPlus) {
      final likes = ref.watch(datingLikesProvider);
      final profiles = likes.valueOrNull?.items
              .map(_LikeProfile.fromBackend)
              .toList(growable: false) ??
          const <_LikeProfile>[];
      final count = profiles.isNotEmpty ? profiles.length : (initialCount ?? 0);
      return DateasyPhoneFrame(
        child: _DatingLikesScaffold(
          count: count,
          onRefresh: () => _refreshDatingLikes(ref),
          bodySlivers: count == 0
              ? const [
                  _PaddedBodySliver(
                    child: _LikesStateCard(
                      message: 'Пока нет входящих лайков',
                    ),
                  ),
                ]
              : _lockedLikesSlivers(
                  count: count,
                  profiles: profiles,
                ),
        ),
      );
    }

    final likes = ref.watch(datingLikesProvider);
    final items = likes.valueOrNull?.items ?? const <BackendCardItem>[];
    final count = items.isNotEmpty ? items.length : (initialCount ?? 0);

    return DateasyPhoneFrame(
      child: _DatingLikesScaffold(
        count: count,
        onRefresh: () => _refreshDatingLikes(ref),
        bodySlivers: items.isNotEmpty
            ? _openLikesSlivers(
                profiles:
                    items.map(_LikeProfile.fromBackend).toList(growable: false),
              )
            : likes.when(
                loading: () => const [
                  _PaddedBodySliver(
                    child: _LikesStateCard(message: 'Загружаем лайки'),
                  ),
                ],
                error: (_, __) => const [
                  _PaddedBodySliver(
                    child:
                        _LikesStateCard(message: 'Не удалось загрузить лайки'),
                  ),
                ],
                data: (page) {
                  if (page.items.isEmpty) {
                    return const [
                      _PaddedBodySliver(
                        child: _LikesStateCard(
                            message: 'Пока нет входящих лайков'),
                      ),
                    ];
                  }
                  final profiles = page.items
                      .map(_LikeProfile.fromBackend)
                      .toList(growable: false);
                  return _openLikesSlivers(profiles: profiles);
                },
              ),
      ),
    );
  }

  Future<void> _refreshDatingLikes(WidgetRef ref) async {
    ref.invalidate(subscriptionProvider);
    ref.invalidate(datingLikesProvider);
  }
}

class _DatingLikesScaffold extends StatelessWidget {
  const _DatingLikesScaffold({
    required this.count,
    required this.bodySlivers,
    required this.onRefresh,
  });

  final int count;
  final List<Widget> bodySlivers;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DateasyRefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 12,
                  20,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LikesHeader(count: count),
                      const SizedBox(height: 20),
                      Text(
                        'Тебя лайкнули',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontSize: 28,
                                  height: 1.05,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        count > 0
                            ? '$count ${_likesWord(count)} за неделю'
                            : 'Новые лайки появятся здесь',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DateasyColors.muted,
                              fontSize: 13,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              ...bodySlivers,
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
        const DateasyBottomNav(),
      ],
    );
  }
}

class _LikesHeader extends StatelessWidget {
  const _LikesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => context.go('/dating'),
        ),
        const Spacer(),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: DateasyColors.glass,
            border: Border.all(color: DateasyColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.heart,
                size: 14,
                color: DateasyColors.lime,
              ),
              const SizedBox(width: 6),
              Text(
                count > 0 ? '$count ${_likesWord(count)}' : 'Лайки',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: DateasyColors.glass,
            border: Border.all(color: DateasyColors.border),
          ),
          child: Icon(icon, size: 20, color: DateasyColors.foreground),
        ),
      ),
    );
  }
}

class _PaddedBodySliver extends StatelessWidget {
  const _PaddedBodySliver({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

List<Widget> _lockedLikesSlivers({
  required int count,
  required List<_LikeProfile> profiles,
}) {
  final cardCount = count.clamp(1, 10).toInt();
  return [
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(child: _PlusUpsellBanner(count: count)),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 14)),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _LockedLikeCard(
            profile: index < profiles.length ? profiles[index] : null,
            onTap: () => context.push('/paywall'),
          ),
          childCount: cardCount,
        ),
      ),
    ),
  ];
}

class _PlusUpsellBanner extends StatelessWidget {
  const _PlusUpsellBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: dateasyPinkGradient,
        boxShadow: [
          BoxShadow(
            color: DateasyColors.pink.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DateasyColors.foreground,
            ),
            child: const Icon(
              LucideIcons.lock,
              size: 20,
              color: DateasyColors.backgroundDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0
                      ? 'Открыть $count ${_likesWord(count)}'
                      : 'Открыть лайки',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Frendly+ покажет фото и профили',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.foreground.withValues(alpha: 0.82),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: DateasyColors.foreground,
              ),
              child: Text(
                'Получить',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.backgroundDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedLikeCard extends StatelessWidget {
  const _LockedLikeCard({
    required this.profile,
    required this.onTap,
  });

  final _LikeProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Скрытый лайк',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DateasyRemoteImage(
                  imageUrl: profile?.imageUrl,
                  usage: DateasyImageUsage.card,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      DateasyColors.lilac.withValues(alpha: 0.36),
                      DateasyColors.backgroundDeep.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DateasyColors.backgroundDeep.withValues(alpha: 0.82),
                    border: Border.all(color: DateasyColors.border),
                  ),
                  child: const Icon(
                    LucideIcons.lock,
                    color: DateasyColors.lime,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  'Скрыто',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
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

List<Widget> _openLikesSlivers({required List<_LikeProfile> profiles}) {
  return [
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _OpenLikeCard(profile: profiles[index]),
          childCount: profiles.length,
        ),
      ),
    ),
  ];
}

class _OpenLikeCard extends StatelessWidget {
  const _OpenLikeCard({required this.profile});

  final _LikeProfile profile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Профиль ${profile.name}',
      child: GestureDetector(
        onTap: () => context.push('/u/${profile.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DateasyRemoteImage(
                imageUrl: profile.imageUrl,
                usage: DateasyImageUsage.card,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD1F0C3F)],
                  ),
                ),
              ),
              if (profile.matchPercent != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: dateasyLimeGradient,
                    ),
                    child: Text(
                      '${profile.matchPercent}% мэтч',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.backgroundDeep,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.age == null
                          ? profile.name
                          : '${profile.name}, ${profile.age}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 11,
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

class _LikesStateCard extends StatelessWidget {
  const _LikesStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: DateasyColors.glass,
        border: Border.all(color: DateasyColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DateasyColors.muted,
            ),
      ),
    );
  }
}

class _LikeProfile {
  const _LikeProfile({
    required this.id,
    required this.name,
    required this.subtitle,
    this.age,
    this.imageUrl,
    this.matchPercent,
  });

  final String id;
  final String name;
  final String subtitle;
  final int? age;
  final String? imageUrl;
  final int? matchPercent;

  factory _LikeProfile.fromBackend(BackendCardItem item) {
    final raw = item.raw;
    final profile = _map(raw['profile']);
    return _LikeProfile(
      id: item.id,
      name: item.title.isEmpty ? 'Профиль' : item.title,
      age: _intOrNull(raw['age'] ?? profile['age']),
      imageUrl: item.imageUrl,
      matchPercent: _intOrNull(
        raw['matchPercent'] ??
            raw['match'] ??
            raw['matchScore'] ??
            raw['compatibility'] ??
            raw['compatibilityPercent'],
      ),
      subtitle: _stringOrNull(
            raw['job'] ??
                raw['profession'] ??
                raw['occupation'] ??
                raw['vibe'] ??
                profile['vibe'],
          ) ??
          item.city ??
          'Лайкнул(а) тебя',
    );
  }
}

String _likesWord(int count) {
  final abs = count.abs();
  final mod100 = abs % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return 'лайков';
  }
  return switch (abs % 10) {
    1 => 'лайк',
    2 || 3 || 4 => 'лайка',
    _ => 'лайков',
  };
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return const <String, Object?>{};
}

String? _stringOrNull(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
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
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
