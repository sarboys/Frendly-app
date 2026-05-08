import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class BbPinnedMeetupCard extends StatelessWidget {
  const BbPinnedMeetupCard({
    required this.chat,
    required this.place,
    super.key,
    this.distance,
    this.capacity,
    this.going,
    this.onTap,
    this.onEdit,
    this.onRouteTap,
    this.onTicketTap,
  });

  final MeetupChat chat;
  final String place;
  final String? distance;
  final int? capacity;
  final int? going;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onRouteTap;
  final VoidCallback? onTicketTap;

  @override
  Widget build(BuildContext context) {
    final joined = going ?? chat.joinedCount ?? chat.members.length;
    final maxGuests = capacity ?? chat.maxGuests ?? joined;

    return BbV5Card(
      onTap: onTap,
      radius: BbV5Radii.lg,
      padding: const EdgeInsets.all(20),
      tint: BbV5Colors.terraSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbV5Kicker('План вечера · #${_planNumber(chat.id)}'),
          const SizedBox(height: 8),
          Text(
            place,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: bbV5DisplayStyle(fontSize: 20, height: 1.25),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _PinnedMeta(
                icon: LucideIcons.calendar,
                label: 'Сегодня · ${chat.time}',
              ),
              _PinnedMeta(
                icon: LucideIcons.map_pin,
                label: distance?.trim().isNotEmpty == true
                    ? distance!.trim()
                    : place,
              ),
              _PinnedMeta(
                icon: LucideIcons.users,
                label: '$joined/$maxGuests',
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _PinnedInitialsStack(
                  members: chat.memberProfiles.isNotEmpty
                      ? chat.memberProfiles
                          .map((member) => member.displayName)
                          .toList(growable: false)
                      : chat.members,
                  count: joined,
                ),
                const SizedBox(width: 16),
                _PinnedPillAction(
                  label: 'Изменить',
                  icon: LucideIcons.pencil,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _PinnedPillAction(
                  label: 'Маршрут',
                  icon: LucideIcons.arrow_up_right,
                  dark: true,
                  onTap: onRouteTap,
                ),
              ],
            ),
          ),
          if (chat.hasPaidTicket) ...[
            const SizedBox(height: 18),
            _TicketAction(chat: chat, onTap: onTicketTap),
          ],
        ],
      ),
    );
  }
}

class _PinnedInitialsStack extends StatelessWidget {
  const _PinnedInitialsStack({
    required this.members,
    required this.count,
  });

  final List<String> members;
  final int count;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(5).toList(growable: false);
    final rest = count - visible.length;
    final itemCount = visible.length + (rest > 0 ? 1 : 0);
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }
    const size = 28.0;
    const overlap = 7.0;

    return SizedBox(
      width: size + ((itemCount - 1) * (size - overlap)),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * (size - overlap),
              child: _PinnedInitial(
                label: _initial(visible[index]),
                dark: false,
              ),
            ),
          if (rest > 0)
            Positioned(
              left: visible.length * (size - overlap),
              child: _PinnedInitial(
                label: '+$rest',
                dark: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedInitial extends StatelessWidget {
  const _PinnedInitial({
    required this.label,
    required this.dark,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? BbV5Colors.accent : BbV5Colors.paperHi,
        shape: BoxShape.circle,
        border: Border.all(color: BbV5Colors.paper, width: 1.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontFamily: 'Sora',
          fontSize: dark ? 9 : 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: dark ? BbV5Colors.paperHi : BbV5Colors.ink,
        ),
      ),
    );
  }
}

class _PinnedPillAction extends StatelessWidget {
  const _PinnedPillAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BbV5Radii.pill),
          child: Ink(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: dark ? BbV5Colors.accent : BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(BbV5Radii.pill),
              border: Border.all(
                color: dark ? BbV5Colors.accent : BbV5Colors.hair,
              ),
              boxShadow: dark ? BbV5Shadows.ink : BbV5Shadows.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!dark) ...[
                  Icon(icon, size: 14, color: BbV5Colors.ink),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppTextStyles.button.copyWith(
                    fontFamily: 'Sora',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: dark ? BbV5Colors.paperHi : BbV5Colors.ink,
                  ),
                ),
                if (dark) ...[
                  const SizedBox(width: 7),
                  Icon(icon, size: 14, color: BbV5Colors.paperHi),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedMeta extends StatelessWidget {
  const _PinnedMeta({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: BbV5Colors.inkSoft),
        const SizedBox(width: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: BbV5Colors.inkSoft,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _TicketAction extends StatelessWidget {
  const _TicketAction({
    required this.chat,
    required this.onTap,
  });

  final MeetupChat chat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _DashedBorder(
      child: Material(
        color: BbV5Colors.paper,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BbV5Colors.paperHi,
                    shape: BoxShape.circle,
                    border: Border.all(color: BbV5Colors.hair),
                  ),
                  child: const Icon(
                    LucideIcons.ticket,
                    size: 18,
                    color: BbV5Colors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'билет на событие',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bbV5KickerStyle(letterSpacing: 1.6),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'от ${_formatRubles(chat.ticketPriceFrom!)} ₽ · осталось...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bbV5DisplayStyle(fontSize: 12.5, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BbV5Colors.accent,
                    borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Купить',
                        style: AppTextStyles.button.copyWith(
                          fontFamily: 'Sora',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BbV5Colors.paperHi,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.arrow_up_right,
                        size: 14,
                        color: BbV5Colors.paperHi,
                      ),
                    ],
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

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(
        color: BbV5Colors.hair,
        radius: 18,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 6.0;
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.substring(0, 1).toUpperCase();
}

String _planNumber(String value) {
  final digits = RegExp(r'\d+').firstMatch(value)?.group(0);
  if (digits == null || digits.isEmpty) {
    return '1';
  }
  return digits.length > 2 ? digits.substring(digits.length - 2) : digits;
}

String _formatRubles(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    if (index > 0 && (raw.length - index) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(raw[index]);
  }
  return buffer.toString();
}
