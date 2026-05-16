import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/data/tomesto_promos_provider.dart';
import 'package:big_break_mobile/shared/utils/tomesto_promo_display.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class PerksScreen extends ConsumerStatefulWidget {
  const PerksScreen({super.key});

  @override
  ConsumerState<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends ConsumerState<PerksScreen> {
  final _opened = <String>{};
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final manualLocation = ref.watch(manualLocationProvider);
    final query = TomestoPromosQuery.fromManualLocation(manualLocation);
    final promosAsync = ref.watch(tomestoPromosProvider(query));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return BbV5Scaffold(
      child: BbV5Page(
        padding: EdgeInsets.zero,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              sliver: SliverToBoxAdapter(
                child: BbV5TopBar(
                  kicker: query.city,
                  title: 'Промо',
                  accent: 'Tomesto',
                  onBack: () => context.pop(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Акции заведений в выбранном городе. Категории берём из Tomesto мест.',
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkSoft,
                    height: 1.625,
                  ),
                ),
              ),
            ),
            ..._withPagePadding(
              promosAsync.when(
                loading: () => [
                  const SliverToBoxAdapter(child: _PromoLoadingCard()),
                ],
                error: (_, __) => [
                  SliverToBoxAdapter(
                    child: _PromoEmptyCard(
                      title: 'Не удалось загрузить промо.',
                      actionLabel: 'Повторить',
                      onAction: () =>
                          ref.invalidate(tomestoPromosProvider(query)),
                    ),
                  ),
                ],
                data: (promos) => _buildPromoSlivers(promos, query.city),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 120 + bottomInset),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _withPagePadding(List<Widget> slivers) {
    return [
      for (final sliver in slivers)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: sliver,
        ),
    ];
  }

  List<Widget> _buildPromoSlivers(
    List<BackendPlacePromoListItem> promos,
    String city,
  ) {
    final categories = _promoCategories(promos);
    if (_category != 'all' &&
        !categories.any((category) => category.key == _category)) {
      _category = 'all';
    }

    final visible = _category == 'all'
        ? promos
        : promos
            .where((promo) => _categoryForPromo(promo).key == _category)
            .toList(growable: false);

    return [
      SliverToBoxAdapter(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BbV5Chip(
              label: 'Все',
              active: _category == 'all',
              onTap: () => setState(() => _category = 'all'),
            ),
            for (final category in categories)
              BbV5Chip(
                label: category.label,
                active: _category == category.key,
                onTap: () => setState(() => _category = category.key),
              ),
          ],
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      if (promos.isEmpty)
        SliverToBoxAdapter(
          child: _PromoEmptyCard(
            title: 'Акций пока нет для $city.',
          ),
        )
      else if (_category == 'all')
        for (final category in categories)
          ..._categorySlivers(
            category,
            promos
                .where((promo) => _categoryForPromo(promo).key == category.key)
                .toList(growable: false),
          )
      else
        ..._categorySlivers(
          categories.firstWhere((category) => category.key == _category),
          visible,
        ),
    ];
  }

  List<Widget> _categorySlivers(
    _PromoCategory category,
    List<BackendPlacePromoListItem> promos,
  ) {
    if (promos.isEmpty) {
      return const [];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(category.icon, size: 14, color: category.color),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: bbV5KickerStyle(
                  color: BbV5Colors.inkMute,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) {
              return const SizedBox(height: AppSpacing.sm);
            }
            final promo = promos[index ~/ 2];
            return _PromoTicket(
              promo: promo,
              category: category,
              opened: _opened.contains(promo.id),
              onOpen: () async {
                setState(() {
                  _opened.add(promo.id);
                });
                await _openPromoUrl(context, promo);
              },
            );
          },
          childCount: promos.length * 2 - 1,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
    ];
  }

  Future<void> _openPromoUrl(
    BuildContext context,
    BackendPlacePromoListItem promo,
  ) async {
    final rawUrl =
        promo.placeBookingUrl ?? promo.bookingUrl ?? promo.sourceUrl ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У этой акции пока нет ссылки')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }
}

class _PromoLoadingCard extends StatelessWidget {
  const _PromoLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const BbV5Card(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(
          color: BbV5Colors.ink,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _PromoEmptyCard extends StatelessWidget {
  const _PromoEmptyCard({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(
              color: BbV5Colors.inkMute,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            BbV5PillButton(
              label: actionLabel!,
              icon: LucideIcons.refresh_cw,
              height: 38,
              fontSize: 12,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _PromoTicket extends StatelessWidget {
  const _PromoTicket({
    required this.promo,
    required this.category,
    required this.opened,
    required this.onOpen,
  });

  final BackendPlacePromoListItem promo;
  final _PromoCategory category;
  final bool opened;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final venue = tomestoVenueDisplayName(
      promoTitle: promo.title,
      placeName: promo.placeName,
      venueName: promo.venueName,
    );
    final title = cleanTomestoPromoTitle(promo.title);
    final meta = [
      if ((promo.address ?? '').trim().isNotEmpty) promo.address!.trim(),
      if (promo.distanceKm != null)
        '${promo.distanceKm!.toStringAsFixed(1)} км',
      if ((promo.provider ?? '').trim().isNotEmpty) promo.provider!.trim(),
    ].join(' · ');
    final hasBooking =
        (promo.placeBookingUrl ?? promo.bookingUrl ?? '').trim().isNotEmpty;
    final hasAnyUrl = hasBooking || (promo.sourceUrl ?? '').trim().isNotEmpty;

    return BbV5Card(
      radius: 24,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          const Positioned(
            left: -10,
            top: 66,
            child: _TicketNotch(),
          ),
          const Positioned(
            right: -10,
            top: 66,
            child: _TicketNotch(),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            category.color,
                            category.color.withValues(alpha: 0.86),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        category.icon,
                        size: 24,
                        color: BbV5Colors.paperHi,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  venue.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: bbV5KickerStyle(
                                    color: category.color,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '· ${category.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: BbV5Colors.inkMute,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: bbV5DisplayStyle(
                              fontSize: 15.5,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if ((promo.description ?? '').trim().isNotEmpty)
                            Text(
                              promo.description!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11.5,
                                color: BbV5Colors.inkMute,
                                letterSpacing: 0,
                              ),
                            )
                          else if (meta.isNotEmpty)
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11.5,
                                color: BbV5Colors.inkMute,
                                letterSpacing: 0,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BbV5Colors.hairSoft,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: opened
                      ? BbV5Colors.brandSoft.withValues(alpha: 0.35)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 12,
                      color: BbV5Colors.inkMute,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _validUntilLabel(promo.validUntil),
                        style: AppTextStyles.caption.copyWith(
                          color: BbV5Colors.inkMute,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (opened)
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.check,
                            size: 14,
                            color: BbV5Colors.brandDeep,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Открыто',
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'Sora',
                              fontSize: 11.5,
                              color: BbV5Colors.brandDeep,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      )
                    else
                      BbV5PillButton(
                        label: hasBooking ? 'Забронировать' : 'Открыть',
                        icon: hasBooking
                            ? LucideIcons.calendar_check
                            : LucideIcons.external_link,
                        dark: true,
                        height: 32,
                        fontSize: 11,
                        iconSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: hasAnyUrl ? onOpen : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketNotch extends StatelessWidget {
  const _TicketNotch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: BbV5Colors.paper,
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.hair),
      ),
    );
  }
}

class _PromoCategory {
  const _PromoCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

List<_PromoCategory> _promoCategories(List<BackendPlacePromoListItem> promos) {
  final keys = promos
      .map((promo) => _categoryForPromo(promo).key)
      .toSet()
      .toList(growable: false)
    ..sort((left, right) =>
        _categoryForKey(left).label.compareTo(_categoryForKey(right).label));
  return keys.map(_categoryForKey).toList(growable: false);
}

_PromoCategory _categoryForPromo(BackendPlacePromoListItem promo) {
  return _categoryForKey(_categoryKey(promo));
}

String _categoryKey(BackendPlacePromoListItem promo) {
  return tomestoPromoCategoryKey(
    placeKind: promo.placeKind,
    placeCategory: promo.placeCategory,
    promoTitle: promo.title,
    promoDescription: promo.description,
  );
}

_PromoCategory _categoryForKey(String key) {
  final normalized = key.trim().toLowerCase();
  if (normalized.contains('bar') ||
      normalized.contains('wine') ||
      normalized.contains('pub')) {
    return const _PromoCategory(
      key: 'bar',
      label: 'Бары',
      icon: LucideIcons.wine,
      color: BbV5Colors.accent,
    );
  }
  if (normalized.contains('restaurant') ||
      normalized.contains('food') ||
      normalized.contains('cafe') ||
      normalized.contains('coffee')) {
    return const _PromoCategory(
      key: 'food',
      label: 'Еда и кофе',
      icon: LucideIcons.utensils,
      color: BbV5Colors.brandDeep,
    );
  }
  if (normalized.contains('club') ||
      normalized.contains('night') ||
      normalized.contains('music') ||
      normalized.contains('karaoke')) {
    return const _PromoCategory(
      key: 'night',
      label: 'Музыка',
      icon: LucideIcons.music,
      color: BbV5Colors.rose,
    );
  }
  if (normalized.contains('culture') ||
      normalized.contains('museum') ||
      normalized.contains('theatre')) {
    return const _PromoCategory(
      key: 'culture',
      label: 'Культура',
      icon: LucideIcons.palette,
      color: BbV5Colors.ink,
    );
  }
  return const _PromoCategory(
    key: 'promo',
    label: 'Промо',
    icon: LucideIcons.gift,
    color: BbV5Colors.gold,
  );
}

String _validUntilLabel(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'акция активна';
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return 'до $day.$month';
}
