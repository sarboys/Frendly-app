import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/shared/widgets/bb_bottom_nav.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

final shellBottomBarVisibleProvider = StateProvider<bool>((ref) => true);

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomBarVisible = ref.watch(shellBottomBarVisibleProvider);
    final showCreateMeetup =
        bottomBarVisible && location.startsWith(AppRoute.tonight.path);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          if (bottomBarVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BbV5GlassBottomBar(
                child: BbBottomNav(
                  location: location,
                  onTap: (tab) {
                    context.goRoute(tab.route);
                  },
                ),
              ),
            ),
          if (showCreateMeetup)
            Positioned(
              right: 20,
              bottom: 96,
              child: _CreateMeetupFab(
                onTap: () => context.pushRoute(AppRoute.createMeetup),
              ),
            )
        ],
      ),
    );
  }
}

class _CreateMeetupFab extends StatelessWidget {
  const _CreateMeetupFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'create-meetup-home',
      onPressed: onTap,
      backgroundColor: BbV5Colors.accent,
      foregroundColor: BbV5Colors.paperHi,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: BbV5Shadows.ink,
        ),
        child: const Icon(
          LucideIcons.plus,
          size: 30,
          color: BbV5Colors.paperHi,
        ),
      ),
    );
  }
}

enum AppTab {
  tonight(AppRoute.tonight),
  communities(AppRoute.communities),
  dating(AppRoute.dating),
  chats(AppRoute.chats),
  profile(AppRoute.profile);

  const AppTab(this.route);

  final AppRoute route;
}
