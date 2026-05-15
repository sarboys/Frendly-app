import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
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

class PartnerVenue {
  const PartnerVenue({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.area,
    required this.address,
    required this.distance,
    required this.rating,
    required this.perk,
    required this.perkShort,
    this.verified = false,
    this.featured = false,
    this.externalPlaceId,
    this.latitude,
    this.longitude,
    this.bookingUrl,
  });

  final String id;
  final String name;
  final String category;
  final String emoji;
  final String area;
  final String address;
  final String distance;
  final double rating;
  final String perk;
  final String perkShort;
  final bool verified;
  final bool featured;
  final String? externalPlaceId;
  final double? latitude;
  final double? longitude;
  final String? bookingUrl;
}

class PartnerCategory {
  const PartnerCategory({
    required this.key,
    required this.label,
    required this.emoji,
  });

  final String key;
  final String label;
  final String emoji;
}

Future<PartnerVenue?> showPartnerPickerSheet(
  BuildContext context, {
  PartnerVenue? initialValue,
}) {
  final container = ProviderScope.containerOf(context, listen: false);

  return showModalBottomSheet<PartnerVenue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.of(context).foreground.withValues(alpha: 0.4),
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: _PartnerPickerSheet(
        initialValue: initialValue,
      ),
    ),
  );
}

class _PartnerPickerSheet extends ConsumerStatefulWidget {
  const _PartnerPickerSheet({
    required this.initialValue,
  });

  final PartnerVenue? initialValue;

