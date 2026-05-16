import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/frendly_season_provider.dart';
import 'package:big_break_mobile/shared/models/frendly_season.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MemoryMapScreen extends ConsumerStatefulWidget {
  const MemoryMapScreen({super.key});

  @override
  ConsumerState<MemoryMapScreen> createState() => _MemoryMapScreenState();
}

class _MemoryMapScreenState extends ConsumerState<MemoryMapScreen> {
  String _filter = 'all';
  int? _activePin;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(frendlyHistoryProvider);
    final peopleAsync = ref.watch(frendlyPeopleProvider);
    final history = historyAsync.valueOrNull?.items ?? const [];
    final people = peopleAsync.valueOrNull?.items ?? const [];
    final pins = _pinsFromHistory(history);
    final active = _activePin == null || _activePin! >= pins.length
        ? null
        : pins[_activePin!];
    final placesCount = history.map((item) => item.place).toSet().length;

    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BbV5TopBar(
                kicker: 'Дневник',
                title: 'История',
                accent: 'вечеров',
                onBack: () => context.pop(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 16),
                child: Text(
                  'Только для тебя. Точки показывают, где ты был и с кем пересёкся.',
                  style: AppTextStyles.meta.copyWith(
                    color: BbV5Colors.inkSoft,
                    height: 1.625,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BbV5Chip(
                    label: 'Всё',
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  BbV5Chip(
                    label: 'Места · $placesCount',
                    active: _filter == 'places',
                    onTap: () => setState(() => _filter = 'places'),
                  ),
                  BbV5Chip(
                    label: 'Люди · ${people.length}',
                    active: _filter == 'people',
                    onTap: () => setState(() => _filter = 'people'),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: _HistoryListCard(
                history: history,
                loading: historyAsync.isLoading,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: _PeopleMetSection(
                people: people,
                loading: peopleAsync.isLoading,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: BbV5Card(
                  padding: EdgeInsets.zero,
                  radius: 28,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      return Stack(
                        children: [
                          const Positioned.fill(child: _MapTexture()),
                          for (var index = 0; index < pins.length; index++)
                            _MapPinButton(
                              pin: pins[index],
                              active: _activePin == index,
                              left: size.width * pins[index].x,
                              top: size.height * pins[index].y,
                              onTap: () {
                                setState(() {
                                  _activePin =
                                      _activePin == index ? null : index;
                                });
                              },
                            ),
                          Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: BbV5Colors.ink,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: BbV5Colors.paperHi,
                                  width: 4,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: BbV5Colors.ink.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 0,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (active != null) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _ActivePinCard(pin: active)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: _MapStats(
                places: placesCount,
                people: people.length,
                evenings: history.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.lock,
                    size: 12,
                    color: BbV5Colors.inkMute,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Карта приватная. Видна только тебе',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
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
    );
  }
}

class _MapPinData {
  const _MapPinData({
    required this.x,
    required this.y,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.people,
    required this.color,
  });

  final double x;
  final double y;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> people;
  final Color color;
}

List<_MapPinData> _pinsFromHistory(List<FrendlyHistoryItemData> history) {
  final withCoords = history
      .where((item) => item.latitude != null && item.longitude != null)
      .take(12)
      .toList(growable: false);
  if (withCoords.isEmpty) {
    return const [];
  }
  final minLat = withCoords
      .map((item) => item.latitude!)
      .reduce((left, right) => left < right ? left : right);
  final maxLat = withCoords
      .map((item) => item.latitude!)
      .reduce((left, right) => left > right ? left : right);
  final minLng = withCoords
      .map((item) => item.longitude!)
      .reduce((left, right) => left < right ? left : right);
  final maxLng = withCoords
      .map((item) => item.longitude!)
      .reduce((left, right) => left > right ? left : right);
  final latSpan = (maxLat - minLat).abs();
  final lngSpan = (maxLng - minLng).abs();
  return [
    for (var index = 0; index < withCoords.length; index++)
      _MapPinData(
        x: lngSpan == 0
            ? 0.5
            : 0.16 + ((withCoords[index].longitude! - minLng) / lngSpan) * 0.68,
        y: latSpan == 0
            ? 0.5
            : 0.16 + ((maxLat - withCoords[index].latitude!) / latSpan) * 0.68,
        icon: LucideIcons.map_pin,
        title: withCoords[index].place,
        subtitle: _historyDateLabel(withCoords[index].startsAt),
        people: withCoords[index]
            .people
            .take(3)
            .map((person) => _initials(person.displayName))
            .toList(growable: false),
        color: index.isEven ? BbV5Colors.accent : BbV5Colors.brandDeep,
      ),
  ];
}

class _HistoryListCard extends StatelessWidget {
  const _HistoryListCard({
    required this.history,
    required this.loading,
  });

  final List<FrendlyHistoryItemData> history;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final visible = history.take(4).toList(growable: false);
    return BbV5Section(
      title: 'Прошедшие встречи',
      margin: EdgeInsets.zero,
      child: BbV5Card(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: visible.isEmpty
            ? Text(
                loading
                    ? 'Загружаем историю...'
                    : 'История появится после первого check-in.',
                style: AppTextStyles.meta.copyWith(
                  color: BbV5Colors.inkMute,
                  height: 1.5,
                ),
              )
            : Column(
                children: [
                  for (var index = 0; index < visible.length; index++) ...[
                    _HistoryRow(item: visible[index]),
                    if (index != visible.length - 1)
                      const Divider(color: BbV5Colors.hairSoft),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final FrendlyHistoryItemData item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BbV5Colors.terraSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            item.emoji.isEmpty ? 'Fr' : item.emoji,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: BbV5Colors.accentDeep,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bbV5DisplayStyle(fontSize: 14, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(
                '${_historyDateLabel(item.startsAt)} · ${item.place}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: BbV5Colors.inkMute,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        if (item.people.isNotEmpty)
          Text(
            '+${item.people.length}',
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'Sora',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: BbV5Colors.inkSoft,
            ),
          ),
      ],
    );
  }
}

class _PeopleMetSection extends StatelessWidget {
  const _PeopleMetSection({
    required this.people,
    required this.loading,
  });

  final List<FrendlyPersonData> people;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final visible = people.take(8).toList(growable: false);
    return BbV5Section(
      title: 'Люди с вечеров',
      margin: EdgeInsets.zero,
      child: BbV5Card(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: visible.isEmpty
            ? Text(
                loading
                    ? 'Собираем людей...'
                    : 'Здесь появятся люди, с кем ты был на встречах.',
                style: AppTextStyles.meta.copyWith(
                  color: BbV5Colors.inkMute,
                  height: 1.5,
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final person in visible)
                    _PersonChip(
                      name: person.displayName,
                      count: person.meetupsCount,
                    ),
                ],
              ),
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.name,
    required this.count,
  });

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PersonBubble(text: _initials(name)),
          const SizedBox(width: 6),
          Text(
            count > 1 ? '$name · $count' : name,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: BbV5Colors.inkSoft,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTexture extends StatelessWidget {
  const _MapTexture();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BbV5Colors.paperHi, BbV5Colors.paper],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _MapGridPainter(),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _MapRiverPainter(),
          ),
        ),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BbV5Colors.ink.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapRiverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BbV5Colors.brand.withValues(alpha: 0.36)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(-10, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.6,
        size.width * 0.55,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.82,
        size.width + 20,
        size.height * 0.58,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPinButton extends StatelessWidget {
  const _MapPinButton({
    required this.pin,
    required this.active,
    required this.left,
    required this.top,
    required this.onTap,
  });

  final _MapPinData pin;
  final bool active;
  final double left;
  final double top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = active ? 44.0 : 34.0;
    return Positioned(
      left: left - size / 2,
      top: top - size / 2,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pin.color,
            shape: BoxShape.circle,
            border:
                Border.all(color: BbV5Colors.paperHi, width: active ? 6 : 3),
            boxShadow: [
              BoxShadow(
                color: pin.color.withValues(alpha: 0.6),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(pin.icon, size: 16, color: BbV5Colors.paperHi),
        ),
      ),
    );
  }
}

class _ActivePinCard extends StatelessWidget {
  const _ActivePinCard({required this.pin});

  final _MapPinData pin;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pin.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(pin.icon, size: 20, color: BbV5Colors.paperHi),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin.title,
                  style: bbV5DisplayStyle(fontSize: 15, height: 1.25),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 12,
                      color: BbV5Colors.inkMute,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pin.subtitle,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11.5,
                        color: BbV5Colors.inkMute,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final person in pin.people) ...[
                      _PersonBubble(text: person),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '· пересёкся здесь',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: BbV5Colors.inkMute,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonBubble extends StatelessWidget {
  const _PersonBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontFamily: 'Sora',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: BbV5Colors.ink,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MapStats extends StatelessWidget {
  const _MapStats({
    required this.places,
    required this.people,
    required this.evenings,
  });

  final int places;
  final int people;
  final int evenings;

  @override
  Widget build(BuildContext context) {
    final items = [
      (value: '$places', label: 'мест', icon: LucideIcons.map_pin),
      (value: '$people', label: 'людей', icon: LucideIcons.users),
      (value: '$evenings', label: 'вечеров', icon: LucideIcons.calendar),
    ];
    return Row(
      children: [
        for (final item in items) ...[
          Expanded(child: _StatCard(item: item)),
          if (item != items.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final ({String value, String label, IconData icon}) item;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(item.icon, size: 14, color: BbV5Colors.inkMute),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: bbV5DisplayStyle(fontSize: 18, height: 1).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

String _historyDateLabel(DateTime? value) {
  if (value == null) {
    return 'вечер';
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month';
}

String _initials(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Fr';
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first.characters.first.toUpperCase();
  final second =
      parts.length > 1 ? parts[1].characters.first.toUpperCase() : '';
  return '$first$second';
}
