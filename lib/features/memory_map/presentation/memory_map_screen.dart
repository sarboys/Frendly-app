import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

class MemoryMapScreen extends StatefulWidget {
  const MemoryMapScreen({super.key});

  @override
  State<MemoryMapScreen> createState() => _MemoryMapScreenState();
}

class _MemoryMapScreenState extends State<MemoryMapScreen> {
  String _filter = 'all';
  int? _activePin;

  static const _pins = [
    _MapPinData(
      x: 0.28,
      y: 0.32,
      icon: LucideIcons.wine,
      title: 'Brix',
      subtitle: 'винный · 12 мая',
      people: ['А', 'Л', 'М'],
      color: BbV5Colors.terra,
    ),
    _MapPinData(
      x: 0.62,
      y: 0.24,
      icon: LucideIcons.music,
      title: 'Powerhouse',
      subtitle: 'джаз · 18 мая',
      people: ['С', 'К'],
      color: BbV5Colors.brand,
    ),
    _MapPinData(
      x: 0.45,
      y: 0.58,
      icon: LucideIcons.coffee,
      title: 'Кофемания',
      subtitle: 'утро · 06 мая',
      people: ['И'],
      color: BbV5Colors.gold,
    ),
    _MapPinData(
      x: 0.72,
      y: 0.64,
      icon: LucideIcons.footprints,
      title: 'Чистые пруды',
      subtitle: 'прогулка · 19 мая',
      people: ['А', 'С', 'Л'],
      color: BbV5Colors.brandDeep,
    ),
    _MapPinData(
      x: 0.18,
      y: 0.72,
      icon: LucideIcons.heart,
      title: 'Свидание · Аня',
      subtitle: '20 мая',
      people: ['А'],
      color: BbV5Colors.rose,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final active = _activePin == null ? null : _pins[_activePin!];

    return BbV5Scaffold(
      child: BbV5Page(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BbV5TopBar(
                kicker: 'Дневник',
                title: 'Карта',
                accent: 'знакомств',
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
                    label: 'Места · 12',
                    active: _filter == 'places',
                    onTap: () => setState(() => _filter = 'places'),
                  ),
                  BbV5Chip(
                    label: 'Люди · 8',
                    active: _filter == 'people',
                    onTap: () => setState(() => _filter = 'people'),
                  ),
                ],
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
                          for (var index = 0; index < _pins.length; index++)
                            _MapPinButton(
                              pin: _pins[index],
                              active: _activePin == index,
                              left: size.width * _pins[index].x,
                              top: size.height * _pins[index].y,
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
            const SliverToBoxAdapter(child: _MapStats()),
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
  const _MapStats();

  static const List<({String value, String label, IconData icon})> _items = [
    (value: '12', label: 'мест', icon: LucideIcons.map_pin),
    (value: '8', label: 'людей', icon: LucideIcons.users),
    (value: '23', label: 'вечеров', icon: LucideIcons.calendar),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in _items) ...[
          Expanded(child: _StatCard(item: item)),
          if (item != _items.last) const SizedBox(width: 10),
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