  @override
  ConsumerState<_PartnerPickerSheet> createState() =>
      _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends ConsumerState<_PartnerPickerSheet> {
  final _queryController = TextEditingController();
  String _active = 'all';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manualLocation = ref.watch(manualLocationProvider);
    final query = TomestoPromosQuery.fromManualLocation(manualLocation);
    final promosAsync = ref.watch(tomestoPromosProvider(query));

    return SafeArea(
      top: false,
      child: promosAsync.when(
        loading: () => const _SheetFrame(
          child: Center(
            child: CircularProgressIndicator(
              color: BbV5Colors.ink,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, __) => _SheetFrame(
          child: _PromoErrorState(
            onRetry: () => ref.invalidate(tomestoPromosProvider(query)),
          ),
        ),
        data: (promos) => _buildLoaded(context, promos, query.city),
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    List<BackendPlacePromoListItem> promos,
    String city,
  ) {
    final colors = AppColors.of(context);
    final query = _queryController.text.trim().toLowerCase();
    final venues = promos.map(_venueFromPromo).toList(growable: false);
    final categories = _promoCategories(venues);
    if (_active != 'all' &&
        !categories.any((category) => category.key == _active)) {
      _active = 'all';
    }

    final filtered = venues.where((venue) {
      final categoryKey = _categoryKey(venue.category);
      if (_active != 'all' && categoryKey != _active) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return venue.name.toLowerCase().contains(query) ||
          venue.address.toLowerCase().contains(query) ||
          venue.area.toLowerCase().contains(query) ||
          venue.perk.toLowerCase().contains(query);
    }).toList(growable: false);

    final featured = venues.take(6).toList(growable: false);

    return _SheetFrame(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.gift,
                            size: 12,
                            color: colors.inkMute,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Промо Tomesto',
                            style: bbV5KickerStyle(
                              color: colors.inkMute,
                              fontSize: 9.5,
                              letterSpacing: 1.71,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Акции рядом',
                        style: bbV5DisplayStyle(
                          fontSize: 18,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        city,
                        style: AppTextStyles.caption.copyWith(
                          color: colors.inkMute,
                          fontSize: 10.5,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.search, size: 18, color: colors.inkMute),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Акция, место или категория',
                        hintStyle: AppTextStyles.bodySoft.copyWith(
                          color: colors.inkMute,
                          fontSize: 13.5,
                          height: 1.2,
                        ),
                      ),
                      style: AppTextStyles.bodySoft.copyWith(
                        color: colors.foreground,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (_queryController.text.isNotEmpty)
                    IconButton(
                      onPressed: () => setState(_queryController.clear),
                      icon: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: colors.inkMute,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryChip(
                  label: 'Все',
                  active: _active == 'all',
                  onTap: () => setState(() => _active = 'all'),
                ),
                for (final category in categories)
                  _CategoryChip(
                    label: '${category.emoji} ${category.label}',
                    active: _active == category.key,
                    onTap: () => setState(() => _active = category.key),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              children: [
                if (_active == 'all' &&
                    query.isEmpty &&
                    featured.isNotEmpty) ...[
                  const _ListTitle(
                    icon: LucideIcons.sparkles,
                    title: 'Ближайшие акции',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return _FeaturedPartnerCard(venue: featured[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _ListTitle(
                  title: query.isEmpty
                      ? (_active == 'all'
                          ? 'Все промо'
                          : categories
                              .firstWhere((item) => item.key == _active)
                              .label)
                      : 'Найдено · ${filtered.length}',
                ),
                const SizedBox(height: AppSpacing.xs),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      promos.isEmpty
                          ? 'В этом городе пока нет активных акций Tomesto.'
                          : 'Ничего не нашли. Попробуй другую категорию.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  )
                else if (_active == 'all' && query.isEmpty)
                  for (final category in categories) ...[
                    _ListTitle(title: category.label),
                    const SizedBox(height: 8),
                    for (final venue in filtered.where(
                      (venue) => _categoryKey(venue.category) == category.key,
                    ))
                      _PartnerRow(
                        venue: venue,
                        selected: widget.initialValue?.id == venue.id,
                      ),
                  ]
                else
                  for (final venue in filtered)
                    _PartnerRow(
                      venue: venue,
                      selected: widget.initialValue?.id == venue.id,
                    ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Акции загружаются из Tomesto по выбранному городу. После выбора место попадёт в встречу.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.inkMute,
                    fontSize: 10.5,
                    height: 1.45,
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

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class _PromoErrorState extends StatelessWidget {
  const _PromoErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Не удалось загрузить промо Tomesto.',
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(color: colors.inkMute),
          ),
          const SizedBox(height: 14),
          BbV5PillButton(
            label: 'Повторить',
            icon: LucideIcons.refresh_cw,
            height: 38,
            fontSize: 12,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.foreground : colors.card,
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: active ? colors.foreground : colors.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.meta.copyWith(
              color: active ? colors.background : colors.inkSoft,
              fontSize: 11.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.23,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle({
    required this.title,
    this.icon,
  });

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: colors.inkMute),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: bbV5KickerStyle(
            color: colors.inkMute,
          ),
        ),
      ],
    );
  }
}

class _FeaturedPartnerCard extends StatelessWidget {
  const _FeaturedPartnerCard({required this.venue});

  final PartnerVenue venue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).pop(venue),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _PartnerEmoji(venue.emoji),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PartnerTitle(venue: venue),
                      Text(
                        '${venue.area} · ${venue.distance}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: colors.inkMute,
                          fontSize: 10.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _PerkPill(text: venue.perkShort),
          ],
        ),
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({
    required this.venue,
    required this.selected,
  });

  final PartnerVenue venue;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(venue),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? colors.primarySoft : colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Row(
            children: [
              _PartnerEmoji(venue.emoji),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PartnerTitle(venue: venue),
                    const SizedBox(height: 2),
                    Text(
                      '${venue.area} · ${venue.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: colors.inkMute,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(child: _PerkPill(text: venue.perkShort)),
                        if (venue.rating > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            LucideIcons.star,
                            size: 12,
                            color: colors.inkSoft,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            venue.rating.toStringAsFixed(1),
                            style: AppTextStyles.caption.copyWith(
                              color: colors.inkSoft,
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                venue.distance,
                style: AppTextStyles.caption.copyWith(
                  color: colors.inkMute,
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerTitle extends StatelessWidget {
  const _PartnerTitle({required this.venue});

  final PartnerVenue venue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            venue.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.itemTitle.copyWith(
              fontSize: 13.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (venue.verified) ...[
          const SizedBox(width: 4),
          Icon(LucideIcons.badge_check, size: 14, color: colors.primary),
        ],
      ],
    );
  }
}

class _PartnerEmoji extends StatelessWidget {
  const _PartnerEmoji(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.warmStart, colors.warmEnd]),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

class _PerkPill extends StatelessWidget {
  const _PerkPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.gift, size: 13, color: colors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: colors.primary,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

PartnerVenue _venueFromPromo(BackendPlacePromoListItem promo) {
  final cleanTitle = cleanTomestoPromoTitle(promo.title);
  final category = tomestoPromoCategoryKey(
    placeKind: promo.placeKind,
    placeCategory: promo.placeCategory,
    promoTitle: promo.title,
    promoDescription: promo.description,
  );
  final displayCategory = _categoryForKey(category);
  final placeName = tomestoVenueDisplayName(
    promoTitle: promo.title,
    placeName: promo.placeName,
    venueName: promo.venueName,
  );
  final address = promo.address?.trim().isNotEmpty == true
      ? promo.address!.trim()
      : promo.city;
  final distance = promo.distanceKm == null
      ? 'рядом'
      : '${promo.distanceKm!.toStringAsFixed(1)} км';
  final averageCheck = promo.averageCheck == null
      ? null
      : 'средний чек ${promo.averageCheck} ${_currencySymbol(promo.currency)}';
  return PartnerVenue(
    id: promo.id,
    name: placeName,
    category: displayCategory.key,
    emoji: displayCategory.emoji,
    area: displayCategory.label,
    address: address,
    distance: distance,
    rating: 0,
    perk: [
      cleanTitle,
      if ((promo.description ?? '').trim().isNotEmpty)
        promo.description!.trim(),
      if (averageCheck != null) averageCheck,
    ].join('\n'),
    perkShort: cleanTitle,
    verified: (promo.provider ?? '').trim().isNotEmpty,
    featured: true,
    externalPlaceId: promo.placeId,
    latitude: promo.latitude,
    longitude: promo.longitude,
    bookingUrl: promo.placeBookingUrl ?? promo.bookingUrl,
  );
}

List<PartnerCategory> _promoCategories(List<PartnerVenue> venues) {
  final keys = venues.map((venue) => venue.category).toSet().toList()
    ..sort((left, right) =>
        _categoryForKey(left).label.compareTo(_categoryForKey(right).label));
  return keys.map(_categoryForKey).toList(growable: false);
}

String _categoryKey(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized.contains('bar') ||
      normalized.contains('wine') ||
      normalized.contains('pub')) {
    return 'bar';
  }
  if (normalized.contains('restaurant') ||
      normalized.contains('food') ||
      normalized.contains('cafe') ||
      normalized.contains('coffee')) {
    return 'food';
  }
  if (normalized.contains('club') ||
      normalized.contains('music') ||
      normalized.contains('karaoke')) {
    return 'night';
  }
  if (normalized.contains('culture') ||
      normalized.contains('museum') ||
      normalized.contains('theatre')) {
    return 'culture';
  }
  return 'promo';
}

PartnerCategory _categoryForKey(String key) {
  switch (key) {
    case 'bar':
      return const PartnerCategory(key: 'bar', label: 'Бары', emoji: '🍷');
    case 'food':
      return const PartnerCategory(
        key: 'food',
        label: 'Еда и кофе',
        emoji: '🍝',
      );
    case 'night':
      return const PartnerCategory(key: 'night', label: 'Музыка', emoji: '🎶');
    case 'culture':
      return const PartnerCategory(
        key: 'culture',
        label: 'Культура',
        emoji: '🎨',
      );
    default:
      return const PartnerCategory(key: 'promo', label: 'Промо', emoji: '🎁');
  }
}

String _currencySymbol(String? currency) {
  final value = currency?.toUpperCase();
  if (value == null || value == 'RUB') {
    return '₽';
  }
  return value;
}
