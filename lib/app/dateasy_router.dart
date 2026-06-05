import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/app/core/deep_links/payment_return_link.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/features/after_dark/presentation/after_dark_event_screen.dart';
import 'package:mobile2/features/after_dark/presentation/after_dark_screen.dart';
import 'package:mobile2/features/ai_builder/presentation/ai_builder_result_screen.dart';
import 'package:mobile2/features/ai_builder/presentation/ai_builder_screen.dart';
import 'package:mobile2/features/auth/presentation/telegram_auth_screen.dart';
import 'package:mobile2/features/chats/presentation/meeting_chat_screen.dart';
import 'package:mobile2/features/chats/presentation/chats_screen.dart';
import 'package:mobile2/features/city/presentation/city_screen.dart';
import 'package:mobile2/features/communities/presentation/community_admin_screen.dart';
import 'package:mobile2/features/communities/presentation/community_detail_screen.dart';
import 'package:mobile2/features/communities/presentation/community_chat_screen.dart';
import 'package:mobile2/features/communities/presentation/community_new_screen.dart';
import 'package:mobile2/features/dating/presentation/dating_filter_screen.dart';
import 'package:mobile2/features/dating/presentation/dating_likes_screen.dart';
import 'package:mobile2/features/dating/presentation/dating_screen.dart';
import 'package:mobile2/features/dating/presentation/match_screen.dart';
import 'package:mobile2/features/evening/presentation/evening_screen.dart';
import 'package:mobile2/features/front2_placeholder/presentation/front2_placeholder_screen.dart';
import 'package:mobile2/features/giveaways/presentation/giveaways_screen.dart';
import 'package:mobile2/features/home/presentation/home_screen.dart';
import 'package:mobile2/features/host/presentation/host_dashboard_screen.dart';
import 'package:mobile2/features/legal/presentation/legal_document_screen.dart';
import 'package:mobile2/features/map/presentation/map_screen.dart';
import 'package:mobile2/features/memory_map/presentation/memory_map_screen.dart';
import 'package:mobile2/features/meetings/presentation/meeting_detail_screen.dart';
import 'package:mobile2/features/meetings/presentation/meetings_screen.dart';
import 'package:mobile2/features/meetings/presentation/new_meeting_screen.dart';
import 'package:mobile2/features/notifications/presentation/notifications_screen.dart';
import 'package:mobile2/features/onboarding/presentation/onboarding_screen.dart';
import 'package:mobile2/features/paywall/presentation/paywall_screen.dart';
import 'package:mobile2/features/auth/presentation/phone_auth_screen.dart';
import 'package:mobile2/features/perks/presentation/perks_screen.dart';
import 'package:mobile2/features/posters/presentation/poster_detail_screen.dart';
import 'package:mobile2/features/posters/presentation/posters_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_edit_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_gallery_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_history_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_screen.dart';
import 'package:mobile2/features/profile/presentation/public_user_screen.dart';
import 'package:mobile2/features/report/presentation/report_screen.dart';
import 'package:mobile2/features/routes/presentation/route_detail_screen.dart';
import 'package:mobile2/features/routes/presentation/routes_screen.dart';
import 'package:mobile2/features/search/presentation/search_screen.dart';
import 'package:mobile2/features/settings/presentation/settings_screen.dart';
import 'package:mobile2/features/share/presentation/share_screen.dart';
import 'package:mobile2/features/sos/presentation/sos_screen.dart';
import 'package:mobile2/features/splash/presentation/splash_screen.dart';
import 'package:mobile2/features/stories/presentation/stories_screen.dart';
import 'package:mobile2/features/streak/presentation/streak_screen.dart';
import 'package:mobile2/features/verify/presentation/verify_screen.dart';
import 'package:mobile2/features/wallet/presentation/wallet_screen.dart';
import 'package:mobile2/features/welcome/presentation/welcome_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';

const Set<String> _publicDateasyRoutes = {
  '/welcome',
  '/auth/phone',
  '/auth/telegram',
  '/legal/terms',
  '/legal/privacy',
  '/legal/community-rules',
};

const Set<String> _guestEntryDateasyRoutes = {
  '/welcome',
  '/auth/phone',
  '/auth/telegram',
};

String? dateasyRouteRedirectPath({
  required String path,
  required AuthTokens? tokens,
  required BackendUser? user,
  required bool bootstrapLoading,
}) {
  final isPublic = _publicDateasyRoutes.contains(path);
  if (tokens == null) {
    return isPublic ? null : '/welcome';
  }
  if (user == null) {
    if (bootstrapLoading) {
      return _guestEntryDateasyRoutes.contains(path) || path == '/splash'
          ? '/'
          : null;
    }
    return isPublic ? null : '/welcome';
  }
  if (!user.onboardingComplete && path != '/onboarding') {
    return '/onboarding';
  }
  if (path == '/splash') {
    return '/';
  }
  if (_guestEntryDateasyRoutes.contains(path)) {
    return '/';
  }
  return null;
}

