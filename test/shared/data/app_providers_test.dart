import 'dart:async';
import 'dart:convert';

import 'package:big_break_mobile/app/core/local_cache/app_cache_key.dart';
import 'package:big_break_mobile/app/core/local_cache/app_cache_policy.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_cache_store.dart';
import 'package:big_break_mobile/app/core/local_cache/app_local_database.dart';
import 'package:big_break_mobile/app/core/local_cache/chat_local_store.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/local_cache/local_first_repository.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/app/core/network/chat_socket_client.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/dating_profile.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/notification_item.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/personal_chat.dart';
import 'package:big_break_mobile/shared/models/profile.dart';
import 'package:big_break_mobile/shared/models/tokens.dart';
import 'package:big_break_mobile/shared/models/user_settings.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _ChatsShouldNotLoadWithoutAuthRepository extends BackendRepository {
  _ChatsShouldNotLoadWithoutAuthRepository({
    required super.ref,
    required super.dio,
  });

  var meetupCalls = 0;
  var personalCalls = 0;

  @override
  Future<PaginatedResponse<MeetupChat>> fetchMeetupChats({
    String? cursor,
    int limit = 20,
  }) async {
    meetupCalls += 1;
    throw StateError('meetup chats should stay idle without auth');
  }

  @override
  Future<PaginatedResponse<PersonalChat>> fetchPersonalChats({
    String? cursor,
    int limit = 20,
  }) async {
    personalCalls += 1;
    throw StateError('personal chats should stay idle without auth');
  }
}

class _RouteTemplatesRepository extends BackendRepository {
  _RouteTemplatesRepository({
    required super.ref,
    required super.dio,
    this.error,
  });

  final Object? error;
  var templateCalls = 0;

  @override
  Future<PaginatedResponse<EveningRouteTemplateSummary>>
      fetchEveningRouteTemplates({
    String city = 'Москва',
    String? q,
    int limit = 20,
  }) async {
    templateCalls += 1;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return const PaginatedResponse<EveningRouteTemplateSummary>(
      items: [],
      nextCursor: null,
    );
  }
}

class _OnboardingShouldNotLoadWithoutNetworkRepository
    extends BackendRepository {
  _OnboardingShouldNotLoadWithoutNetworkRepository({
    required super.ref,
    required super.dio,
  });

  var onboardingCalls = 0;

  @override
  Future<OnboardingData> fetchOnboarding() async {
    onboardingCalls += 1;
    throw StateError('onboarding should stay local in this test');
  }
}

class _ProfileWithSharedOnboardingRepository extends BackendRepository {
  _ProfileWithSharedOnboardingRepository({
    required super.ref,
    required super.dio,
  });

  var fetchMeCalls = 0;
  var fetchProfileCalls = 0;
  var fetchOnboardingCalls = 0;

  @override
  Future<ProfileData> fetchMe() async {
    fetchMeCalls += 1;
    return const ProfileData(
      id: 'user-me',
      displayName: 'Никита М',
      verified: true,
      online: true,
      age: 28,
      city: 'Москва',
      area: 'Патрики',
      bio: 'bio',
      vibe: 'calm',
      rating: 4.8,
      meetupCount: 12,
      avatarUrl: 'https://cdn.example.com/me.jpg',
      interests: [],
      intent: [],
    );
  }

  @override
  Future<ProfileData> fetchProfile() async {
    fetchProfileCalls += 1;
    throw StateError('profileProvider should not fetch bundled onboarding');
  }

  @override
  Future<OnboardingData> fetchOnboarding() async {
    fetchOnboardingCalls += 1;
    return const OnboardingData(
      intent: 'both',
      gender: 'male',
      birthDate: '1998-01-10',
      city: 'Москва',
      area: 'Патрики',
      interests: ['Кофе', 'Кино'],
      vibe: 'calm',
    );
  }
}

class _ProfileWithFailingOnboardingRepository extends BackendRepository {
  _ProfileWithFailingOnboardingRepository({
    required super.ref,
    required super.dio,
  });

  var fetchMeCalls = 0;
  var fetchOnboardingCalls = 0;

  @override
  Future<ProfileData> fetchMe() async {
    fetchMeCalls += 1;
    return const ProfileData(
      id: 'user-me',
      displayName: 'Никита М',
      verified: true,
      online: true,
      age: 28,
      city: 'Москва',
      area: 'Патрики',
      bio: 'bio',
      vibe: 'calm',
      rating: 4.8,
      meetupCount: 12,
      avatarUrl: 'https://cdn.example.com/me.jpg',
      interests: [],
      intent: [],
    );
  }

  @override
  Future<OnboardingData> fetchOnboarding() async {
    fetchOnboardingCalls += 1;
    throw StateError('onboarding request failed');
  }
}

class _MapEventsRepository extends BackendRepository {
  _MapEventsRepository({
    required super.ref,
    required super.dio,
  });

  String? lastFilter;
  int? lastLimit;
  double? lastLatitude;
  double? lastLongitude;
  double? lastRadiusKm;
  double? lastSouthWestLatitude;
  double? lastSouthWestLongitude;
  double? lastNorthEastLatitude;
  double? lastNorthEastLongitude;

  @override
  Future<PaginatedResponse<Event>> fetchEvents({
    String filter = 'nearby',
    String? q,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? date,
    String? cursor,
    int limit = 20,
    double? latitude,
    double? longitude,
    double? radiusKm,
    double? southWestLatitude,
    double? southWestLongitude,
    double? northEastLatitude,
    double? northEastLongitude,
    CancelToken? cancelToken,
  }) async {
    lastFilter = filter;
    lastLimit = limit;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastRadiusKm = radiusKm;
    lastSouthWestLatitude = southWestLatitude;
    lastSouthWestLongitude = southWestLongitude;
    lastNorthEastLatitude = northEastLatitude;
    lastNorthEastLongitude = northEastLongitude;
    return const PaginatedResponse<Event>(
      items: [],
      nextCursor: null,
    );
  }
}

class _FastScreenDataRepository extends BackendRepository {
  _FastScreenDataRepository({
    required super.ref,
    required super.dio,
  });

  var eventsCalls = 0;
  var meetupChatsCalls = 0;
  var personalChatsCalls = 0;
  var routeTemplatesCalls = 0;

