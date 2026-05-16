import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum AppRoute {
  splash('/splash'),
  welcome('/welcome'),
  phoneAuth('/phone-auth'),
  telegramAuth('/telegram-auth'),
  permissions('/permissions'),
  addPhoto('/add-photo'),
  tonight('/tonight'),
  communities('/communities'),
  chats('/chats'),
  dating('/dating'),
  profile('/profile'),
  tokensFocus('/tokens/focus'),
  tokensBalance('/tokens/balance'),
  tokensTopUp('/tokens/top-up'),
  tokensBoost('/tokens/boost'),
  wallet('/wallet'),
  onboarding('/onboarding'),
  map('/map'),
  notifications('/notifications'),
  sos('/sos'),
  afterDark('/after-dark'),
  aiCreate('/ai-create'),
  aiVoice('/ai-voice'),
  streak('/streak'),
  memoryMap('/memory-map'),
  perks('/perks'),
  eveningBuilder('/evening-builder'),
  eveningPlan('/evening-plan/:routeId'),
  eveningEdit('/evening-edit/:routeId'),
  eveningPreview('/evening-preview/:sessionId'),
  eveningShareCard('/evening-share/:sessionId'),
  eveningLive('/evening-live/:routeId'),
  eveningAfterParty('/evening-after-party/:routeId'),
  offerCode('/offer-code/:codeId'),
  eveningRoutes('/routes'),
  newEveningRoute('/routes/new'),
  eveningRouteDetail('/routes/:templateId'),
  createEveningSession('/routes/:templateId/create'),
  meetups('/meetups'),
  affiche('/affiche'),
  afficheEvent('/affiche/event/:eventId'),
  createMeetup('/create'),
  publishMeetup('/publish'),
  joinRequest('/join-request/:eventId'),
  eveningFlow('/evening/:eventId'),
  hostDashboard('/host'),
  hostEvent('/host/event/:eventId'),
  verification('/verification'),
  safetyHub('/safety'),
  report('/report/:userId'),
  stories('/stories/:eventId'),
  shareCard('/share/:eventId'),
  match('/match/:userId'),
  paywall('/paywall'),
  paymentReturn('/payment/:result'),
  createCommunity('/community/create'),
  editCommunity('/community/:communityId/edit'),
  createCommunityPost('/community/:communityId/post/create'),
  communityDetail('/community/:communityId'),
  communityChat('/community/:communityId/chat'),
  communityMedia('/community/:communityId/media'),
  userProfile('/user/:userId'),
  editProfile('/edit-profile'),
  settings('/settings'),
  eventDetail('/event/:eventId'),
  meetupChat('/meetup/:chatId'),
  personalChat('/personal/:chatId'),
  chatLocation('/chat-location');

  const AppRoute(this.path);

  final String path;
}

extension AppRouteNavigation on BuildContext {
  Future<T?> pushRoute<T>(
    AppRoute route, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
    Object? extra,
  }) {
    return pushNamed<T>(
      route.name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }

  void goRoute(
    AppRoute route, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
    Object? extra,
  }) {
    goNamed(
      route.name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }
}