class DateasyRouterRefresh extends ChangeNotifier {
  DateasyRouterRefresh(WidgetRef ref) {
    _tokensSub = ref.listenManual<AuthTokens?>(
      authTokensProvider,
      (_, __) => notifyListeners(),
    );
    _userSub = ref.listenManual(
      currentUserProvider,
      (_, __) => notifyListeners(),
    );
    _bootstrapSub = ref.listenManual<AsyncValue<void>>(
      authBootstrapProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthTokens?> _tokensSub;
  late final ProviderSubscription<Object?> _userSub;
  late final ProviderSubscription<AsyncValue<void>> _bootstrapSub;

  @override
  void dispose() {
    _tokensSub.close();
    _userSub.close();
    _bootstrapSub.close();
    super.dispose();
  }
}

GoRouter buildDateasyRouter(
  WidgetRef ref, {
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final path = state.uri.path;
      final legacyRedirect = legacyDateasyRouteRedirect(state.uri);
      if (legacyRedirect != null) {
        return legacyRedirect;
      }
      return dateasyRouteRedirectPath(
        path: path,
        tokens: ref.read(authTokensProvider),
        user: ref.read(currentUserProvider),
        bootstrapLoading: ref.read(authBootstrapProvider).isLoading,
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/city', builder: (_, __) => const CityScreen()),
      GoRoute(path: '/evening', builder: (_, __) => const EveningScreen()),
      GoRoute(path: '/after-dark', builder: (_, __) => const AfterDarkScreen()),
      GoRoute(
        path: '/after-dark/:eventId',
        builder: (_, state) => AfterDarkEventScreen(
          eventId: state.pathParameters['eventId'] ?? '',
        ),
      ),
      GoRoute(path: '/memory-map', builder: (_, __) => const MemoryMapScreen()),
      GoRoute(path: '/ai-builder', builder: (_, __) => const AiBuilderScreen()),
      GoRoute(
        path: '/ai-builder/result',
        builder: (_, state) => AiBuilderResultScreen(
          draftId: state.uri.queryParameters['draftId'],
        ),
      ),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/legal/:documentId',
        builder: (_, state) => LegalDocumentScreen(
          documentId: state.pathParameters['documentId'] ?? '',
        ),
      ),
      GoRoute(path: '/auth/phone', builder: (_, __) => const PhoneAuthScreen()),
      GoRoute(
        path: '/auth/telegram',
        builder: (_, __) => const TelegramAuthScreen(),
      ),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            _DateasyShellRefreshBridge(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/meetings',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const MeetingsScreen()),
                routes: [
                  GoRoute(
                    path: 'new',
                    pageBuilder: (_, state) => _noTransitionPage(
                      state,
                      NewMeetingScreen(
                        editEventId: state.uri.queryParameters['editEventId'],
                        afficheEventId:
                            state.uri.queryParameters['afficheEventId'],
                        inviteeUserId:
                            state.uri.queryParameters['inviteeUserId'],
                        sourceChatId: state.uri.queryParameters['sourceChatId'],
                        communityId: state.uri.queryParameters['communityId'],
                        routeId: state.uri.queryParameters['routeId'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':meetingId',
                    builder: (_, state) => MeetingDetailScreen(
                      meetingId: state.pathParameters['meetingId'] ?? 'coffee',
                      inviteRequestId:
                          state.uri.queryParameters['inviteRequestId'],
                    ),
                    routes: [
                      GoRoute(
                        path: 'chat',
                        builder: (_, state) => MeetingChatScreen(
                          meetingId:
                              state.pathParameters['meetingId'] ?? 'coffee',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const HomeScreen()),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (_, __) => const NotificationsScreen(),
                  ),
                  GoRoute(
                      path: 'search', builder: (_, __) => const SearchScreen()),
                  GoRoute(path: 'map', builder: (_, __) => const MapScreen()),
                  GoRoute(
                    path: 'posters',
                    builder: (_, __) => const PostersScreen(),
                    routes: [
                      GoRoute(
                        path: ':posterId',
                        builder: (_, state) => PosterDetailScreen(
                          posterId: state.pathParameters['posterId'] ?? '',
                          initialPoster: state.extra is BackendCardItem
                              ? state.extra as BackendCardItem
                              : null,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                      path: 'perks', builder: (_, __) => const PerksScreen()),
                  GoRoute(
                    path: 'stories',
                    builder: (_, state) => StoriesScreen(
                      eventId: state.uri.queryParameters['eventId'],
                    ),
                  ),
                  GoRoute(
                      path: 'streak', builder: (_, __) => const StreakScreen()),
                  GoRoute(
                    path: 'share',
                    builder: (_, state) => ShareScreen(
                      targetType: state.uri.queryParameters['targetType'],
                      targetId: state.uri.queryParameters['targetId'],
                    ),
                  ),
                  GoRoute(path: 'sos', builder: (_, __) => const SosScreen()),
                  GoRoute(
                    path: 'routes',
                    builder: (_, __) => const DateasyRoutesScreen(),
                    routes: [
                      GoRoute(
                        path: ':routeId',
                        builder: (_, state) => DateasyRouteDetailScreen(
                          routeId: state.pathParameters['routeId'] ?? 'patriki',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'communities',
                    builder: (_, __) => const HomeScreen(initialHomeTab: 1),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (_, __) => const CommunityNewScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => CommunityDetailScreen(
                          communityId: state.pathParameters['id'] ?? 'wine',
                        ),
                        routes: [
                          GoRoute(
                            path: 'chat',
                            builder: (_, state) => CommunityChatScreen(
                              communityId: state.pathParameters['id'] ?? '',
                            ),
                          ),
                          GoRoute(
                            path: 'admin',
                            builder: (_, state) => CommunityAdminScreen(
                              communityId: state.pathParameters['id'] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const ChatsScreen()),
                routes: [
                  GoRoute(
                    path: ':chatId',
                    builder: (_, state) => MeetingChatScreen(
                      meetingId: state.pathParameters['chatId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dating',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const DatingScreen()),
                routes: [
                  GoRoute(
                    path: 'filter',
                    builder: (_, __) => const DatingFilterScreen(),
                  ),
                  GoRoute(
                    path: 'likes',
                    builder: (_, state) => DatingLikesScreen(
                      initialCount: int.tryParse(
                        state.uri.queryParameters['count'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/match',
                builder: (_, state) => MatchScreen(
                  userId: state.uri.queryParameters['userId'],
                  chatId: state.uri.queryParameters['chatId'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, __) => const ProfileEditScreen(),
                  ),
                  GoRoute(
                    path: 'gallery',
                    builder: (_, __) => const ProfileGalleryScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (_, __) => const ProfileHistoryScreen(),
                  ),
                ],
              ),
              GoRoute(
                  path: '/host',
                  builder: (_, __) => const HostDashboardScreen()),
              GoRoute(
                  path: '/giveaways',
                  builder: (_, __) => const GiveawaysScreen()),
              GoRoute(
                  path: '/settings',
                  builder: (_, __) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'faq',
                      builder: (_, __) => const SettingsFaqScreen(),
                    ),
                    GoRoute(
                      path: 'documents',
                      builder: (_, __) => const SettingsDocumentsScreen(),
                      routes: [
                        GoRoute(
                          path: 'promo-rules',
                          builder: (_, __) => const SettingsPromoRulesScreen(),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'blocked',
                      builder: (_, __) => const SettingsBlockedUsersScreen(),
                    ),
                  ]),
              GoRoute(
                  path: '/wallet', builder: (_, __) => const WalletScreen()),
              GoRoute(
                  path: '/paywall', builder: (_, __) => const PaywallScreen()),
              GoRoute(
                  path: '/verify', builder: (_, __) => const VerifyScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/u/:userId',
        builder: (_, state) => PublicUserScreen(
          userId: state.pathParameters['userId'] ?? 'nina',
        ),
      ),
      GoRoute(
        path: '/report',
        builder: (_, state) => ReportScreen(
          targetUserId: state.uri.queryParameters['targetUserId'],
        ),
      ),
      GoRoute(
        path: '/:page',
        builder: (_, state) => Front2PlaceholderScreen(
          title: _titleFor(state.pathParameters['page']),
        ),
      ),
    ],
  );
}

class _DateasyShellRefreshBridge extends ConsumerStatefulWidget {
  const _DateasyShellRefreshBridge({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_DateasyShellRefreshBridge> createState() =>
      _DateasyShellRefreshBridgeState();
}

class _DateasyShellRefreshBridgeState
    extends ConsumerState<_DateasyShellRefreshBridge> {
  late int _currentIndex = widget.navigationShell.currentIndex;

  @override
  void didUpdateWidget(covariant _DateasyShellRefreshBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.navigationShell.currentIndex;
    if (nextIndex == _currentIndex) {
      return;
    }
    _currentIndex = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshBranch(nextIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.navigationShell;
  }

  void _refreshBranch(int index) {
    switch (index) {
      case 0:
        ref.invalidate(meetingsProvider);
        ref.invalidate(meetingsQueryProvider);
        break;
      case 1:
        ref.invalidate(homeEventsProvider);
        ref.invalidate(homeEventsQueryProvider);
        ref.invalidate(postersProvider);
        ref.invalidate(communitiesProvider);
        break;
      case 2:
        ref.invalidate(chatsProvider);
        ref.invalidate(chatListProvider);
        break;
      case 3:
        ref.invalidate(datingLikesProvider);
        ref.invalidate(datingLimitsProvider);
        break;
      case 4:
        ref.invalidate(ownProfileProvider);
        ref.invalidate(tokenWalletProvider);
        ref.invalidate(verificationProvider);
        ref.invalidate(subscriptionProvider);
        ref.invalidate(profileHistoryProvider);
        break;
    }
  }
}

String? legacyDateasyRouteRedirect(Uri uri) {
  final paymentReturn = paymentReturnRouteForUri(uri);
  if (paymentReturn != null) {
    return paymentReturn;
  }
  final path = uri.path;
  final segments = uri.pathSegments;
  return switch (path) {
    '/phone' || '/phone-auth' => '/auth/phone',
    '/telegram-auth' => '/auth/telegram',
    '/tonight' => '/',
    '/meetups' => _uri(path: '/meetings', queryParameters: uri.queryParameters),
    '/affiche' => _uri(path: '/posters', queryParameters: uri.queryParameters),
    '/verification' => '/verify',
    '/evening-builder' || '/ai-create' || '/ai-voice' => '/ai-builder',
    '/edit-profile' => '/profile/edit',
    '/create' =>
      _uri(path: '/meetings/new', queryParameters: uri.queryParameters),
    '/safety' => '/sos',
    '/community/create' => '/communities/new',
    '/tokens/focus' ||
    '/tokens/balance' ||
    '/tokens/top-up' ||
    '/tokens/boost' =>
      '/wallet',
    _
        when segments.length == 3 &&
            segments[0] == 'affiche' &&
            segments[1] == 'event' =>
      _uri(
        path: '/posters/${Uri.encodeComponent(segments[2])}',
        queryParameters: uri.queryParameters,
      ),
    _ when segments.length == 2 && segments[0] == 'event' => _uri(
        path: '/meetings/${Uri.encodeComponent(segments[1])}',
        queryParameters: uri.queryParameters,
      ),
    _
        when segments.length == 3 &&
            segments[0] == 'meetings' &&
            segments[2] == 'chat' =>
      _uri(
        path: '/chats/${Uri.encodeComponent(segments[1])}',
        queryParameters: uri.queryParameters,
      ),
    _
        when segments.length == 2 &&
            (segments[0] == 'meetup' || segments[0] == 'personal') =>
      _uri(
        path: '/chats/${Uri.encodeComponent(segments[1])}',
        queryParameters: uri.queryParameters,
      ),
    _
        when segments.length == 3 &&
            segments[0] == 'routes' &&
            segments[2] == 'create' =>
      _uri(
        path: '/routes/${Uri.encodeComponent(segments[1])}',
        queryParameters: uri.queryParameters,
      ),
    _ when segments.length == 2 && segments[0] == 'user' => _uri(
        path: '/u/${Uri.encodeComponent(segments[1])}',
        queryParameters: uri.queryParameters,
      ),
    _ when segments.length == 2 && segments[0] == 'report' => _uri(
        path: '/report',
        queryParameters: {
          'targetUserId': segments[1],
          ...uri.queryParameters,
        },
      ),
    _ when segments.length == 2 && segments[0] == 'share' => _uri(
        path: '/share',
        queryParameters: {
          'targetType': 'event',
          'targetId': segments[1],
          ...uri.queryParameters,
        },
      ),
    _ when segments.length == 2 && segments[0] == 'stories' => _uri(
        path: '/stories',
        queryParameters: {
          'eventId': segments[1],
          ...uri.queryParameters,
        },
      ),
    _ when segments.length == 2 && segments[0] == 'join-request' => _uri(
        path: '/meetings/${Uri.encodeComponent(segments[1])}',
        queryParameters: uri.queryParameters,
      ),
    _ when segments.length == 2 && segments[0] == 'match' => _uri(
        path: '/match',
        queryParameters: {
          'userId': segments[1],
          ...uri.queryParameters,
        },
      ),
    _ when segments.length >= 2 && segments[0] == 'community' => _uri(
        path: '/communities/${Uri.encodeComponent(segments[1])}',
        queryParameters: uri.queryParameters,
      ),
    _ when segments.length == 2 && segments[0] == 'payment' => _uri(
        path: '/wallet',
        queryParameters: {
          'paymentResult': segments[1],
          ...uri.queryParameters,
        },
      ),
    _ => null,
  };
}

String _uri({
  required String path,
  Map<String, String> queryParameters = const {},
}) {
  if (queryParameters.isEmpty) {
    return path;
  }
  return Uri(path: path, queryParameters: queryParameters).toString();
}

Page<void> _noTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

String _titleFor(String? page) {
  final value = page ?? 'soon';
  return switch (value) {
    'auth' => 'Авторизация',
    'onboarding' => 'Анкета',
    _ => 'Скоро',
  };
}
