enum AppCacheNamespace {
  chatList('chat_list'),
  chatMessages('chat_messages'),
  profile('profile'),
  publicProfile('public_profile'),
  notifications('notifications'),
  tonight('tonight'),
  meetups('meetups'),
  map('map'),
  affiche('affiche'),
  dating('dating'),
  routeTemplates('route_templates'),
  settings('settings');

  const AppCacheNamespace(this.value);

  final String value;
}

class AppCachePolicy {
  const AppCachePolicy({
    required this.staleAfter,
    required this.expiresAfter,
  });

  final Duration staleAfter;
  final Duration expiresAfter;

  DateTime staleAt(DateTime fetchedAt) => fetchedAt.add(staleAfter);

  DateTime expiresAt(DateTime fetchedAt) => fetchedAt.add(expiresAfter);
}

class AppCachePolicies {
  const AppCachePolicies._();

  static const chatList = AppCachePolicy(
    staleAfter: Duration(seconds: 20),
    expiresAfter: Duration(hours: 6),
  );
  static const chatMessages = AppCachePolicy(
    staleAfter: Duration(seconds: 15),
    expiresAfter: Duration(days: 14),
  );
  static const profile = AppCachePolicy(
    staleAfter: Duration(minutes: 3),
    expiresAfter: Duration(days: 2),
  );
  static const publicProfile = AppCachePolicy(
    staleAfter: Duration(minutes: 10),
    expiresAfter: Duration(days: 7),
  );
  static const notifications = AppCachePolicy(
    staleAfter: Duration(seconds: 30),
    expiresAfter: Duration(days: 3),
  );
  static const tonight = AppCachePolicy(
    staleAfter: Duration(minutes: 2),
    expiresAfter: Duration(hours: 12),
  );
  static const meetups = AppCachePolicy(
    staleAfter: Duration(minutes: 2),
    expiresAfter: Duration(hours: 12),
  );
  static const map = AppCachePolicy(
    staleAfter: Duration(seconds: 45),
    expiresAfter: Duration(hours: 3),
  );
  static const affiche = AppCachePolicy(
    staleAfter: Duration(minutes: 15),
    expiresAfter: Duration(days: 2),
  );
  static const dating = AppCachePolicy(
    staleAfter: Duration(minutes: 2),
    expiresAfter: Duration(hours: 6),
  );
  static const routeTemplates = AppCachePolicy(
    staleAfter: Duration(minutes: 10),
    expiresAfter: Duration(days: 3),
  );
  static const settings = AppCachePolicy(
    staleAfter: Duration(minutes: 5),
    expiresAfter: Duration(days: 7),
  );

  static AppCachePolicy forNamespace(AppCacheNamespace namespace) {
    return switch (namespace) {
      AppCacheNamespace.chatList => chatList,
      AppCacheNamespace.chatMessages => chatMessages,
      AppCacheNamespace.profile => profile,
      AppCacheNamespace.publicProfile => publicProfile,
      AppCacheNamespace.notifications => notifications,
      AppCacheNamespace.tonight => tonight,
      AppCacheNamespace.meetups => meetups,
      AppCacheNamespace.map => map,
      AppCacheNamespace.affiche => affiche,
      AppCacheNamespace.dating => dating,
      AppCacheNamespace.routeTemplates => routeTemplates,
      AppCacheNamespace.settings => settings,
    };
  }
}
