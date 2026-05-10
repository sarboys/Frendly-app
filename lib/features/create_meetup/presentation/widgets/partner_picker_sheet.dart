import 'package:big_break_mobile/app/theme/app_colors.dart';
import 'package:big_break_mobile/app/theme/app_radii.dart';
import 'package:big_break_mobile/app/theme/app_shadows.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

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

const partnerCategories = [
  PartnerCategory(key: 'bar', label: 'Бары', emoji: '🍷'),
  PartnerCategory(key: 'club', label: 'Клубы', emoji: '🪩'),
  PartnerCategory(key: 'restaurant', label: 'Рестораны', emoji: '🍝'),
  PartnerCategory(key: 'cafe', label: 'Кофейни', emoji: '☕'),
  PartnerCategory(key: 'sport', label: 'Спорт', emoji: '🏃'),
  PartnerCategory(key: 'wellness', label: 'Wellness', emoji: '🧖'),
  PartnerCategory(key: 'culture', label: 'Культура', emoji: '🎨'),
  PartnerCategory(key: 'outdoor', label: 'На воздухе', emoji: '🌳'),
];

const partnerVenues = <PartnerVenue>[
  PartnerVenue(
    id: 'brix',
    name: 'Brix Wine',
    category: 'bar',
    emoji: '🍷',
    area: 'Покровка',
    address: 'Покровка 12',
    distance: '0.4 км',
    rating: 4.8,
    perk: '−15% на винную карту для компании от 3 человек',
    perkShort: '−15%',
    verified: true,
    featured: true,
  ),
  PartnerVenue(
    id: 'aglio',
    name: 'Aglio',
    category: 'restaurant',
    emoji: '🍝',
    area: 'Маросейка',
    address: 'Маросейка 6',
    distance: '0.7 км',
    rating: 4.7,
    perk: 'Десерт в подарок при чек-ине',
    perkShort: 'десерт в подарок',
    verified: true,
    featured: true,
  ),
  PartnerVenue(
    id: 'powerhouse',
    name: 'Powerhouse',
    category: 'bar',
    emoji: '🎶',
    area: 'Казакова',
    address: 'Казакова 8',
    distance: '1.2 км',
    rating: 4.6,
    perk: 'Вход без очереди на late jazz после 23:00',
    perkShort: 'вход без очереди',
    verified: true,
  ),
  PartnerVenue(
    id: 'coffeemania',
    name: 'Coffeemania',
    category: 'cafe',
    emoji: '☕',
    area: 'Центр',
    address: 'рядом с тобой',
    distance: '0.8 км',
    rating: 4.5,
    perk: 'Второй кофе бесплатно до 12:00',
    perkShort: '2-й кофе бесплатно',
  ),
];

Future<PartnerVenue?> showPartnerPickerSheet(
  BuildContext context, {
  PartnerVenue? initialValue,
}) {
  return showModalBottomSheet<PartnerVenue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.of(context).foreground.withValues(alpha: 0.4),
    builder: (context) => _PartnerPickerSheet(
      initialValue: initialValue,
    ),
  );
}

class _PartnerPickerSheet extends StatefulWidget {
  const _PartnerPickerSheet({
    required this.initialValue,
  });

  final PartnerVenue? initialValue;

  @override
  State<_PartnerPickerSheet> createState() => _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends State<_PartnerPickerSheet> {
  final _queryController = TextEditingController();
  String _active = 'all';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final query = _queryController.text.trim().toLowerCase();
    final filtered = partnerVenues.where((venue) {
      if (_active != 'all' && venue.category != _active) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return venue.name.toLowerCase().contains(query) ||
          venue.area.toLowerCase().contains(query) ||
          venue.perk.toLowerCase().contains(query);
    }).toList(growable: false);
    final featured =
        partnerVenues.where((venue) => venue.featured).toList(growable: false);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.92,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: AppShadows.card,
        ),
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
                            Icon(LucideIcons.sparkles,
                                size: 12, color: colors.inkMute),
                            const SizedBox(width: 4),
                            Text(
                              'Партнёры Frendly',
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
                          'Партнёрские места',
                          style: bbV5DisplayStyle(
                            fontSize: 18,
                            height: 1.25,
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
                          hintText: 'Заведение, район или перк',
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
                        icon: Icon(LucideIcons.x,
                            size: 16, color: colors.inkMute),
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
                  for (final category in partnerCategories)
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
                      title: 'Лучшие перки сейчас',
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
                            ? 'Все партнёры'
                            : partnerCategories
                                .firstWhere((item) => item.key == _active)
                                .label)
                        : 'Найдено · ${filtered.length}',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Ничего не нашли. Попробуй другую категорию.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.meta.copyWith(
                          color: colors.inkMute,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    )
                  else
                    for (final venue in filtered)
                      _PartnerRow(
                        venue: venue,
                        selected: widget.initialValue?.id == venue.id,
                      ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Партнёры проверены командой Frendly. Перк применяется при бронировании из встречи.',
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
        borderRadius: AppRadii.pillBorder,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.foreground : colors.card,
            borderRadius: AppRadii.pillBorder,
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
                        const SizedBox(width: 8),
                        Icon(LucideIcons.star, size: 12, color: colors.inkSoft),
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