  @override
  Future<PaginatedResponse<Event>> fetchEvents({
    String filter = 'nearby',
    String? q,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? date,
    String? cursor,
    int limit = 20,
    double? latitude,
    double? longitude,
    double? radiusKm,
    double? southWestLatitude,
    double? southWestLongitude,
    double? northEastLatitude,
    double? northEastLongitude,
    CancelToken? cancelToken,
  }) async {
    eventsCalls += 1;
    return const PaginatedResponse<Event>(
      items: [],
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<MeetupChat>> fetchMeetupChats({
    String? cursor,
    int limit = 20,
  }) async {
    meetupChatsCalls += 1;
    return const PaginatedResponse<MeetupChat>(
      items: [],
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<PersonalChat>> fetchPersonalChats({
    String? cursor,
    int limit = 20,
  }) async {
    personalChatsCalls += 1;
    return const PaginatedResponse<PersonalChat>(
      items: [],
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<EveningRouteTemplateSummary>>
      fetchEveningRouteTemplates({
    String city = 'Москва',
    String? q,
    int limit = 20,
  }) async {
    routeTemplatesCalls += 1;
    return const PaginatedResponse<EveningRouteTemplateSummary>(
      items: [],
      nextCursor: null,
    );
  }
}

class _EmptyChatListsRepository extends BackendRepository {
  _EmptyChatListsRepository({
    required super.ref,
    required super.dio,
  });

  @override
  Future<PaginatedResponse<MeetupChat>> fetchMeetupChats({
    String? cursor,
    int limit = 20,
  }) async {
    return const PaginatedResponse<MeetupChat>(
      items: [],
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<PersonalChat>> fetchPersonalChats({
    String? cursor,
    int limit = 20,
  }) async {
    return const PaginatedResponse<PersonalChat>(
      items: [],
      nextCursor: null,
    );
  }
}

class _DelayedMeetupChatsRepository extends BackendRepository {
  _DelayedMeetupChatsRepository({
    required super.ref,
    required super.dio,
    required this.completer,
  });

  final Completer<PaginatedResponse<MeetupChat>> completer;
  var calls = 0;

  @override
  Future<PaginatedResponse<MeetupChat>> fetchMeetupChats({
    String? cursor,
    int limit = 20,
  }) {
    calls += 1;
    return completer.future;
  }
}

class _DelayedEventsRepository extends BackendRepository {
  _DelayedEventsRepository({
    required super.ref,
    required super.dio,
    required this.completer,
  });

  final Completer<PaginatedResponse<Event>> completer;
  var calls = 0;

  @override
  Future<PaginatedResponse<Event>> fetchEvents({
    String filter = 'nearby',
    String? q,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? date,
    String? cursor,
    int limit = 20,
    double? latitude,
    double? longitude,
    double? radiusKm,
    double? southWestLatitude,
    double? southWestLongitude,
    double? northEastLatitude,
    double? northEastLongitude,
    CancelToken? cancelToken,
  }) {
    calls += 1;
    return completer.future;
  }
}

class _DelayedAfficheEventsRepository extends BackendRepository {
  _DelayedAfficheEventsRepository({
    required super.ref,
    required super.dio,
    required this.completer,
  });

  final Completer<PaginatedResponse<AfficheEvent>> completer;
  var calls = 0;

  @override
  Future<PaginatedResponse<AfficheEvent>> fetchAfficheEvents({
    String? city,
    String? q,
    String? date,
    String? priceMode,
    String? source,
    String? category,
    bool? featured,
    String? cursor,
    int limit = 24,
    CancelToken? cancelToken,
  }) {
    calls += 1;
    return completer.future;
  }
}

class _SequencedAfficheEventsRepository extends BackendRepository {
  _SequencedAfficheEventsRepository({
    required super.ref,
    required super.dio,
    required this.completers,
  });

  final List<Completer<PaginatedResponse<AfficheEvent>>> completers;
  var calls = 0;

  @override
  Future<PaginatedResponse<AfficheEvent>> fetchAfficheEvents({
    String? city,
    String? q,
    String? date,
    String? priceMode,
    String? source,
    String? category,
    bool? featured,
    String? cursor,
    int limit = 24,
    CancelToken? cancelToken,
  }) {
    final index = calls;
    calls += 1;
    return completers[index].future;
  }
}

class _DelayedRouteTemplatesCacheRepository extends BackendRepository {
  _DelayedRouteTemplatesCacheRepository({
    required super.ref,
    required super.dio,
    required this.completer,
  });

  final Completer<PaginatedResponse<EveningRouteTemplateSummary>> completer;
  var calls = 0;

  @override
  Future<PaginatedResponse<EveningRouteTemplateSummary>>
      fetchEveningRouteTemplates({
    String city = 'Москва',
    String? q,
    int limit = 20,
  }) {
    calls += 1;
    return completer.future;
  }
}

class _DelayedNotificationsRepository extends BackendRepository {
  _DelayedNotificationsRepository({
    required super.ref,
    required super.dio,
    required this.completer,
  });

  final Completer<PaginatedResponse<NotificationItem>> completer;
  var calls = 0;

  @override
  Future<PaginatedResponse<NotificationItem>> fetchNotifications({
    String? cursor,
    int limit = 20,
  }) {
    calls += 1;
    return completer.future;
  }
}

class _DelayedNotificationUnreadCountRepository extends BackendRepository {
  _DelayedNotificationUnreadCountRepository({
    required super.ref,
    required super.dio,
    required this.completer,
  });

  final Completer<int> completer;
  var calls = 0;

  @override
  Future<int> fetchUnreadNotificationCount() {
    calls += 1;
    return completer.future;
  }
}

class _DelayedProfileCacheRepository extends BackendRepository {
  _DelayedProfileCacheRepository({
    required super.ref,
    required super.dio,
    this.profileCompleter,
    this.onboardingCompleter,
    this.personProfileCompleter,
    this.settingsCompleter,
  });

  final Completer<ProfileData>? profileCompleter;
  final Completer<OnboardingData>? onboardingCompleter;
  final Completer<ProfileData>? personProfileCompleter;
  final Completer<UserSettingsData>? settingsCompleter;
  var profileCalls = 0;
  var onboardingCalls = 0;
  var personProfileCalls = 0;
  var settingsCalls = 0;

  @override
  Future<ProfileData> fetchMe() {
    profileCalls += 1;
    return profileCompleter!.future;
  }

  @override
  Future<OnboardingData> fetchOnboarding() {
    onboardingCalls += 1;
    return onboardingCompleter!.future;
  }

  @override
  Future<ProfileData> fetchPersonProfile(
    String userId, {
    CancelToken? cancelToken,
  }) {
    personProfileCalls += 1;
    return personProfileCompleter!.future;
  }

  @override
  Future<UserSettingsData> fetchSettings() {
    settingsCalls += 1;
    return settingsCompleter!.future;
  }
}

class _DelayedDatingRepository extends BackendRepository {
  _DelayedDatingRepository({
    required super.ref,
    required super.dio,
    required this.discoverCompleter,
    required this.likesCompleter,
  });

  final Completer<PaginatedResponse<DatingProfileData>> discoverCompleter;
  final Completer<PaginatedResponse<DatingProfileData>> likesCompleter;
  var discoverCalls = 0;
  var likesCalls = 0;

  @override
  Future<PaginatedResponse<DatingProfileData>> fetchDatingDiscover({
    String? cursor,
    int limit = 20,
    int? ageMin,
    int? ageMax,
    double? radiusKm,
    List<String> interests = const [],
    CancelToken? cancelToken,
  }) {
    discoverCalls += 1;
    return discoverCompleter.future;
  }

  @override
  Future<PaginatedResponse<DatingProfileData>> fetchDatingLikes({
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) {
    likesCalls += 1;
    return likesCompleter.future;
  }
}

class _DatingPreviewRepository extends BackendRepository {
  _DatingPreviewRepository({
    required super.ref,
    required super.dio,
    this.discoverError,
  });

  final Object? discoverError;
  int? discoverLimit;
  var peopleCalls = 0;

  @override
  Future<PaginatedResponse<DatingProfileData>> fetchDatingDiscover({
    String? cursor,
    int limit = 20,
    int? ageMin,
    int? ageMax,
    double? radiusKm,
    List<String> interests = const [],
    CancelToken? cancelToken,
  }) async {
    discoverLimit = limit;
    final error = discoverError;
    if (error != null) {
      throw error;
    }
    return PaginatedResponse<DatingProfileData>(
      items: List.generate(
        limit,
        (index) => DatingProfileData(
          userId: 'dating-$index',
          name: 'Дейтинг $index',
          age: 28,
          distance: 'Рядом',
          about: '',
          tags: const ['музыка'],
          prompt: '',
          photoEmoji: '💘',
          avatarUrl: null,
          likedYou: false,
          premium: true,
          vibe: 'Спокойно',
          area: 'Центр',
          verified: true,
          online: true,
        ),
      ),
      nextCursor: null,
    );
  }

  @override
  Future<PaginatedResponse<PersonSummary>> fetchPeople({
    String? q,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    peopleCalls += 1;
    return const PaginatedResponse<PersonSummary>(
      items: [],
      nextCursor: null,
    );
  }
}

class _StaticLocationService implements AppLocationService {
  const _StaticLocationService();

  @override
  Future<Position?> getCurrentPosition() async {
    return Position(
      longitude: 37.61,
      latitude: 55.75,
      timestamp: DateTime(2026, 4, 29, 12),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return 0;
  }
}

void main() {
  test('mergeProfileDraftPhotos refreshes avatar from the first merged photo',
      () {
    const profile = ProfileData(
      id: 'user-me',
      displayName: 'Никита М',
      verified: true,
      online: true,
      age: 28,
      city: 'Москва',
      area: 'Чистые пруды',
      bio: 'bio',
      vibe: 'Спокойно',
      rating: 4.8,
      meetupCount: 12,
      avatarUrl: 'https://cdn.example.com/stale.jpg',
      interests: ['Кофе'],
      intent: ['Друзья'],
    );

    const merged = [
      ProfilePhoto(
        id: 'ph1',
        url: 'https://cdn.example.com/ph1.jpg',
        order: 0,
      ),
      ProfilePhoto(
        id: 'ph2',
        url: 'https://cdn.example.com/ph2.jpg',
        order: 1,
      ),
    ];

    final result = mergeProfileDraftPhotos(profile, merged);

    expect(result.photos, merged);
    expect(result.avatarUrl, 'https://cdn.example.com/ph1.jpg');
  });

  test('upsertMeetupChatSummary updates chat preview and moves it to top', () {
    const chats = [
      MeetupChat(
        id: 'mc1',
        eventId: 'e1',
        title: 'Первый чат',
        emoji: '🍷',
        time: '20:00',
        lastMessage: 'Старое сообщение',
        lastAuthor: 'Аня',
        lastTime: '1 ч',
        unread: 2,
        members: ['Аня', 'Ты'],
        status: 'Сегодня',
      ),
      MeetupChat(
        id: 'mc2',
        eventId: 'e2',
        title: 'Второй чат',
        emoji: '♟️',
        time: '19:00',
        lastMessage: 'Привет',
        lastAuthor: 'Паша',
        lastTime: '5 мин',
        unread: 1,
        members: ['Паша', 'Ты'],
        status: 'Сегодня',
      ),
    ];

    final result = upsertMeetupChatSummary(
      chats,
      chatId: 'mc2',
      lastMessage: 'Новое сообщение',
      lastAuthor: 'Ты',
      lastTime: 'сейчас',
      unread: 0,
    );

    expect(result.first.id, 'mc2');
    expect(result.first.lastMessage, 'Новое сообщение');
    expect(result.first.lastAuthor, 'Ты');
    expect(result.first.lastTime, 'сейчас');
    expect(result.first.unread, 0);
  });

  test('upsertMeetupChatSummary keeps pinned meetup chats above updates', () {
    const chats = [
      MeetupChat(
        id: 'mc-pinned',
        eventId: 'e1',
        title: 'Закрепленный',
        emoji: '📌',
        time: '20:00',
        lastMessage: 'Старое сообщение',
        lastAuthor: 'Аня',
        lastTime: '1 ч',
        unread: 0,
        members: ['Аня', 'Ты'],
        status: 'Сегодня',
        isPinned: true,
      ),
      MeetupChat(
        id: 'mc-new',
        eventId: 'e2',
        title: 'Новый',
        emoji: '☕',
        time: '19:00',
        lastMessage: 'Привет',
        lastAuthor: 'Паша',
        lastTime: '5 мин',
        unread: 1,
        members: ['Паша', 'Ты'],
        status: 'Сегодня',
      ),
    ];

    final result = upsertMeetupChatSummary(
      chats,
      chatId: 'mc-new',
      lastMessage: 'Новое сообщение',
      lastAuthor: 'Ты',
      lastTime: 'сейчас',
      unread: 0,
    );

    expect(result.map((chat) => chat.id), ['mc-pinned', 'mc-new']);
  });

  test('sortMeetupChatsByPinned orders each pin group by last message date',
      () {
    final chats = [
      MeetupChat(
        id: 'regular-old',
        eventId: 'e1',
        title: 'Старый',
        emoji: '☕',
        time: '18:00',
        lastMessage: 'Старое',
        lastAuthor: 'Аня',
        lastTime: '1 ч',
        lastMessageAt: DateTime.parse('2026-05-16T09:00:00.000Z'),
        unread: 0,
        members: const ['Аня', 'Ты'],
      ),
      MeetupChat(
        id: 'pinned-old',
        eventId: 'e2',
        title: 'Закрепленный старый',
        emoji: '📌',
        time: '19:00',
        lastMessage: 'Старое',
        lastAuthor: 'Паша',
        lastTime: '2 ч',
        lastMessageAt: DateTime.parse('2026-05-16T08:00:00.000Z'),
        unread: 0,
        members: const ['Паша', 'Ты'],
        isPinned: true,
      ),
      MeetupChat(
        id: 'regular-new',
        eventId: 'e3',
        title: 'Свежий',
        emoji: '🍷',
        time: '20:00',
        lastMessage: 'Новое',
        lastAuthor: 'Соня',
        lastTime: '5 мин',
        lastMessageAt: DateTime.parse('2026-05-16T10:00:00.000Z'),
        unread: 0,
        members: const ['Соня', 'Ты'],
      ),
      MeetupChat(
        id: 'pinned-new',
        eventId: 'e4',
        title: 'Закрепленный свежий',
        emoji: '🎵',
        time: '21:00',
        lastMessage: 'Новое',
        lastAuthor: 'Дима',
        lastTime: 'сейчас',
        lastMessageAt: DateTime.parse('2026-05-16T11:00:00.000Z'),
        unread: 0,
        members: const ['Дима', 'Ты'],
        isPinned: true,
      ),
    ];

    final result = sortMeetupChatsByPinned(chats);

    expect(result.map((chat) => chat.id), [
      'pinned-new',
      'pinned-old',
      'regular-new',
      'regular-old',
    ]);
  });

  test('upsertMeetupChat inserts new chat and keeps existing chats', () {
    const chats = [
      MeetupChat(
        id: 'mc1',
        eventId: 'e1',
        title: 'Первый чат',
        emoji: '🍷',
        time: '20:00',
        lastMessage: 'Старое сообщение',
        lastAuthor: 'Аня',
        lastTime: '1 ч',
        unread: 2,
        members: ['Аня', 'Ты'],
        status: 'Сегодня',
      ),
    ];
    const eveningChat = MeetupChat(
      id: 'evening-chat-new',
      eventId: null,
      title: 'Теплый круг',
      emoji: '🍇',
      time: '19:00',
      lastMessage: 'Вечер опубликован',
      lastAuthor: 'Frendly',
      lastTime: 'сейчас',
      unread: 0,
      members: ['Ты'],
      phase: MeetupPhase.soon,
      routeId: 'r-cozy-circle',
      sessionId: 'session-new',
      hostUserId: 'user-me',
    );

    final result = upsertMeetupChat(chats, eveningChat);

    expect(result, hasLength(2));
    expect(result.first.id, 'evening-chat-new');
    expect(result.last.id, 'mc1');
  });

  test('updateMeetupChatFromRealtime keeps paid ticket summary', () {
    const chats = [
      MeetupChat(
        id: 'mc-ticket',
        eventId: 'event-affiche',
        title: 'Концерт',
        emoji: '🎟',
        time: '20:00',
        lastMessage: 'Собираемся',
        lastAuthor: 'Аня',
        lastTime: 'сейчас',
        unread: 0,
        members: ['Ты', 'Аня'],
        status: 'Сегодня',
        phase: MeetupPhase.soon,
        ticketUrl: 'https://tickets.example/affiche',
        ticketSourceKind: MeetupChatTicketSourceKind.affiche,
        ticketSourceId: 'affiche-1',
        ticketPriceFrom: 1500,
        ticketProvider: 'KudaGo',
        ticketVenue: 'Клуб',
      ),
    ];

    final result = updateMeetupChatFromRealtime(
      chats,
      chatId: 'mc-ticket',
      phase: MeetupPhase.live,
      hasCurrentPlace: true,
      currentPlace: 'Клуб',
    );

    final chat = result.single;
    expect(chat.phase, MeetupPhase.live);
    expect(chat.currentPlace, 'Клуб');
    expect(chat.ticketUrl, 'https://tickets.example/affiche');
    expect(chat.ticketSourceKind, MeetupChatTicketSourceKind.affiche);
    expect(chat.ticketSourceId, 'affiche-1');
    expect(chat.ticketPriceFrom, 1500);
    expect(chat.ticketProvider, 'KudaGo');
    expect(chat.ticketVenue, 'Клуб');
    expect(chat.hasPaidTicket, isTrue);
  });

  test('upsertPersonalChatSummary updates preview and moves chat to top', () {
    const chats = [
      PersonalChat(
        id: 'p1',
        name: 'Аня',
        lastMessage: 'Старое',
        lastTime: 'вчера',
        unread: 3,
        online: true,
      ),
      PersonalChat(
        id: 'p2',
        name: 'Соня',
        lastMessage: 'Привет',
        lastTime: '5 мин',
        unread: 1,
        online: false,
      ),
    ];

    final result = upsertPersonalChatSummary(
      chats,
      chatId: 'p1',
      lastMessage: 'Голосовое сообщение',
      lastTime: 'сейчас',
      unread: 0,
    );

    expect(result.first.id, 'p1');
    expect(result.first.lastMessage, 'Голосовое сообщение');
    expect(result.first.lastTime, 'сейчас');
    expect(result.first.unread, 0);
  });

  test('upsertPersonalChatSummary keeps pinned personal chats above updates',
      () {
    const chats = [
      PersonalChat(
        id: 'p-pinned',
        name: 'Аня',
        lastMessage: 'Старое',
        lastTime: 'вчера',
        unread: 0,
        online: true,
        isPinned: true,
      ),
      PersonalChat(
        id: 'p-new',
        name: 'Соня',
        lastMessage: 'Привет',
        lastTime: '5 мин',
        unread: 1,
        online: false,
      ),
    ];

    final result = upsertPersonalChatSummary(
      chats,
      chatId: 'p-new',
      lastMessage: 'Голосовое сообщение',
      lastTime: 'сейчас',
      unread: 0,
    );

    expect(result.map((chat) => chat.id), ['p-pinned', 'p-new']);
  });

  test('sortPersonalChatsByPinned orders each pin group by last message date',
      () {
    final chats = [
      PersonalChat(
        id: 'regular-old',
        name: 'Аня',
        lastMessage: 'Старое',
        lastTime: '1 ч',
        lastMessageAt: DateTime.parse('2026-05-16T09:00:00.000Z'),
        unread: 0,
        online: false,
      ),
      PersonalChat(
        id: 'pinned-old',
        name: 'Паша',
        lastMessage: 'Старое',
        lastTime: '2 ч',
        lastMessageAt: DateTime.parse('2026-05-16T08:00:00.000Z'),
        unread: 0,
        online: false,
        isPinned: true,
      ),
      PersonalChat(
        id: 'regular-new',
        name: 'Соня',
        lastMessage: 'Новое',
        lastTime: '5 мин',
        lastMessageAt: DateTime.parse('2026-05-16T10:00:00.000Z'),
        unread: 0,
        online: true,
      ),
      PersonalChat(
        id: 'pinned-new',
        name: 'Дима',
        lastMessage: 'Новое',
        lastTime: 'сейчас',
        lastMessageAt: DateTime.parse('2026-05-16T11:00:00.000Z'),
        unread: 0,
        online: true,
        isPinned: true,
      ),
    ];

    final result = sortPersonalChatsByPinned(chats);

    expect(result.map((chat) => chat.id), [
      'pinned-new',
      'pinned-old',
      'regular-new',
      'regular-old',
    ]);
  });

  test('mapEventsProvider requests a bounded map page', () async {
    _MapEventsRepository? repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _MapEventsRepository(ref: ref, dio: Dio());
          return repository!;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(
      mapEventsProvider(
        const MapEventsQuery(
          centerLatitude: 55.75,
          centerLongitude: 37.61,
          radiusKm: 4,
          southWestLatitude: 55.70,
          southWestLongitude: 37.50,
          northEastLatitude: 55.80,
          northEastLongitude: 37.70,
        ),
      ).future,
    );

    expect(repository, isNotNull);
    expect(repository!.lastFilter, 'nearby');
    expect(repository!.lastLimit, 50);
    expect(repository!.lastLatitude, 55.75);
    expect(repository!.lastLongitude, 37.61);
    expect(repository!.lastRadiusKm, 4);
    expect(repository!.lastSouthWestLatitude, 55.70);
    expect(repository!.lastSouthWestLongitude, 37.50);
    expect(repository!.lastNorthEastLatitude, 55.80);
    expect(repository!.lastNorthEastLongitude, 37.70);
  });

  test('eventsProvider sends current location for nearby feed', () async {
    _MapEventsRepository? repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        appLocationServiceProvider.overrideWith(
          (ref) => const _StaticLocationService(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _MapEventsRepository(ref: ref, dio: Dio());
          return repository!;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(eventsProvider('nearby').future);

    expect(repository, isNotNull);
    expect(repository!.lastFilter, 'nearby');
    expect(repository!.lastLatitude, 55.75);
    expect(repository!.lastLongitude, 37.61);
    expect(repository!.lastRadiusKm, 50);
  });

  test('eventsProvider prefers manual location for nearby feed', () async {
    _MapEventsRepository? repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        appLocationServiceProvider.overrideWith(
          (ref) => const _StaticLocationService(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _MapEventsRepository(ref: ref, dio: Dio());
          return repository!;
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(manualLocationProvider.notifier).setLocation(
          const ManualLocation(
            label: 'Москва - Покровка',
            latitude: 55.757,
            longitude: 37.648,
          ),
        );

    await container.read(eventsProvider('nearby').future);

    expect(repository, isNotNull);
    expect(repository!.lastFilter, 'nearby');
    expect(repository!.lastLatitude, 55.757);
    expect(repository!.lastLongitude, 37.648);
    expect(repository!.lastRadiusKm, 50);
  });

  test('datingHomePreviewProvider requests compact dating discover page',
      () async {
    _DatingPreviewRepository? repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DatingPreviewRepository(ref: ref, dio: Dio());
          return repository!;
        }),
      ],
    );
    addTearDown(container.dispose);

    final items = await container.read(datingHomePreviewProvider.future);

    expect(repository, isNotNull);
    expect(repository!.discoverLimit, 4);
    expect(items, hasLength(4));
  });

  test('datingHomePreviewProvider does not fall back to people after error',
      () async {
    _DatingPreviewRepository? repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DatingPreviewRepository(
            ref: ref,
            dio: Dio(),
            discoverError: StateError('discover failed'),
          );
          return repository!;
        }),
      ],
    );
    addTearDown(container.dispose);

    final items = await container.read(datingHomePreviewProvider.future);

    expect(items, isEmpty);
    expect(repository, isNotNull);
    expect(repository!.discoverLimit, 4);
    expect(repository!.peopleCalls, 0);
  });

  test('eventsProvider uses Saint Petersburg manual location coordinates',
      () async {
    _MapEventsRepository? repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        appLocationServiceProvider.overrideWith(
          (ref) => const _StaticLocationService(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _MapEventsRepository(ref: ref, dio: Dio());
          return repository!;
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(manualLocationProvider.notifier).setLocation(
          const ManualLocation(
            label: 'Санкт-Петербург',
            city: 'Санкт-Петербург',
            latitude: 59.9386,
            longitude: 30.3141,
          ),
        );

    await container.read(eventsProvider('nearby').future);

    expect(repository, isNotNull);
    expect(repository!.lastFilter, 'nearby');
    expect(repository!.lastLatitude, 59.9386);
    expect(repository!.lastLongitude, 30.3141);
    expect(repository!.lastRadiusKm, 50);
  });

  test(
      'chatRealtimeSyncProvider subscribes chat ids and applies typing and unread updates',
      () async {
    final socket = _FakeGlobalChatSocketClient();
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        chatSocketClientProvider.overrideWith((ref) => socket),
        meetupChatsLocalStateProvider.overrideWith(
          (ref) => const [
            MeetupChat(
              id: 'mc1',
              eventId: 'e1',
              title: 'Встреча',
              emoji: '🍷',
              time: '20:00',
              lastMessage: 'Привет',
              lastAuthor: 'Аня',
              lastTime: '1 мин',
              unread: 1,
              members: ['Аня', 'Ты'],
              status: 'Сегодня',
            ),
          ],
        ),
        personalChatsLocalStateProvider.overrideWith(
          (ref) => const [
            PersonalChat(
              id: 'p1',
              name: 'Соня',
              lastMessage: 'Привет',
              lastTime: '2 мин',
              unread: 1,
              online: true,
            ),
          ],
        ),
      ],
    );
    addTearDown(() async {
      await socket.dispose();
      container.dispose();
    });

    container.read(chatRealtimeSyncProvider);
    await container.read(meetupChatsProvider.future);
    await container.read(personalChatsProvider.future);
    await _drain();

    expect(socket.subscribedChatIds, containsAll(<String>['mc1', 'p1']));

    socket.emit({
      'type': 'typing.changed',
      'payload': {
        'chatId': 'mc1',
        'isTyping': true,
      },
    });
    socket.emit({
      'type': 'unread.updated',
      'payload': {
        'chatId': 'p1',
        'unreadCount': 4,
      },
    });
    await _drain();

    final meetupChats = container.read(meetupChatsProvider).valueOrNull;
    final personalChats = container.read(personalChatsProvider).valueOrNull;

    expect(meetupChats?.single.typing, true);
    expect(personalChats?.single.unread, 4);
  });

  test('chatRealtimeSyncProvider applies evening chat phase updates', () async {
    final socket = _FakeGlobalChatSocketClient();
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        chatSocketClientProvider.overrideWith((ref) => socket),
        meetupChatsLocalStateProvider.overrideWith(
          (ref) => const [
            MeetupChat(
              id: 'evening-chat-1',
              eventId: null,
              title: 'Теплый круг',
              emoji: '🍷',
              time: '19:00',
              lastMessage: 'Собираемся',
              lastAuthor: 'Frendly',
              lastTime: 'сейчас',
              unread: 0,
              members: ['Ты', 'Аня'],
              phase: MeetupPhase.soon,
              routeId: 'r-cozy-circle',
              sessionId: 'session-1',
              totalSteps: 2,
            ),
          ],
        ),
        personalChatsLocalStateProvider.overrideWith(
          (ref) => const <PersonalChat>[],
        ),
        eveningSessionsProvider.overrideWith((ref) async => const []),
        eveningSessionProvider('session-1').overrideWith(
          (ref) async => const EveningSessionDetail(
            id: 'session-1',
            routeId: 'r-cozy-circle',
            chatId: 'evening-chat-1',
            phase: EveningSessionPhase.live,
            chatPhase: MeetupPhase.live,
            privacy: EveningPrivacy.open,
            title: 'Теплый круг',
            vibe: 'Камерно',
            emoji: '🍷',
            participants: [],
            steps: [],
          ),
        ),
      ],
    );
    addTearDown(() async {
      await socket.dispose();
      container.dispose();
    });

    container.read(chatRealtimeSyncProvider);
    await container.read(meetupChatsProvider.future);
    await _drain();

    socket.emit({
      'type': 'chat.updated',
      'payload': {
        'chatId': 'evening-chat-1',
        'sessionId': 'session-1',
        'phase': 'live',
        'currentStep': 1,
        'totalSteps': 2,
        'currentPlace': 'Brix Wine',
        'endTime': '20:15',
      },
    });
    await _drain();

    final chat = container.read(meetupChatsProvider).valueOrNull?.single;
    expect(chat?.phase, MeetupPhase.live);
    expect(chat?.currentStep, 1);
    expect(chat?.currentPlace, 'Brix Wine');
    expect(chat?.endTime, '20:15');
  });

  test('chatRealtimeSyncProvider clears stale meetup override for unknown chat',
      () async {
    final socket = _FakeGlobalChatSocketClient();
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        chatSocketClientProvider.overrideWith((ref) => socket),
        backendRepositoryProvider.overrideWith(
          (ref) => _EmptyChatListsRepository(ref: ref, dio: Dio()),
        ),
        meetupChatsLocalStateProvider.overrideWith(
          (ref) => const <MeetupChat>[],
        ),
        personalChatsLocalStateProvider.overrideWith(
          (ref) => const <PersonalChat>[],
        ),
        eveningSessionsProvider.overrideWith((ref) async => const []),
        eveningSessionProvider('session-new').overrideWith(
          (ref) async => const EveningSessionDetail(
            id: 'session-new',
            routeId: 'r-cozy-circle',
            chatId: 'evening-chat-new',
            phase: EveningSessionPhase.scheduled,
            chatPhase: MeetupPhase.soon,
            privacy: EveningPrivacy.open,
            title: 'Теплый круг',
            vibe: 'Камерно',
            emoji: '🍷',
            participants: [],
            steps: [],
          ),
        ),
      ],
    );
    addTearDown(() async {
      await socket.dispose();
      container.dispose();
    });

    container.read(chatRealtimeSyncProvider);
    await container.read(meetupChatsProvider.future);
    await _drain();

    socket.emit({
      'type': 'chat.updated',
      'payload': {
        'chatId': 'evening-chat-new',
        'sessionId': 'session-new',
        'phase': 'soon',
      },
    });
    await _drain();

    expect(container.read(meetupChatsLocalStateProvider), isNull);
  });

  test(
      'chatRealtimeSyncProvider invalidates evening detail from notification payload',
      () async {
    final socket = _FakeGlobalChatSocketClient();
    var detailLoads = 0;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        chatSocketClientProvider.overrideWith((ref) => socket),
        meetupChatsLocalStateProvider.overrideWith(
          (ref) => const [
            MeetupChat(
              id: 'evening-chat-1',
              eventId: null,
              title: 'Теплый круг',
              emoji: '🍷',
              time: '19:00',
              lastMessage: 'Собираемся',
              lastAuthor: 'Frendly',
              lastTime: 'сейчас',
              unread: 0,
              members: ['Ты'],
              phase: MeetupPhase.soon,
              routeId: 'r-cozy-circle',
              sessionId: 'session-1',
            ),
          ],
        ),
        personalChatsLocalStateProvider.overrideWith(
          (ref) => const <PersonalChat>[],
        ),
        notificationsLocalStateProvider.overrideWith(
          (ref) => const <NotificationItem>[],
        ),
        notificationUnreadCountProvider.overrideWith((ref) async => 0),
        eveningSessionsProvider.overrideWith((ref) async => const []),
        eveningSessionProvider('session-1').overrideWith((ref) async {
          detailLoads += 1;
          return const EveningSessionDetail(
            id: 'session-1',
            routeId: 'r-cozy-circle',
            chatId: 'evening-chat-1',
            phase: EveningSessionPhase.scheduled,
            chatPhase: MeetupPhase.soon,
            privacy: EveningPrivacy.request,
            title: 'Теплый круг',
            vibe: 'Камерно',
            emoji: '🍷',
            participants: [],
            steps: [],
          );
        }),
      ],
    );
    addTearDown(() async {
      await socket.dispose();
      container.dispose();
    });

    container.read(chatRealtimeSyncProvider);
    await container.read(meetupChatsProvider.future);
    await container.read(eveningSessionProvider('session-1').future);
    expect(detailLoads, 1);

    socket.emit({
      'type': 'notification.created',
      'payload': {
        'notificationId': 'n-evening-request',
        'kind': 'event_joined',
        'title': 'Новая заявка',
        'body': 'Новая заявка на вечер',
        'createdAt': '2026-04-26T12:00:00Z',
        'payload': {
          'sessionId': 'session-1',
          'requestId': 'request-1',
        },
      },
    });
    await _drain();
    await container.read(eveningSessionProvider('session-1').future);

    expect(detailLoads, 2);
  });

  test(
      'chatRealtimeSyncProvider updates personal preview, badge and local notifications from realtime event',
      () async {
    final socket = _FakeGlobalChatSocketClient();
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        chatSocketClientProvider.overrideWith((ref) => socket),
        personalChatsLocalStateProvider.overrideWith(
          (ref) => const [
            PersonalChat(
              id: 'p1',
              name: 'Соня',
              lastMessage: 'Старое',
              lastTime: 'вчера',
              unread: 1,
              online: true,
            ),
            PersonalChat(
              id: 'p2',
              name: 'Аня',
              lastMessage: 'Текст',
              lastTime: '5 мин',
              unread: 0,
              online: false,
            ),
          ],
        ),
        meetupChatsLocalStateProvider.overrideWith(
          (ref) => const <MeetupChat>[],
        ),
        notificationsLocalStateProvider.overrideWith(
          (ref) => [
            NotificationItem(
              id: 'n1',
              kind: 'message',
              title: 'Новое сообщение',
              body: 'Старое уведомление',
              payload: {'chatId': 'p1'},
              readAt: null,
              createdAt: DateTime(2026, 4, 21, 11, 0),
            ),
          ],
        ),
        notificationUnreadCountProvider.overrideWith((ref) async => 2),
      ],
    );
    addTearDown(() async {
      await socket.dispose();
      container.dispose();
    });

    container.read(chatRealtimeSyncProvider);
    await container.read(personalChatsProvider.future);
    await container.read(notificationUnreadCountProvider.future);
    await _drain();

    socket.emit({
      'type': 'message.created',
      'payload': {
        'id': 'm-voice',
        'chatId': 'p2',
        'clientMessageId': 'client-m-voice',
        'senderId': 'user-anya',
        'senderName': 'Аня',
        'text': '',
        'createdAt': '2026-04-21T12:20:00Z',
        'attachments': [
          {
            'id': 'a-voice',
            'kind': 'chat_voice',
            'status': 'ready',
            'url': 'https://example.com/voice.m4a',
            'mimeType': 'audio/mp4',
            'byteSize': 1234,
            'fileName': 'voice.m4a',
            'durationMs': 7000,
          },
        ],
      },
    });
    socket.emit({
      'type': 'notification.created',
      'payload': {
        'userId': 'user-me',
        'notificationId': 'n100',
        'kind': 'message',
        'title': 'Новое сообщение',
        'body': 'Аня: Голосовое сообщение',
        'payload': {
          'chatId': 'p2',
          'messageId': 'm-voice',
        },
        'createdAt': '2026-04-21T12:20:00Z',
        'readAt': null,
      },
    });
    await _drain();

    final personalChats = container.read(personalChatsProvider).valueOrNull;
    expect(personalChats?.first.id, 'p2');
    expect(personalChats?.first.lastMessage, 'Голосовое сообщение');
    expect(
      container.read(notificationUnreadCountOverrideProvider),
      3,
    );
    final notifications = container.read(notificationsLocalStateProvider);
    expect(notifications?.first.id, 'n100');
    expect(notifications?.first.body, 'Аня: Голосовое сообщение');
    expect(notifications?.first.payload['chatId'], 'p2');
  });

  test(
      'chatRealtimeSyncProvider preserves fresh unread state when preview follows unread update',
      () async {
    final socket = _FakeGlobalChatSocketClient();
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        chatSocketClientProvider.overrideWith((ref) => socket),
        personalChatsLocalStateProvider.overrideWith(
          (ref) => const [
            PersonalChat(
              id: 'p1',
              name: 'Соня',
              lastMessage: 'Старое',
              lastTime: 'вчера',
              unread: 1,
              online: true,
            ),
          ],
        ),
        meetupChatsLocalStateProvider.overrideWith(
          (ref) => const <MeetupChat>[],
        ),
      ],
    );
    addTearDown(() async {
      await socket.dispose();
      container.dispose();
    });

    container.read(chatRealtimeSyncProvider);
    await container.read(personalChatsProvider.future);
    await _drain();

    socket.emit({
      'type': 'unread.updated',
      'payload': {
        'chatId': 'p1',
        'unreadCount': 4,
      },
    });
    socket.emit({
      'type': 'message.created',
      'payload': {
        'id': 'm-new',
        'chatId': 'p1',
        'clientMessageId': 'client-m-new',
        'senderId': 'user-sonya',
        'senderName': 'Соня',
        'text': 'Новое',
        'createdAt': '2026-04-21T12:20:00Z',
        'attachments': const [],
      },
    });
    await _drain();

    final personalChats = container.read(personalChatsProvider).valueOrNull;
    expect(personalChats?.single.lastMessage, 'Новое');
    expect(personalChats?.single.unread, 4);
  });

  test('chat lists stay empty without auth instead of calling backend',
      () async {
    var repositoryBuilt = false;
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWith(
          (ref) {
            repositoryBuilt = true;
            return _ChatsShouldNotLoadWithoutAuthRepository(
              ref: ref,
              dio: Dio(),
            );
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final meetupChats = await container.read(meetupChatsProvider.future);
    final personalChats = await container.read(personalChatsProvider.future);

    expect(meetupChats, isEmpty);
    expect(personalChats, isEmpty);
    expect(repositoryBuilt, isFalse);
  });

  test('meetup chat list returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = ChatLocalStore(db);
    await store.upsertSummary(
      userScope: AppCacheUserScope.user('user-me'),
      kind: ChatSummaryKind.meetup,
      chatId: 'mc1',
      summaryJson: {
        'id': 'mc1',
        'eventId': 'e1',
        'title': 'Cached chat',
        'emoji': '🍷',
        'time': '20:00',
        'lastMessage': 'cached',
        'lastAuthor': 'Аня',
        'lastTime': '1 мин',
        'unread': 1,
        'members': ['Аня', 'Ты'],
      },
      updatedAt: DateTime.utc(2026, 5, 14, 10),
    );

    final completer = Completer<PaginatedResponse<MeetupChat>>();
    late _DelayedMeetupChatsRepository repository;
    final container = ProviderContainer(
      overrides: [
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        chatLocalStoreProvider.overrideWithValue(store),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedMeetupChatsRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final cached = await container
        .read(meetupChatsProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(cached.single.title, 'Cached chat');
    expect(repository.calls, 1);

    completer.complete(
      const PaginatedResponse<MeetupChat>(
        items: [
          MeetupChat(
            id: 'mc1',
            eventId: 'e1',
            title: 'Network chat',
            emoji: '🍷',
            time: '20:00',
            lastMessage: 'network',
            lastAuthor: 'Аня',
            lastTime: 'сейчас',
            unread: 0,
            members: ['Аня', 'Ты'],
          ),
        ],
        nextCursor: null,
      ),
    );
    await _drain();

    expect(
      container.read(meetupChatsLocalStateProvider)?.single.title,
      'Network chat',
    );
  });

  test('eventsProvider returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.meetups,
      cacheKey: AppCacheKey.build(
        path: '/events',
        query: const {'filter': 'now'},
      ),
      payloadJson: jsonEncode([
        {
          'id': 'event-cached',
          'title': 'Cached event',
          'emoji': '🍷',
          'time': '20:00',
          'place': 'Brix',
          'distance': '1 км',
          'attendees': ['Аня'],
          'going': 4,
          'capacity': 8,
          'vibe': 'calm',
          'tone': 'warm',
          'joined': false,
        },
      ]),
      policy: AppCachePolicies.meetups,
    );

    final completer = Completer<PaginatedResponse<Event>>();
    late _DelayedEventsRepository repository;
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedEventsRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final events = await container
        .read(eventsProvider('now').future)
        .timeout(const Duration(milliseconds: 100));

    expect(events.single.title, 'Cached event');
    expect(repository.calls, 1);
  });

  test('eventsProvider fetches network when local cache cannot decode',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.meetups,
      cacheKey: AppCacheKey.build(
        path: '/events',
        query: const {'filter': 'now'},
      ),
      payloadJson: jsonEncode([
        {
          'id': 'event-stale',
        },
      ]),
      policy: AppCachePolicies.meetups,
    );

    final completer = Completer<PaginatedResponse<Event>>();
    late _DelayedEventsRepository repository;
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedEventsRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final future = container.read(eventsProvider('now').future);
    completer.complete(
      PaginatedResponse<Event>(
        items: [
          Event.fromJson(
            {
              'id': 'event-network',
              'title': 'Network event',
              'emoji': '🎟',
              'time': '21:00',
              'place': 'Mars',
              'distance': '2 км',
              'attendees': ['Лиза'],
              'going': 2,
              'capacity': 8,
              'vibe': 'active',
              'tone': 'warm',
              'joined': false,
            },
          ),
        ],
        nextCursor: null,
      ),
    );

    final events = await future;
    expect(events.single.title, 'Network event');
    expect(repository.calls, 1);
  });

  test('events force refresh bypasses local cache and waits for network',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.meetups,
      cacheKey: AppCacheKey.build(
        path: '/events',
        query: const {'filter': 'now'},
      ),
      payloadJson: jsonEncode([
        {
          'id': 'event-cached',
          'title': 'Cached event',
          'emoji': '🍷',
          'time': '20:00',
          'place': 'Brix',
          'distance': '1 км',
          'attendees': ['Аня'],
          'going': 4,
          'capacity': 8,
          'vibe': 'calm',
          'tone': 'warm',
          'joined': false,
        },
      ]),
      policy: AppCachePolicies.meetups,
    );

    final completer = Completer<PaginatedResponse<Event>>();
    late _DelayedEventsRepository repository;
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedEventsRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final refresh = container.read(eventsForceRefreshProvider('now').future);
    await expectLater(
      refresh.timeout(const Duration(milliseconds: 100)),
      throwsA(isA<TimeoutException>()),
    );

    completer.complete(
      PaginatedResponse<Event>(
        items: [
          Event.fromJson(
            {
              'id': 'event-network',
              'title': 'Network event',
              'emoji': '🎟',
              'time': '21:00',
              'place': 'Mars',
              'distance': '2 км',
              'attendees': ['Лиза'],
              'going': 2,
              'capacity': 8,
              'vibe': 'active',
              'tone': 'warm',
              'joined': false,
            },
          ),
        ],
        nextCursor: null,
      ),
    );

    final events = await refresh;
    expect(events.single.title, 'Network event');
    expect(repository.calls, 1);
  });

  test('afficheEventsProvider returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    const query = AfficheEventsQuery(city: 'Москва', limit: 12);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.affiche,
      cacheKey: AppCacheKey.build(
        path: '/affiche/events',
        query: const {
          'city': 'Москва',
          'priceMode': 'any',
          'limit': 12,
        },
      ),
      payloadJson: jsonEncode({
        'items': [_cachedAfficheJson()],
        'nextCursor': 'next-page',
      }),
      policy: AppCachePolicies.affiche,
    );

    final completer = Completer<PaginatedResponse<AfficheEvent>>();
    late _DelayedAfficheEventsRepository repository;
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedAfficheEventsRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final events = await container
        .read(afficheEventsProvider(query).future)
        .timeout(const Duration(milliseconds: 100));

    expect(events.single.title, 'Cached affiche');
    expect(repository.calls, 1);
  });

  test('afficheEventsPagedProvider returns first page cache before refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    const query = AfficheEventsQuery(city: 'Москва', limit: 12);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.affiche,
      cacheKey: AppCacheKey.build(
        path: '/affiche/events',
        query: const {
          'city': 'Москва',
          'priceMode': 'any',
          'limit': 12,
        },
      ),
      payloadJson: jsonEncode({
        'items': [_cachedAfficheJson()],
        'nextCursor': 'next-page',
      }),
      policy: AppCachePolicies.affiche,
    );

    final completer = Completer<PaginatedResponse<AfficheEvent>>();
    late _DelayedAfficheEventsRepository repository;
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedAfficheEventsRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final page = await _readAfficheFirstPage(container, query)
        .timeout(const Duration(milliseconds: 100));

    expect(page.items.single.title, 'Cached affiche');
    expect(page.nextCursor, 'next-page');
    expect(repository.calls, 1);
  });

  test('afficheEventsPagedProvider keeps current page during refresh',
      () async {
    final firstCompleter = Completer<PaginatedResponse<AfficheEvent>>();
    final refreshCompleter = Completer<PaginatedResponse<AfficheEvent>>();
    late _SequencedAfficheEventsRepository repository;
    const query = AfficheEventsQuery(city: 'Москва', limit: 12);
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWith((ref) {
          repository = _SequencedAfficheEventsRepository(
            ref: ref,
            dio: Dio(),
            completers: [firstCompleter, refreshCompleter],
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(afficheEventsPagedProvider(query));
    firstCompleter.complete(
      PaginatedResponse<AfficheEvent>(
        items: [AfficheEvent.fromJson(_cachedAfficheJson())],
        nextCursor: null,
      ),
    );
    final firstPage = await _readAfficheFirstPage(container, query);

    unawaited(
      container
          .read(afficheEventsPagedProvider(query).notifier)
          .loadFirstPage(forceRefresh: true),
    );
    await _drain();

    final refreshingPage =
        container.read(afficheEventsPagedProvider(query)).valueOrNull;
    expect(firstPage.items.single.title, 'Cached affiche');
    expect(refreshingPage?.items.single.title, 'Cached affiche');
    expect(repository.calls, 2);

    refreshCompleter.complete(
      PaginatedResponse<AfficheEvent>(
        items: [
          AfficheEvent.fromJson(
            {
              ..._cachedAfficheJson(),
              'id': 'affiche-network',
              'title': 'Network affiche',
            },
          ),
        ],
        nextCursor: null,
      ),
    );
    await _drain();

    final refreshedPage = await _readAfficheFirstPage(container, query);
    expect(refreshedPage.items.single.title, 'Network affiche');
  });

  test('route catalog returns local cache before background refresh', () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.routeTemplates,
      cacheKey: AppCacheKey.build(
        path: '/evening/route-templates',
        query: const {
          'city': 'Москва',
          'limit': 20,
        },
      ),
      payloadJson: jsonEncode([
        {
          'id': 'template-cached',
          'routeId': 'route-cached',
          'title': 'Cached route',
          'blurb': 'cached',
          'city': 'Москва',
          'vibe': 'calm',
          'budget': '2500 ₽',
          'durationLabel': '2 часа',
          'totalPriceFrom': 2500,
          'stepsPreview': [],
          'partnerOffersPreview': [],
          'nearestSessions': [],
        },
      ]),
      policy: AppCachePolicies.routeTemplates,
    );

    final completer =
        Completer<PaginatedResponse<EveningRouteTemplateSummary>>();
    late _DelayedRouteTemplatesCacheRepository repository;
    final container = ProviderContainer(
      overrides: [
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedRouteTemplatesCacheRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final routes = await container
        .read(eveningRouteTemplatesProvider('Москва').future)
        .timeout(const Duration(milliseconds: 100));

    expect(routes.single.title, 'Cached route');
    expect(repository.calls, 1);
  });

  test('route catalog keeps local cache when background refresh fails',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.routeTemplates,
      cacheKey: AppCacheKey.build(
        path: '/evening/route-templates',
        query: const {
          'city': 'Москва',
          'limit': 20,
        },
      ),
      payloadJson: jsonEncode([
        {
          'id': 'template-cached',
          'routeId': 'route-cached',
          'title': 'Cached route',
          'blurb': 'cached',
          'city': 'Москва',
          'vibe': 'calm',
          'budget': '2500 ₽',
          'durationLabel': '2 часа',
          'totalPriceFrom': 2500,
          'stepsPreview': [],
          'partnerOffersPreview': [],
          'nearestSessions': [],
        },
      ]),
      policy: AppCachePolicies.routeTemplates,
    );

    late _RouteTemplatesRepository repository;
    final container = ProviderContainer(
      overrides: [
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _RouteTemplatesRepository(
            ref: ref,
            dio: Dio(),
            error: StateError('route template request failed'),
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final routes = await container.read(
      eveningRouteTemplatesProvider('Москва').future,
    );

    expect(routes.single.title, 'Cached route');
    expect(repository.templateCalls, 1);
  });

  test('notificationsProvider returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.notifications,
      cacheKey: AppCacheKey.build(
        path: '/notifications',
        query: const {'limit': 20},
      ),
      payloadJson: jsonEncode([
        {
          'id': 'notification-cached',
          'kind': 'message',
          'title': 'Cached notification',
          'body': 'cached',
          'payload': {'chatId': 'chat-1'},
          'readAt': null,
          'createdAt': '2026-05-14T10:00:00.000Z',
        },
      ]),
      policy: AppCachePolicies.notifications,
    );

    final completer = Completer<PaginatedResponse<NotificationItem>>();
    late _DelayedNotificationsRepository repository;
    final container = ProviderContainer(
      overrides: [
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedNotificationsRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final notifications = await container
        .read(notificationsProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(notifications.single.title, 'Cached notification');
    expect(repository.calls, 1);
  });

  test(
      'notification unread count returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.notifications,
      cacheKey: AppCacheKey.build(path: '/notifications/unread-count'),
      payloadJson: jsonEncode(7),
      policy: AppCachePolicies.notifications,
    );

    final completer = Completer<int>();
    late _DelayedNotificationUnreadCountRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedNotificationUnreadCountRepository(
            ref: ref,
            dio: Dio(),
            completer: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final count = await container
        .read(notificationUnreadCountProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(count, 7);
    expect(repository.calls, 1);
  });

  test('onboardingProvider returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.profile,
      cacheKey: AppCacheKey.build(path: '/onboarding/me'),
      payloadJson: jsonEncode(_cachedOnboardingJson()),
      policy: AppCachePolicies.profile,
    );

    final completer = Completer<OnboardingData>();
    late _DelayedProfileCacheRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedProfileCacheRepository(
            ref: ref,
            dio: Dio(),
            onboardingCompleter: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final onboarding = await container
        .read(onboardingProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(onboarding.city, 'Москва');
    expect(onboarding.area, 'Патрики');
    expect(repository.onboardingCalls, 1);
  });

  test('profileProvider returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.profile,
      cacheKey: AppCacheKey.build(path: '/profile/me'),
      payloadJson: jsonEncode(_cachedProfileJson(id: 'user-me')),
      policy: AppCachePolicies.profile,
    );
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.profile,
      cacheKey: AppCacheKey.build(path: '/onboarding/me'),
      payloadJson: jsonEncode(_cachedOnboardingJson()),
      policy: AppCachePolicies.profile,
    );

    final profileCompleter = Completer<ProfileData>();
    final onboardingCompleter = Completer<OnboardingData>();
    late _DelayedProfileCacheRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedProfileCacheRepository(
            ref: ref,
            dio: Dio(),
            profileCompleter: profileCompleter,
            onboardingCompleter: onboardingCompleter,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container
        .read(profileProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(profile.displayName, 'Cached profile');
    expect(profile.interests, ['Кофе', 'Кино']);
    expect(repository.profileCalls, 1);
    expect(repository.onboardingCalls, 1);
  });

  test('personProfileProvider returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.publicProfile,
      cacheKey: AppCacheKey.build(path: '/people/person-cached'),
      payloadJson: jsonEncode(
        _cachedProfileJson(
          id: 'person-cached',
          displayName: 'Cached person',
        ),
      ),
      policy: AppCachePolicies.publicProfile,
    );

    final completer = Completer<ProfileData>();
    late _DelayedProfileCacheRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedProfileCacheRepository(
            ref: ref,
            dio: Dio(),
            personProfileCompleter: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container
        .read(personProfileProvider('person-cached').future)
        .timeout(const Duration(milliseconds: 100));

    expect(profile.displayName, 'Cached person');
    expect(repository.personProfileCalls, 1);
  });

  test('settingsProvider returns local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.settings,
      cacheKey: AppCacheKey.build(path: '/settings/me'),
      payloadJson: jsonEncode(_cachedSettingsJson()),
      policy: AppCachePolicies.settings,
    );

    final completer = Completer<UserSettingsData>();
    late _DelayedProfileCacheRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedProfileCacheRepository(
            ref: ref,
            dio: Dio(),
            settingsCompleter: completer,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final settings = await container
        .read(settingsProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(settings.allowPush, isTrue);
    expect(settings.darkMode, isTrue);
    expect(repository.settingsCalls, 1);
  });

  test('dating providers return local cache before background refresh',
      () async {
    final db = AppLocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = AppLocalCacheStore(db);
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.dating,
      cacheKey: AppCacheKey.build(
        path: '/dating/discover',
        query: const DatingDiscoverFilters(
          ageMin: 22,
          ageMax: 35,
          radiusKm: 10,
        ).toQuery(limit: 20),
      ),
      payloadJson: jsonEncode([_cachedDatingJson(userId: 'discover-cached')]),
      policy: AppCachePolicies.dating,
    );
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.dating,
      cacheKey: AppCacheKey.build(
        path: '/dating/discover',
        query: const {'limit': 4},
      ),
      payloadJson: jsonEncode([_cachedDatingJson(userId: 'home-cached')]),
      policy: AppCachePolicies.dating,
    );
    await store.write(
      userScope: AppCacheUserScope.user('user-me'),
      namespace: AppCacheNamespace.dating,
      cacheKey: AppCacheKey.build(
        path: '/dating/likes',
        query: const {'limit': 20},
      ),
      payloadJson: jsonEncode([_cachedDatingJson(userId: 'like-cached')]),
      policy: AppCachePolicies.dating,
    );

    final discoverCompleter = Completer<PaginatedResponse<DatingProfileData>>();
    final likesCompleter = Completer<PaginatedResponse<DatingProfileData>>();
    late _DelayedDatingRepository repository;
    final container = ProviderContainer(
      overrides: [
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-me'),
        localFirstRepositoryProvider.overrideWithValue(
          LocalFirstRepository(store),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _DelayedDatingRepository(
            ref: ref,
            dio: Dio(),
            discoverCompleter: discoverCompleter,
            likesCompleter: likesCompleter,
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final discover = await container
        .read(datingDiscoverProvider.future)
        .timeout(const Duration(milliseconds: 100));
    final home = await container
        .read(datingHomePreviewProvider.future)
        .timeout(const Duration(milliseconds: 100));
    final likes = await container
        .read(datingLikesProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(discover.single.userId, 'discover-cached');
    expect(home.single.userId, 'home-cached');
    expect(likes.single.userId, 'like-cached');
    expect(repository.discoverCalls, 2);
    expect(repository.likesCalls, 1);
  });

  test('datingDiscoverProvider filters local action tombstones', () async {
    final container = ProviderContainer(
      overrides: [
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith(
          (ref) => _DatingPreviewRepository(ref: ref, dio: Dio()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(datingActionTombstonesProvider.notifier).state = const {
      'dating-0': 'like',
      'dating-1': 'pass',
      'dating-2': 'super_like',
      'dating-3': 'match_open',
    };

    final profiles = await container.read(datingDiscoverProvider.future);

    expect(
        profiles.map((profile) => profile.userId), isNot(contains('dating-0')));
    expect(
        profiles.map((profile) => profile.userId), isNot(contains('dating-1')));
    expect(
        profiles.map((profile) => profile.userId), isNot(contains('dating-2')));
    expect(
        profiles.map((profile) => profile.userId), isNot(contains('dating-3')));
  });

  test('route catalog stays empty without auth instead of using fallback data',
      () async {
    var repositoryBuilt = false;
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWith((ref) {
          repositoryBuilt = true;
          return _RouteTemplatesRepository(ref: ref, dio: Dio());
        }),
      ],
    );
    addTearDown(container.dispose);

    final routes = await container.read(
      eveningRouteTemplatesProvider('Москва').future,
    );

    expect(routes, isEmpty);
    expect(repositoryBuilt, isFalse);
  });

  test('route catalog keeps empty backend response instead of fallback data',
      () async {
    late _RouteTemplatesRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _RouteTemplatesRepository(ref: ref, dio: Dio());
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final routes = await container.read(
      eveningRouteTemplatesProvider('Москва').future,
    );

    expect(routes, isEmpty);
    expect(repository.templateCalls, 1);
  });

  test(
      'screen data providers use saved auth tokens without waiting for bootstrap',
      () async {
    final bootstrapCompleter = Completer<void>();
    late _FastScreenDataRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) => bootstrapCompleter.future),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _FastScreenDataRepository(ref: ref, dio: Dio());
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    await Future.wait([
      container.read(eventsProvider('now').future),
      container.read(meetupChatsProvider.future),
      container.read(personalChatsProvider.future),
      container.read(eveningRouteTemplatesProvider('Москва').future),
    ]).timeout(const Duration(milliseconds: 100));

    expect(repository.eventsCalls, 1);
    expect(repository.meetupChatsCalls, 1);
    expect(repository.personalChatsCalls, 1);
    expect(repository.routeTemplatesCalls, 1);
    expect(bootstrapCompleter.isCompleted, isFalse);
  });

  test('route catalog exposes backend errors instead of fallback data',
      () async {
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith(
          (ref) => _RouteTemplatesRepository(
            ref: ref,
            dio: Dio(),
            error: StateError('route template request failed'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(eveningRouteTemplatesProvider('Москва').future),
      throwsA(isA<StateError>()),
    );
  });

  test('onboarding provider prefers local state before backend fetch',
      () async {
    late _OnboardingShouldNotLoadWithoutNetworkRepository repository;
    var repositoryBuilt = false;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repositoryBuilt = true;
          repository = _OnboardingShouldNotLoadWithoutNetworkRepository(
            ref: ref,
            dio: Dio(),
          );
          return repository;
        }),
        onboardingLocalStateProvider.overrideWith(
          (ref) => const OnboardingData(
            intent: 'both',
            gender: 'male',
            city: 'Москва',
            area: 'Патрики',
            interests: ['Кофе', 'Кино'],
            vibe: 'calm',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final onboarding = await container.read(onboardingProvider.future);

    expect(onboarding.city, 'Москва');
    expect(onboarding.area, 'Патрики');
    expect(repositoryBuilt, isFalse);
  });

  test('profile provider reuses onboarding provider data', () async {
    late _ProfileWithSharedOnboardingRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _ProfileWithSharedOnboardingRepository(
            ref: ref,
            dio: Dio(),
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container.read(profileProvider.future);
    final onboarding = await container.read(onboardingProvider.future);

    expect(profile.interests, ['Кофе', 'Кино']);
    expect(profile.intent, ['Свидания', 'Друзья']);
    expect(onboarding.city, 'Москва');
    expect(repository.fetchMeCalls, 1);
    expect(repository.fetchOnboardingCalls, 1);
    expect(repository.fetchProfileCalls, 0);
  });

  test('profile provider keeps profile data when onboarding fails', () async {
    late _ProfileWithFailingOnboardingRepository repository;
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async {}),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _ProfileWithFailingOnboardingRepository(
            ref: ref,
            dio: Dio(),
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container.read(profileProvider.future);

    expect(profile.displayName, 'Никита М');
    expect(profile.interests, isEmpty);
    expect(profile.intent, isEmpty);
    expect(repository.fetchMeCalls, 1);
    expect(repository.fetchOnboardingCalls, 1);
  });

  test('profile provider reuses profile loaded by auth bootstrap', () async {
    late _ProfileWithSharedOnboardingRepository repository;
    final container = ProviderContainer(
      overrides: [
        authTokensProvider.overrideWith(
          (ref) => _StaticAuthTokensController(),
        ),
        backendRepositoryProvider.overrideWith((ref) {
          repository = _ProfileWithSharedOnboardingRepository(
            ref: ref,
            dio: Dio(),
          );
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container.read(profileProvider.future);

    expect(profile.id, 'user-me');
    expect(repository.fetchMeCalls, 1);
    expect(container.read(currentUserIdProvider), 'user-me');
  });
}

Map<String, dynamic> _cachedOnboardingJson() {
  return {
    'intent': 'both',
    'gender': 'male',
    'birthDate': '1998-01-10',
    'city': 'Москва',
    'area': 'Патрики',
    'interests': ['Кофе', 'Кино'],
    'vibe': 'calm',
    'email': 'cached@example.com',
    'phoneNumber': '+79990000000',
    'requiredContact': 'email',
  };
}

Map<String, dynamic> _cachedProfileJson({
  required String id,
  String displayName = 'Cached profile',
}) {
  return {
    'id': id,
    'displayName': displayName,
    'verified': true,
    'online': true,
    'age': 28,
    'gender': 'male',
    'city': 'Москва',
    'area': 'Патрики',
    'bio': 'cached bio',
    'vibe': 'calm',
    'rating': 4.8,
    'meetupCount': 12,
    'avatarUrl': 'https://cdn.example.com/$id.jpg',
    'interests': ['Кофе'],
    'intent': ['Друзья'],
    'photos': [
      {
        'id': 'photo-$id',
        'url': 'https://cdn.example.com/$id-photo.jpg',
        'order': 0,
        'variants': const {},
      },
    ],
    'social': const {
      'followers': 1,
      'likes': 2,
      'superLikes': 3,
      'iFollow': false,
      'iLike': true,
      'iSuper': false,
    },
  };
}

Map<String, dynamic> _cachedSettingsJson() {
  return {
    'allowLocation': true,
    'allowPush': true,
    'allowContacts': false,
    'autoSharePlans': true,
    'hideExactLocation': false,
    'quietHours': true,
    'showAge': true,
    'discoverable': true,
    'darkMode': true,
  };
}

Map<String, dynamic> _cachedDatingJson({required String userId}) {
  return {
    'userId': userId,
    'name': 'Cached dating',
    'age': 27,
    'city': 'Москва',
    'distance': 'Рядом',
    'about': 'cached',
    'tags': ['кофе'],
    'prompt': 'cached prompt',
    'photoEmoji': '💘',
    'avatarUrl': 'https://cdn.example.com/$userId.jpg',
    'primaryPhoto': null,
    'photos': const [],
    'likedYou': false,
    'premium': true,
    'vibe': 'calm',
    'area': 'Центр',
    'latitude': 55.75,
    'longitude': 37.61,
    'verified': true,
    'online': true,
    'languages': const [],
    'nationality': null,
  };
}

Map<String, dynamic> _cachedAfficheJson() {
  return {
    'id': 'affiche-cached',
    'title': 'Cached affiche',
    'description': 'cached',
    'city': 'Москва',
    'venue': 'Дом кино',
    'address': 'Покровка 12',
    'lat': 55.75,
    'lng': 37.61,
    'startsAt': '2026-05-14T18:00:00.000Z',
    'endsAt': null,
    'dateLabel': '14 мая',
    'timeLabel': '18:00',
    'category': 'culture',
    'priceFrom': 0,
    'priceMode': 'free',
    'currency': 'RUB',
    'imageUrl': null,
    'imageVariants': const {},
    'provider': 'affiche',
    'sourceCode': 'cached-source',
    'actionUrl': 'https://example.com/event',
    'actionKind': 'details',
    'isAffiliate': false,
    'tags': ['кино'],
  };
}

Future<AfficheEventsPagedState> _readAfficheFirstPage(
  ProviderContainer container,
  AfficheEventsQuery query,
) async {
  container.read(afficheEventsPagedProvider(query));
  while (true) {
    final value = container.read(afficheEventsPagedProvider(query)).valueOrNull;
    if (value != null) {
      return value;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeGlobalChatSocketClient extends ChatSocketClient {
  _FakeGlobalChatSocketClient()
      : _events = StreamController<Map<String, dynamic>>.broadcast(),
        super(accessTokenProvider: _token);

  final StreamController<Map<String, dynamic>> _events;
  final List<String> subscribedChatIds = <String>[];
  final List<String> unsubscribedChatIds = <String>[];

  static Future<String> _token() async => 'token';

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect() async {}

  @override
  void subscribe(String chatId) {
    subscribedChatIds.add(chatId);
  }

  @override
  void unsubscribe(String chatId) {
    unsubscribedChatIds.add(chatId);
  }

  void emit(Map<String, dynamic> envelope) {
    _events.add(envelope);
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

class _StaticAuthTokensController extends AuthTokensController {
  _StaticAuthTokensController()
      : super(
          null,
          tokenStorage: null,
        ) {
    state = const AuthTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
  }
}
