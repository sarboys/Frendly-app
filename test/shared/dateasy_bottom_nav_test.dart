import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';

void main() {
  testWidgets('bottom nav uses the front2 Frendly item set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DateasyTheme.theme,
        home: const Scaffold(
          body: Stack(
            children: [
              DateasyBottomNav(),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.calendarHeart), findsOneWidget);
    expect(find.byIcon(LucideIcons.compass), findsOneWidget);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);
    expect(find.byIcon(LucideIcons.heart), findsOneWidget);
    expect(find.byIcon(LucideIcons.house), findsNothing);
    expect(find.byIcon(LucideIcons.map), findsNothing);
    expect(find.byIcon(LucideIcons.user), findsNothing);
  });

  testWidgets('bottom nav keeps the larger front2 surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DateasyTheme.theme,
        home: const Scaffold(
          body: Stack(
            children: [
              DateasyBottomNav(),
            ],
          ),
        ),
      ),
    );

    final nav = find.byKey(const ValueKey('dateasy-bottom-nav-surface'));
    final size = tester.getSize(nav);
    expect(size.width, moreOrLessEquals(395.6, epsilon: 0.1));
    expect(size.height, 64);

    final container = tester.widget<Container>(nav);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, DateasyColors.navSurface);
  });

  testWidgets('bottom nav keeps the lowered bottom offset with safe area',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DateasyTheme.theme,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(430, 812),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Scaffold(
            body: Stack(
              children: [
                DateasyBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );

    final nav = find.byKey(const ValueKey('dateasy-bottom-nav-surface'));
    final navBottom = tester.getBottomLeft(nav).dy;

    expect(812 - navBottom, moreOrLessEquals(21, epsilon: 0.1));
  });

  testWidgets('bottom nav highlights current route', (tester) async {
    final router = GoRouter(
      initialLocation: '/chats',
      routes: [
        GoRoute(
          path: '/chats',
          builder: (_, __) => const Scaffold(
            body: Stack(children: [DateasyBottomNav()]),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: DateasyTheme.theme,
        routerConfig: router,
      ),
    );

    final chatIcon =
        tester.widget<Icon>(find.byIcon(LucideIcons.messageCircle));

    expect(chatIcon.color, DateasyColors.backgroundDeep);
  });

  testWidgets('create button accepts taps across the visible circle',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Stack(children: [
              Center(child: Text('home-root')),
              DateasyBottomNav()
            ]),
          ),
        ),
        GoRoute(
          path: '/meetings/new',
          builder: (_, __) => const Scaffold(body: Text('new-meeting')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: DateasyTheme.theme,
        routerConfig: router,
      ),
    );

    final plusCenter = tester.getCenter(find.byIcon(LucideIcons.plus));
    await tester.tapAt(plusCenter.translate(0, -25));
    await tester.pumpAndSettle();

    expect(find.text('new-meeting'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('home-root'), findsOneWidget);
  });

  testWidgets('bottom nav opens the branch root from another branch',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/meetings',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/meetings',
                  builder: (_, __) => _ShellTestPage(
                    label: 'meetings-root',
                    actionLabel: 'open-meeting',
                    onAction: (context) => context.go('/meetings/coffee'),
                  ),
                  routes: [
                    GoRoute(
                      path: ':meetingId',
                      builder: (_, __) =>
                          const _ShellTestPage(label: 'meeting-detail'),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const _ShellTestPage(label: 'home'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chats',
                  builder: (_, __) => const _ShellTestPage(label: 'chats'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dating',
                  builder: (_, __) => const _ShellTestPage(label: 'dating'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: DateasyTheme.theme,
        routerConfig: router,
      ),
    );

    await tester.tap(find.text('open-meeting'));
    await tester.pumpAndSettle();
    expect(find.text('meeting-detail'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.heart));
    await tester.pumpAndSettle();
    expect(find.text('dating'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.calendarHeart));
    await tester.pumpAndSettle();

    expect(find.text('meetings-root'), findsOneWidget);
    expect(find.text('meeting-detail'), findsNothing);
  });
}

class _ShellTestPage extends StatelessWidget {
  const _ShellTestPage({
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final void Function(BuildContext context)? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (actionLabel != null)
                  TextButton(
                    onPressed: () => onAction?.call(context),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ),
          const DateasyBottomNav(),
        ],
      ),
    );
  }
}
