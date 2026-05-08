import 'package:big_break_mobile/app/core/network/chat_socket_client.dart';
import 'package:big_break_mobile/app/core/device/app_attachment_service.dart';
import 'package:big_break_mobile/app/core/device/app_permission_preferences.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_shell.dart';
import 'package:big_break_mobile/features/after_dark/presentation/after_dark_providers.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_thread_providers.dart';
import 'package:big_break_mobile/features/chats/presentation/chat_voice_playback_controller.dart';
import 'package:big_break_mobile/features/chats/presentation/chats_providers.dart';
import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/features/evening_plan/presentation/evening_edit_state.dart';
import 'package:big_break_mobile/features/tonight/presentation/tonight_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appSessionControllerProvider = Provider<AppSessionController>(
  (ref) => AppSessionController(ref),
);

class AppSessionController {
  AppSessionController(this.ref);

  final Ref ref;
  Future<void>? _sessionRuntimeClearFuture;
  bool _pendingPersistedChatStateClear = false;
  int _sessionReplacementGeneration = 0;

  Future<void> replaceAuthenticatedSession({
    required AuthTokens tokens,
    required String userId,
  }) async {
    final generation = ++_sessionReplacementGeneration;
    final currentUser = ref.read(currentUserIdProvider.notifier);
    final authTokens = ref.read(authTokensProvider.notifier);
    final previousUserId = ref.read(currentUserIdProvider);
    if (previousUserId != null && previousUserId != userId) {
      currentUser.state = null;
      authTokens.setTokens(tokens);
      await clearSessionRuntime(clearPersistedChatState: true);
      if (generation != _sessionReplacementGeneration) {
        return;
      }
    } else {
      authTokens.setTokens(tokens);
    }

    currentUser.state = userId;
    ref.invalidate(authBootstrapProvider);
  }

  Future<void> clearSessionRuntime({
    required bool clearPersistedChatState,
  }) async {
    _pendingPersistedChatStateClear =
        _pendingPersistedChatStateClear || clearPersistedChatState;

    final running = _sessionRuntimeClearFuture;
    if (running != null) {
      await running;
      return;
    }

    final future = _drainSessionRuntimeClearQueue();
    _sessionRuntimeClearFuture = future;
    try {
      await future;
    } finally {
      if (identical(_sessionRuntimeClearFuture, future)) {
        _sessionRuntimeClearFuture = null;
      }
    }
  }

  Future<void> _drainSessionRuntimeClearQueue() async {
    do {
      final clearPersistedChatState = _pendingPersistedChatStateClear;
      _pendingPersistedChatStateClear = false;
      await _clearSessionRuntimeOnce(
        clearPersistedChatState: clearPersistedChatState,
      );
    } while (_pendingPersistedChatStateClear);
  }

  Future<void> _clearSessionRuntimeOnce({
    required bool clearPersistedChatState,
  }) async {
    final sharedPreferences = ref.read(sharedPreferencesProvider);
    final attachmentService = ref.read(appAttachmentServiceProvider);
    final permissionPreferences = ref.read(appPermissionPreferencesProvider);
    final profilePhotoDraft = ref.read(profilePhotoDraftProvider.notifier);
    final profilePhotoPreview = ref.read(profilePhotoPreviewProvider.notifier);
    final authBootstrapProfile =
        ref.read(authBootstrapProfileProvider.notifier);
    final onboardingLocalState =
        ref.read(onboardingLocalStateProvider.notifier);
    final meetupChatsLocalState =
        ref.read(meetupChatsLocalStateProvider.notifier);
    final personalChatsLocalState =
        ref.read(personalChatsLocalStateProvider.notifier);
    final notificationsLocalState =
        ref.read(notificationsLocalStateProvider.notifier);
    final notificationUnreadCountOverride =
        ref.read(notificationUnreadCountOverrideProvider.notifier);
    final eveningRouteOverrides =
        ref.read(eveningRouteOverridesProvider.notifier);
    final tonightFilter = ref.read(tonightFilterProvider.notifier);
    final chatSegment = ref.read(chatSegmentProvider.notifier);
    final shellBottomBarVisible =
        ref.read(shellBottomBarVisibleProvider.notifier);

    if (clearPersistedChatState) {
      await SharedPreferencesChatOutboxStorage.clearStoredCommands(
        sharedPreferences,
      );
    }

    await attachmentService.clearPrivateCache();
    await permissionPreferences.clear();

    profilePhotoDraft.state = const [];
    profilePhotoPreview.state = const {};
    authBootstrapProfile.state = null;
    onboardingLocalState.state = null;
    meetupChatsLocalState.state = null;
    personalChatsLocalState.state = null;
    notificationsLocalState.state = null;
    notificationUnreadCountOverride.state = null;
    eveningRouteOverrides.state = const {};
    tonightFilter.state = TonightFilter.nearby;
    chatSegment.state = ChatSegment.meetup;
    shellBottomBarVisible.state = true;

    ref.invalidate(chatRealtimeSyncProvider);
    ref.invalidate(chatThreadProvider);
    ref.invalidate(chatVoicePlaybackControllerProvider);
    ref.invalidate(chatSocketClientProvider);

    ref.invalidate(authBootstrapProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(onboardingProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(mapEventsProvider);
    ref.invalidate(eventDetailProvider);
    ref.invalidate(afficheEventsProvider);
    ref.invalidate(afficheEventsPagedProvider);
    ref.invalidate(afficheEventDetailProvider);
    ref.invalidate(checkInProvider);
    ref.invalidate(liveMeetupProvider);
    ref.invalidate(afterPartyProvider);
    ref.invalidate(hostDashboardProvider);
    ref.invalidate(hostEventProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(verificationProvider);
    ref.invalidate(safetyHubProvider);
    ref.invalidate(storiesProvider);
    ref.invalidate(matchesProvider);
    ref.invalidate(subscriptionPlansProvider);
    ref.invalidate(subscriptionStateProvider);
    ref.invalidate(peopleProvider);
    ref.invalidate(personProfileProvider);
    ref.invalidate(profileSocialProvider);
    ref.invalidate(meetupChatsProvider);
    ref.invalidate(eveningSessionsProvider);
    ref.invalidate(eveningSessionProvider);
    ref.invalidate(eveningRouteTemplatesProvider);
    ref.invalidate(eveningRouteTemplateProvider);
    ref.invalidate(eveningRouteTemplateSessionsProvider);
    ref.invalidate(personalChatsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(afterDarkAccessProvider);
    ref.invalidate(afterDarkEventsProvider);
    ref.invalidate(afterDarkEventDetailProvider);
    ref.invalidate(datingDiscoverProvider);
    ref.invalidate(datingLikesProvider);
    ref.invalidate(communitiesFeedProvider);
    ref.invalidate(communityMediaFeedProvider);
    ref.invalidate(communitiesProvider);
    ref.invalidate(communityProvider);
  }
}
