import 'dart:async';

import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostersScreen extends ConsumerStatefulWidget {
  const PostersScreen({super.key});

  @override
  ConsumerState<PostersScreen> createState() => _PostersScreenState();
}

class _PostersScreenState extends ConsumerState<PostersScreen> {
  final _queryController = TextEditingController();
  Timer? _queryDebounce;
  PosterCategory? _category;
  String _debouncedQuery = '';

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String value) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final query = value.trim();
      if (_debouncedQuery == query) {
        return;
      }
      setState(() {
        _debouncedQuery = query;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _debouncedQuery;
    final featuredAsync = ref.watch(featuredPostersProvider);
    final filteredAsync = ref.watch(
      posterFeedProvider(
        PostersQuery(
          query: query,
          category: _category,
          featuredOnly: false,
        ),
      ),
    );
    final featured = featuredAsync.valueOrNull ?? const <Poster>[];
    final filtered = filteredAsync.valueOrNull ?? const <Poster>[];
    final visiblePosters = _postersForDisplay(
      filtered: filtered,
      featured: featured,
      category: _category,
      query: query,
    );

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _PostersHeader(
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: BbV5SearchPill(
                      controller: _queryController,
                      onChanged: _handleQueryChanged,
                      hintText: 'Концерт, выставка, стендап...',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 18),
                    child: SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          BbV5Chip(
                            label: 'Все',
                            active: _category == null,
                            onTap: () => setState(() => _category = null),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ...PosterCategory.values.map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.xs,
                              ),
                              child: BbV5Chip(
                                label: '${category.emoji} ${category.label}',
                                active: _category == category,
                                onTap: () =>
                                    setState(() => _category = category),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (featuredAsync.isLoading || filteredAsync.isLoading)
                  const _PostersStateSliver(
                    icon: LucideIcons.ticket,
                    title: 'Загружаем афишу',
                    message: 'Собираем события рядом.',
                    loading: true,
                  )
                else if (featuredAsync.hasError || filteredAsync.hasError)
                  const _PostersStateSliver(
                    icon: LucideIcons.wifi_off,
                    title: 'Не получилось загрузить афишу',
                    message: 'Проверь соединение и попробуй ещё раз.',
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: BbV5Kicker('${visiblePosters.length} событий'),
                    ),
                  ),
                  if (visiblePosters.isEmpty)
                    const _PostersStateSliver(
                      icon: LucideIcons.search_x,
                      title: 'Ничего не нашли',
                      message: 'Попробуй другой запрос или категорию.',
                    )
                  else
                    _PostersGrid(posters: visiblePosters),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 112)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Poster> _postersForDisplay({
    required List<Poster> filtered,
    required List<Poster> featured,
    required PosterCategory? category,
    required String query,
  }) {
    if (category != null || query.isNotEmpty || featured.isEmpty) {
      return filtered;
    }

    final byId = <String>{};
    return [
      for (final poster in featured)
        if (byId.add(poster.id)) poster,
      for (final poster in filtered)
        if (byId.add(poster.id)) poster,
    ];
  }
}

class _PostersHeader extends StatelessWidget {
  const _PostersHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BbV5IconButton(
          icon: LucideIcons.arrow_left,
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.xs),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BbV5Kicker('Афиша города'),
              SizedBox(height: 4),
              BbV5HeroTitle(
                title: 'Куда пойти',
                accent: 'сегодня',
                fontSize: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostersGrid extends StatelessWidget {
  const _PostersGrid({required this.posters});

  final List<Poster> posters;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final poster = posters[index];
            return _PosterGridCardV5(
              poster: poster,
              onTap: () => context.pushRoute(
                AppRoute.poster,
                pathParameters: {'posterId': poster.id},
              ),
            );
          },
          childCount: posters.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
      ),
    );
  }
}

class _PosterGridCardV5 extends StatelessWidget {
  const _PosterGridCardV5({
    required this.poster,
    required this.onTap,
  });

  final Poster poster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.md),
        child: Ink(
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.md),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BbV5Radii.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: _PosterGridStage(poster: poster),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 36,
                          child: Text(
                            poster.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontFamily: 'Sora',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              letterSpacing: 0,
                              color: BbV5Colors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.map_pin,
                              size: 11,
                              color: BbV5Colors.inkMute,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                poster.venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta.copyWith(
                                  fontSize: 10.5,
                                  color: BbV5Colors.inkMute,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Divider(height: 13, color: BbV5Colors.hairSoft),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                poster.priceFrom == 0
                                    ? 'free'
                                    : 'от ${poster.priceFrom}₽',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta.copyWith(
                                  fontFamily: 'Sora',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: BbV5Colors.terra,
                                ),
                              ),
                            ),
                            const Icon(
                              LucideIcons.ticket,
                              size: 14,
                              color: BbV5Colors.inkMute,
                            ),
                          ],
                        ),
                      ],
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

class _PosterGridStage extends StatelessWidget {
  const _PosterGridStage({required this.poster});

  final Poster poster;

  @override
  Widget build(BuildContext context) {
    final imageUrl = poster.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BbV5Colors.terraSoft, BbV5Colors.brandSoft],
        ),
      ),
      child: Stack(
        children: [
          if (hasImage)
            Positioned.fill(
              child: BbExternalEventImage(
                imageUrl: imageUrl,
                usage: BbExternalEventImageUsage.card,
              ),
            )
          else
            Center(
              child: Text(
                poster.emoji,
                style: TextStyle(
                  fontSize: 64,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: BbV5Colors.ink.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          if (hasImage)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.02),
                      Colors.black.withValues(alpha: 0.24),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(BbV5Radii.pill),
                border: Border.all(color: BbV5Colors.hair),
              ),
              child: Text(
                _dateBadgeLabel(poster),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: BbV5Colors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateBadgeLabel(Poster poster) {
    final value = poster.displayDateLabel.trim();
    if (value.isEmpty) {
      return poster.timeLabel;
    }
    final comma = value.indexOf(',');
    if (comma > 0 && value.length > comma + 1) {
      return value.substring(comma + 1).trim();
    }
    return value.length > 12 ? value.substring(0, 12) : value;
  }
}

class _PostersStateSliver extends StatelessWidget {
  const _PostersStateSliver({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Center(
          child: BbV5Card(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BbV5Colors.ink,
                    ),
                  )
                else
                  Icon(icon, size: 28, color: BbV5Colors.inkSoft),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: bbV5DisplayStyle(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkMute,
                    height: 1.35,
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
