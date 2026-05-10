import 'package:big_break_mobile/features/affiche/presentation/affiche_events_screen.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<AfficheEvent?> showAfficheEventPickerSheet(
  BuildContext context, {
  AfficheEvent? initialValue,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showModalBottomSheet<AfficheEvent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: _AfficheEventPickerSheet(initialValue: initialValue),
    ),
  );
}

class _AfficheEventPickerSheet extends StatelessWidget {
  const _AfficheEventPickerSheet({
    this.initialValue,
  });

  final AfficheEvent? initialValue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.92,
          child: Material(
            color: BbV5Colors.paper,
            child: Stack(
              children: [
                const Positioned.fill(child: BbV5WarmBackground()),
                AfficheEventsBrowser(
                  initialSelectedEvent: initialValue,
                  onEventSelected: (event) => Navigator.of(context).pop(event),
                  onBack: () => Navigator.of(context).pop(),
                  backIcon: LucideIcons.x,
                  kicker: 'События и билеты',
                  title: 'Выбрать из',
                  accent: 'афиши',
                  searchHintText: 'Концерт, спектакль, матч',
                  safeAreaTop: false,
                  showDragHandle: true,
                  headerTopPadding: 12,
                  bottomSpacer: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
