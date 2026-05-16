import 'package:big_break_mobile/app/core/device/app_address_geocoding_service.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/device/app_reverse_geocoding_service.dart';
import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/publish_meetup_screen.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/create_event_route.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/host_dashboard.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../test_overrides.dart';

class _NoopMapkitBootstrap implements MapkitBootstrap {
  const _NoopMapkitBootstrap();

  @override
  Future<void> ensureInitialized() async {}
}

class _FakeCreateMeetupRepository extends BackendRepository {
  _FakeCreateMeetupRepository({
    required super.ref,
    required super.dio,
  });

  EventJoinMode? lastJoinMode;
  String? lastIdempotencyKey;
  String? lastCommunityId;
  String? lastRouteId;
  String? lastAfficheEventId;
  CreateEventRoutePayload? lastRoute;
  double? lastDistanceKm;
  double? lastLatitude;
  double? lastLongitude;
  String? lastMode;
  String? lastDescription;
  String? lastInviteeUserId;
  String? lastSourceChatId;
  String? lastExternalPlaceId;
  var createEventCalls = 0;
  var updateHostedEventCalls = 0;
  String? lastUpdatedEventId;
  String? lastUpdatedTitle;
  String? lastUpdatedPlace;
  DateTime? lastUpdatedStartsAt;
  int? lastUpdatedCapacity;
  String? lastUpdatedVisibilityMode;
  EventJoinMode? lastUpdatedJoinMode;

  @override
  Future<List<BackendPlacePromoListItem>> fetchPlacePromos({
    String city = 'Москва',
    double? latitude,
    double? longitude,
    int limit = 80,
    String? category,
    CancelToken? cancelToken,
  }) async {
    return const [
      BackendPlacePromoListItem(
        id: 'promo-real-venue',
        title: 'Акции и скидки: Второй бокал бесплатно',
        city: 'Москва',
        venueName: 'Brix Wine',
        placeName: 'Brix Wine',
        address: 'Покровка 12',
        placeCategory: 'bar',
        placeKind: 'bar',
        provider: 'ТоМесто',
        distanceKm: 1.2,
      ),
      BackendPlacePromoListItem(
        id: 'promo-generic-source',
        title: 'Акции и скидки: Алкоголь Виски-карта',
        city: 'Москва',
        venueName: 'Tomesto',
        placeName: 'Tomesto',
        address: 'Москва',
        provider: 'Tomesto',
      ),
    ];
  }

  @override
  Future<EventDetail> createEvent({
    required String title,
    required String description,
    required String emoji,
    required String vibe,
    required String place,
    required DateTime startsAt,
    required int capacity,
    String mode = 'default',
    String lifestyle = 'neutral',
    String priceMode = 'free',
    int? priceAmountFrom,
    int? priceAmountTo,
    String accessMode = 'open',
    String genderMode = 'all',
    String visibilityMode = 'public',
    EventJoinMode joinMode = EventJoinMode.open,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    String? inviteeUserId,
    String? sourceChatId,
    String? afficheEventId,
    String? externalPlaceId,
    String? routeId,
    CreateEventRoutePayload? route,
    String? dressCode,
    String? ageRange,
    String? ratioLabel,
    String? communityId,
    double? distanceKm,
    double? latitude,
    double? longitude,
    bool consentRequired = false,
    List<String>? rules,
    String? idempotencyKey,
  }) async {
    createEventCalls += 1;
    lastJoinMode = joinMode;
    lastIdempotencyKey = idempotencyKey;
    lastCommunityId = communityId;
    lastAfficheEventId = afficheEventId;
    lastRouteId = routeId;
    lastRoute = route;
    lastDistanceKm = distanceKm;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastMode = mode;
    lastDescription = description;
    lastInviteeUserId = inviteeUserId;
    lastSourceChatId = sourceChatId;
    lastExternalPlaceId = externalPlaceId;
    return const EventDetail(
      id: 'e-created',
      title: 'Новая встреча',
      emoji: '🍷',
      time: 'Сегодня · 20:00',
      place: 'Brix Wine, Покровка 12',
      distance: '1.0 км',
      vibe: 'Спокойно',
      description: 'Описание',
      hostNote: null,
      joined: false,
      partnerName: null,
      partnerOffer: null,
      capacity: 6,
      going: 1,
      chatId: null,
      host: EventHost(
        id: 'user-me',
        displayName: 'Никита М',
        verified: true,
        rating: 4.9,
        meetupCount: 10,
        avatarUrl: null,
      ),
      attendees: [
        EventAttendee(
          id: 'user-me',
          displayName: 'Никита М',
          avatarUrl: null,
        ),
      ],
    );
  }

  @override
  Future<void> updateHostedEvent(
    String eventId, {
    required String title,
    required String description,
    required String emoji,
    required String vibe,
    required String place,
    required DateTime startsAt,
    required int capacity,
    String lifestyle = 'neutral',
    String priceMode = 'free',
    int? priceAmountFrom,
    int? priceAmountTo,
    String accessMode = 'open',
    String genderMode = 'all',
    String visibilityMode = 'public',
    EventJoinMode joinMode = EventJoinMode.open,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    double? distanceKm,
    double? latitude,
    double? longitude,
  }) async {
    updateHostedEventCalls += 1;
    lastUpdatedEventId = eventId;
    lastUpdatedTitle = title;
    lastUpdatedPlace = place;
    lastUpdatedStartsAt = startsAt;
    lastUpdatedCapacity = capacity;
    lastUpdatedVisibilityMode = visibilityMode;
    lastUpdatedJoinMode = joinMode;
  }

  @override
  Future<AfficheEvent> fetchAfficheEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return AfficheEvent.fromJson({
      'id': eventId,
      'title': 'Большой стендап',
      'description': 'Комики на сцене',
      'city': 'Москва',
      'venue': 'Клуб',
      'address': 'Тверская 1',
      'lat': 55.75,
      'lng': 37.61,
      'startsAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'category': 'comedy',
      'priceMode': 'paid',
      'priceFrom': 1500,
      'currency': 'RUB',
      'provider': 'Ticketland / MTS Live',
      'sourceCode': 'advcake_ticketland',
      'actionUrl': 'https://go.avred.online/click',
      'actionKind': 'affiliate_ticket',
      'isAffiliate': true,
      'tags': <String>[],
    });
  }
}

class _FakeYandexMapService extends YandexMapService {
  _FakeYandexMapService() : super(bootstrap: const _NoopMapkitBootstrap());

  bool? lastSearchPlacesGeocodeFirst;
  Point? lastSearchPlacesNear;

  @override
  Future<ResolvedAddress?> searchAddress(String query, {Point? near}) async {
    switch (query.trim().toLowerCase()) {
      case 'тверская':
        return const ResolvedAddress(
          name: 'Тверская улица',
          address: 'Тверская улица, Москва',
          point: Point(latitude: 55.765, longitude: 37.605),
        );
      case 'brix · покровка 12':
      case 'brix wine, покровка 12':
        return const ResolvedAddress(
          name: 'Brix Wine',
          address: 'Покровка 12, Москва',
          point: Point(latitude: 55.7605, longitude: 37.6442),
        );
      default:
        return null;
    }
  }

  @override
  Future<List<ResolvedAddress>> searchPlaces(
    String query, {
    Point? near,
    bool geocodeFirst = false,
  }) async {
    lastSearchPlacesGeocodeFirst = geocodeFirst;
    lastSearchPlacesNear = near;
    final normalized = query.trim().toLowerCase();
    if (normalized == 'тверская' && geocodeFirst) {
      return const [
        ResolvedAddress(
          name: 'Тверская улица',
          address: 'Тверская улица, Москва',
          point: Point(latitude: 55.765, longitude: 37.605),
        ),
      ];
    }
    if (normalized == 'кофе') {
      return const [
        ResolvedAddress(
          name: 'Кофемания',
          address: 'Большая Никитская 13, Москва',
          point: Point(latitude: 55.756, longitude: 37.601),
          category: 'Место',
        ),
        ResolvedAddress(
          name: 'ABC Coffee',
          address: 'Покровка 1, Москва',
          point: Point(latitude: 55.759, longitude: 37.647),
          category: 'Место',
        ),
      ];
    }
    return const [];
  }
}

class _HangingYandexMapService extends YandexMapService {
  _HangingYandexMapService() : super(bootstrap: const _NoopMapkitBootstrap());

  var searchAddressCalls = 0;

  @override
  Future<ResolvedAddress?> searchAddress(String query, {Point? near}) {
    searchAddressCalls += 1;
    return Future<ResolvedAddress?>.delayed(const Duration(minutes: 1));
  }

  @override
  Future<List<ResolvedAddress>> searchPlaces(
    String query, {
    Point? near,
    bool geocodeFirst = false,
  }) async {
    return const [];
  }
}

class _UnavailableYandexMapService extends YandexMapService {
  _UnavailableYandexMapService()
      : super(bootstrap: const _NoopMapkitBootstrap());

  @override
  Future<List<ResolvedAddress>> searchPlaces(
    String query, {
    Point? near,
    bool geocodeFirst = false,
  }) async {
    return const [];
  }

  @override
  Future<ResolvedAddress?> reverseGeocode(Point point) async => null;
}

class _FakeAddressGeocodingService implements AppAddressGeocodingService {
  const _FakeAddressGeocodingService({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Future<ForwardGeocodedLocation?> geocodeAddress(String query) async {
    return ForwardGeocodedLocation(
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class _FakeReverseGeocodingService implements AppReverseGeocodingService {
  const _FakeReverseGeocodingService({
    this.city,
    this.street,
  });

  final String? city;
  final String? street;

  @override
  Future<ReverseGeocodedLocation?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return ReverseGeocodedLocation(
      city: city,
      street: street,
    );
  }
}

class _FakeLocationService implements AppLocationService {
  const _FakeLocationService({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Future<Position?> getCurrentPosition() async {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 5, 8),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
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

Widget _wrap(
  void Function(_FakeCreateMeetupRepository repository) onReady, {
  List<Override> overrides = const [],
  String? communityId,
  String? editEventId,
  String? inviteeUserId,
  String? sourceChatId,
  CreateMeetupMode initialMode = CreateMeetupMode.meetup,
  String? afficheEventId,
  bool watchHostDashboard = false,
}) {
  Widget buildScreen() {
    final screen = CreateMeetupScreen(
      communityId: communityId,
      editEventId: editEventId,
      inviteeUserId: inviteeUserId,
      sourceChatId: sourceChatId,
      initialMode: initialMode,
      afficheEventId: afficheEventId,
    );

    if (!watchHostDashboard) {
      return screen;
    }

    return Stack(
      children: [
        screen,
        Offstage(
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(hostDashboardProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => buildScreen(),
      ),
      GoRoute(
        path: '/publish',
        name: 'publishMeetup',
        builder: (context, state) => const PublishMeetupScreen(),
      ),
      GoRoute(
        path: '/event/:eventId',
        name: 'eventDetail',
        builder: (context, state) => Text(
          'event detail ${state.pathParameters['eventId']}',
        ),
      ),
      GoRoute(
        path: '/paywall',
        name: 'paywall',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      backendRepositoryProvider.overrideWith((ref) {
        final repository = _FakeCreateMeetupRepository(
          ref: ref,
          dio: Dio(),
        );
        onReady(repository);
        return repository;
      }),
      yandexMapServiceProvider.overrideWithValue(_FakeYandexMapService()),
      ...overrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('edit startsAt parser keeps backend wall clock time', () {
    final parsed = parseCreateMeetupEventStartsAtForTest(
      '2026-05-12T15:23:00.000Z',
    );

    expect(parsed, isNotNull);
    expect(parsed!.hour, 15);
    expect(parsed.minute, 23);
  });

  final descriptionField = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.maxLines == 3,
    description: 'description text field',
  );
  final placeSheetSearchField = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == 'Найти…',
    description: 'place sheet search field',
  );
  Finder mainScrollable() {
    return find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
          description: 'main vertical scrollable',
        )
        .first;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: mainScrollable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterTitle(WidgetTester tester, String value) async {
    await scrollTo(tester, find.text('Название и иконка'));
    await tester.enterText(find.byType(TextField).first, value);
  }

  Future<void> enterDescription(WidgetTester tester, String value) async {
    await scrollTo(tester, find.text('Описание'));
    await tester.enterText(descriptionField, value);
  }

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.tap(find.text('Дальше · превью'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDatingInvite(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Отправить инвайт'));
    await tester.pumpAndSettle();
  }

  Future<void> openPlaceSheet(WidgetTester tester) async {
    await scrollTo(tester, find.text('Где'));
    await tester.tap(find.text('Где'));
    await tester.pumpAndSettle();
  }

  Future<void> selectTverskayaPlace(WidgetTester tester) async {
    await openPlaceSheet(tester);
    await tester.enterText(placeSheetSearchField, 'Тверская');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Тверская улица').last);
    await tester.pumpAndSettle();
  }

  Finder attachIconButton(String tooltip) {
    return find
        .byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == tooltip,
          description: '$tooltip attach icon button',
        )
        .first;
  }

  Future<void> scrollToAttachActions(WidgetTester tester) async {
    await scrollTo(tester, find.text('Прикрепить'));
  }

  Future<void> tapAttachIconButton(
    WidgetTester tester,
    String tooltip,
  ) async {
    final button = tester.widget<IconButton>(attachIconButton(tooltip));
    expect(button.onPressed, isNotNull);
    button.onPressed!.call();
    await tester.pumpAndSettle();
  }

  testWidgets('create meetup screen renders publish CTA and helper copy',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Образ жизни'));
    expect(find.text('Образ жизни'), findsOneWidget);
    await scrollTo(tester, find.text('Стоимость'));
    expect(find.text('Стоимость'), findsOneWidget);
    await scrollTo(tester, find.text('Кого приглашаешь'));
    expect(find.text('Кого приглашаешь'), findsOneWidget);
    expect(find.text('Дальше · превью'), findsOneWidget);
    expect(
      find.text(
        'Чат откроется автоматически, когда кто-то присоединится',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('create meetup price options stay compact like v5 reference',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Стоимость'));

    final freeChip = find
        .ancestor(
          of: find.text('Бесплатно'),
          matching: find.byType(InkWell),
        )
        .first;
    final fixedChip = find
        .ancestor(
          of: find.text('Фикс'),
          matching: find.byType(InkWell),
        )
        .first;
    final freeRect = tester.getRect(freeChip);
    final fixedRect = tester.getRect(fixedChip);

    expect(freeRect.width, lessThan(150));
    expect((fixedRect.top - freeRect.top).abs(), lessThan(1));
    expect(fixedRect.left, greaterThan(freeRect.right));
  });

  testWidgets('create meetup renders v5 source actions under place',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    await scrollToAttachActions(tester);

    expect(find.byTooltip('Афиша'), findsOneWidget);
    expect(find.byTooltip('Промо'), findsOneWidget);
    expect(find.byTooltip('Маршрут'), findsOneWidget);
    expect(find.text('Афиша'), findsOneWidget);
    expect(find.text('Промо'), findsOneWidget);
    expect(find.text('Маршрут'), findsOneWidget);
    expect(find.text('Партнёр'), findsNothing);
    expect(
      find.text('Указать свой адрес или ориентир', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
      'create meetup promo picker uses venues, clean promo text and categories',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    await scrollToAttachActions(tester);
    await tester.tap(find.byTooltip('Промо'));
    await tester.pumpAndSettle();

    expect(find.text('Brix Wine'), findsWidgets);
    expect(find.text('Tomesto'), findsNothing);
    expect(find.textContaining('Бары'), findsWidgets);
    expect(find.textContaining('Алкоголь Виски-карта'), findsWidgets);
    expect(find.textContaining('Акции и скидки'), findsNothing);
  });

  testWidgets('create meetup keeps bottom fields above fixed CTA',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      _wrap(
        (_) {},
        initialMode: CreateMeetupMode.dating,
      ),
    );
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView).first);
    final listPadding = listView.padding!.resolve(TextDirection.ltr);
    expect(listPadding.bottom, greaterThanOrEqualTo(196));

    await scrollTo(tester, find.text('Описание'));
    await tester.tap(descriptionField);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('create meetup screen hides dating segment in normal creation',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Обычная'), findsOneWidget);
    expect(find.text('Свидание'), findsNothing);
    expect(find.text('After Dark'), findsOneWidget);
  });

  testWidgets('create meetup edit mode prefills event fields', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) {},
        editEventId: 'e-edit',
        overrides: [
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-edit',
              title: 'Вечерняя пробежка',
              emoji: '🏃',
              time: 'Сегодня · 20:00',
              place: 'Парк Горького',
              distance: '1.4 км',
              vibe: 'Активно',
              description: 'Легкий темп и кофе после.',
              hostNote: null,
              joined: true,
              partnerName: null,
              partnerOffer: null,
              capacity: 4,
              going: 2,
              chatId: 'mc-edit',
              startsAtIso: '2026-05-04T17:00:00.000Z',
              lifestyle: 'zozh',
              priceMode: 'free',
              accessMode: 'open',
              genderMode: 'all',
              visibilityMode: 'public',
              isHost: true,
              host: EventHost(
                id: 'user-me',
                displayName: 'Никита М',
                verified: true,
                rating: 4.9,
                meetupCount: 10,
                avatarUrl: null,
              ),
              attendees: [
                EventAttendee(
                  id: 'user-me',
                  displayName: 'Никита М',
                  avatarUrl: null,
                ),
              ],
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактировать встречу'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Встреча'), findsNothing);
    expect(find.text('Свидание'), findsNothing);

    final titleField = tester.widget<TextField>(find.byType(TextField).first);
    expect(titleField.controller?.text, 'Вечерняя пробежка');

    await scrollTo(tester, find.text('Парк Горького'));
    expect(find.text('Парк Горького'), findsOneWidget);

    await scrollTo(tester, find.text('Описание'));
    expect(
      tester.widget<TextField>(descriptionField).controller?.text,
      'Легкий темп и кофе после.',
    );
  });

  testWidgets('create meetup edit mode saves through repository',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        editEventId: 'e-edit',
        overrides: [
          eventDetailProvider.overrideWith((ref, eventId) async {
            return const EventDetail(
              id: 'e-edit',
              title: 'Вечерняя пробежка',
              emoji: '🏃',
              time: 'Сегодня · 20:00',
              place: 'Парк Горького',
              distance: '1.4 км',
              vibe: 'Активно',
              description: 'Легкий темп и кофе после.',
              hostNote: null,
              joined: true,
              partnerName: null,
              partnerOffer: null,
              capacity: 4,
              going: 2,
              chatId: 'mc-edit',
              startsAtIso: '2026-05-04T17:00:00.000Z',
              lifestyle: 'zozh',
              priceMode: 'free',
              accessMode: 'open',
              genderMode: 'all',
              visibilityMode: 'public',
              isHost: true,
              host: EventHost(
                id: 'user-me',
                displayName: 'Никита М',
                verified: true,
                rating: 4.9,
                meetupCount: 10,
                avatarUrl: null,
              ),
              attendees: [
                EventAttendee(
                  id: 'user-me',
                  displayName: 'Никита М',
                  avatarUrl: null,
                ),
              ],
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'Пробежка после правки');
    await scrollTo(tester, find.text('Сохранить'));
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(repository, isNotNull);
    expect(repository!.createEventCalls, 0);
    expect(repository!.updateHostedEventCalls, 1);
    expect(repository!.lastUpdatedEventId, 'e-edit');
    expect(repository!.lastUpdatedTitle, 'Пробежка после правки');
    expect(repository!.lastUpdatedPlace, contains('Парк Горького'));
    expect(repository!.lastUpdatedCapacity, 4);
    expect(repository!.lastUpdatedVisibilityMode, 'public');
    expect(repository!.lastUpdatedJoinMode, EventJoinMode.open);
  });

  testWidgets('date invite uses fallback description and opens event detail',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        initialMode: CreateMeetupMode.dating,
        inviteeUserId: 'user-sonya',
        sourceChatId: 'chat-sonya',
      ),
    );
    await tester.pumpAndSettle();

    await tapDatingInvite(tester);

    expect(repository, isNotNull);
    expect(repository!.createEventCalls, 1);
    expect(repository!.lastMode, 'dating');
    expect(repository!.lastJoinMode, EventJoinMode.request);
    expect(repository!.lastInviteeUserId, 'user-sonya');
    expect(repository!.lastSourceChatId, 'chat-sonya');
    expect(repository!.lastDescription, isNotEmpty);
    expect(repository!.lastDescription, isNot(''));
    expect(find.text('event detail e-created'), findsOneWidget);
  });

  testWidgets('create meetup screen does not show flow explainer cards',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Обычный flow'), findsNothing);
    expect(find.text('Встреча для людей рядом'), findsNothing);

    expect(find.text('Frendly+ date flow'), findsNothing);
    expect(find.text('Отдельный сценарий свидания'), findsNothing);
  });

  testWidgets('create meetup hides free access and ai helper cards',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Свободный приход', skipOffstage: false), findsNothing);
    expect(find.text('AI compass', skipOffstage: false), findsNothing);
    expect(
      find.text('Напишет описание за тебя', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('create meetup sends request join mode for invite visibility',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(_wrap((value) => repository = value));
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Ужин');
    await selectTverskayaPlace(tester);
    await enterDescription(tester, 'Короткое описание');
    final visibilityOption = find.text('По ссылке');
    await scrollTo(tester, visibilityOption);
    await tester.tap(visibilityOption, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastJoinMode, EventJoinMode.request);
  });

  testWidgets('create meetup sends idempotency key on publish', (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(_wrap((value) => repository = value));
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Ужин');
    await selectTverskayaPlace(tester);
    await enterDescription(tester, 'Короткое описание');

    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastIdempotencyKey, isNotNull);
    expect(repository!.lastIdempotencyKey, startsWith('mobile-create-event-'));
  });

  testWidgets(
      'create meetup resolves selected place coordinates before publish',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(_wrap((value) => repository = value));
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Ужин');
    await selectTverskayaPlace(tester);
    await enterDescription(tester, 'Короткое описание');

    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastLatitude, 55.765);
    expect(repository!.lastLongitude, 37.605);
  });

  testWidgets('create meetup refreshes host dashboard after publish',
      (tester) async {
    _FakeCreateMeetupRepository? repository;
    var dashboardLoads = 0;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        watchHostDashboard: true,
        overrides: [
          hostDashboardProvider.overrideWith((ref) async {
            dashboardLoads += 1;
            return const HostDashboardData(
              stats: HostDashboardStats(
                meetupsCount: 0,
                rating: 0,
                fillRate: 0,
              ),
              pendingRequestsCount: 0,
              requests: [],
              events: [],
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(dashboardLoads, 1);

    await enterTitle(tester, 'Ужин');
    await selectTverskayaPlace(tester);
    await enterDescription(tester, 'Короткое описание');

    await tapCreate(tester);
    await tester.pumpAndSettle();

    expect(repository, isNotNull);
    expect(repository!.createEventCalls, 1);
    expect(dashboardLoads, 2);
  });

  testWidgets('create meetup does not wait for hidden geocoding on publish',
      (tester) async {
    _FakeCreateMeetupRepository? repository;
    final mapService = _HangingYandexMapService();

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        overrides: [
          yandexMapServiceProvider.overrideWithValue(mapService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Ужин');
    await openPlaceSheet(tester);
    await tester.enterText(placeSheetSearchField, 'Ручной адрес');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Использовать «Ручной адрес»'));
    await tester.pumpAndSettle();
    await enterDescription(tester, 'Короткое описание');
    final publishButton = find.widgetWithText(FilledButton, 'Дальше · превью');
    expect(publishButton, findsOneWidget);
    await tester.ensureVisible(publishButton);
    await tester.pumpAndSettle();
    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.createEventCalls, 1);
    expect(mapService.searchAddressCalls, 0);
    expect(repository!.lastLatitude, isNull);
    expect(repository!.lastLongitude, isNull);
  });

  testWidgets('create meetup sends community id when opened from community',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        communityId: 'c-owned',
      ),
    );
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Бранч клуба');
    await selectTverskayaPlace(tester);
    await enterDescription(tester, 'Короткое описание');

    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastCommunityId, 'c-owned');
  });

  testWidgets('create meetup sends affiche event id on publish',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        afficheEventId: 'affiche-1',
      ),
    );
    await tester.pumpAndSettle();

    await scrollToAttachActions(tester);
    expect(find.text('Большой стендап'), findsOneWidget);

    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastAfficheEventId, 'affiche-1');
    expect(repository!.lastRouteId, isNull);
  });

  testWidgets('create meetup sends preset route id on publish', (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        overrides: [
          eveningRouteTemplatesProvider.overrideWith(
            (ref, city) async => [_routeSummary],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Вечер по маршруту');
    await scrollToAttachActions(tester);
    await tapAttachIconButton(tester, 'Маршрут');
    await tester.tap(find.text('Тёплый круг на Покровке'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Маршрут: Тёплый круг на Покровке'));
    expect(find.text('Маршрут: Тёплый круг на Покровке'), findsOneWidget);

    await enterDescription(tester, 'Короткое описание');
    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastRouteId, 'r-cozy-circle');
    expect(repository!.lastRoute, isNull);
  });

  testWidgets('create meetup sends custom route payload on publish',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(_wrap((value) => repository = value));
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Свой вечер');
    await scrollToAttachActions(tester);
    await tapAttachIconButton(tester, 'Маршрут');
    await tester.tap(find.text('Создать свой маршрут'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Slow night на Патриках'),
      'Футбол и хинкали',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Бар или кафе'),
      'Футбол',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Адрес или ориентир').first,
      'Парк Горького',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Прогулка'),
      'Хинкали',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Адрес или ориентир').last,
      'Хинкальная',
    );
    await tester.ensureVisible(find.text('Сохранить маршрут'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Сохранить маршрут'));
    await tester.pumpAndSettle();

    expect(find.text('Свой маршрут · 2 шага'), findsWidgets);

    await enterDescription(tester, 'Короткое описание');
    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastRouteId, isNull);
    expect(repository!.lastRoute, isNotNull);
    expect(repository!.lastRoute!.title, 'Футбол и хинкали');
    expect(repository!.lastRoute!.steps, hasLength(2));
  });

  testWidgets('create meetup date time sheet shows only calendar and time',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('Сегодня'));
    await tester.tap(find.textContaining('Сегодня').first);
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsNothing);
    expect(find.text('Завтра'), findsNothing);
    expect(find.text('Послезавтра'), findsNothing);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('create meetup place sheet matches v5 header and search metrics',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    await openPlaceSheet(tester);

    final closeIcon = tester.widget<Icon>(find.byIcon(LucideIcons.x).last);
    expect(closeIcon.size, 16);
    expect(closeIcon.color, BbV5Colors.ink);

    final closeButtonSize = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(LucideIcons.x).last,
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(closeButtonSize, const Size.square(36));

    final searchIcon =
        tester.widget<Icon>(find.byIcon(LucideIcons.search).last);
    expect(searchIcon.size, 16);

    final searchField = tester.widget<TextField>(placeSheetSearchField);
    expect(searchField.style?.fontSize, 13);
    expect(searchField.style?.height, 1.2);
    expect(searchField.decoration?.isDense, isTrue);
    expect(searchField.decoration?.contentPadding, EdgeInsets.zero);
    expect(searchField.textAlignVertical, TextAlignVertical.center);
  });

  testWidgets('create meetup place sheet does not show mock nearby places',
      (tester) async {
    await tester.pumpWidget(_wrap((_) {}));
    await tester.pumpAndSettle();

    await openPlaceSheet(tester);

    expect(find.widgetWithText(InkWell, 'Brix'), findsNothing);
    expect(find.widgetWithText(InkWell, 'Aglio'), findsNothing);
    expect(find.widgetWithText(InkWell, 'Powerhouse'), findsNothing);
    expect(find.widgetWithText(InkWell, 'Парк Горького'), findsNothing);
    expect(find.widgetWithText(InkWell, 'Хохловский переулок'), findsNothing);
    expect(find.text('Ничего не нашли'), findsNothing);
    expect(find.widgetWithText(InkWell, 'Моё местоположение'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Афиша города'), findsOneWidget);
  });

  testWidgets('create meetup place sheet shows yandex search result',
      (tester) async {
    final mapService = _FakeYandexMapService();

    await tester.pumpWidget(
      _wrap(
        (_) {},
        overrides: [
          manualLocationProvider.overrideWith((ref) {
            return ManualLocationController(null)
              ..setLocation(
                const ManualLocation(
                  label: 'Москва',
                  latitude: 55.7558,
                  longitude: 37.6173,
                  city: 'Москва',
                ),
              );
          }),
          yandexMapServiceProvider.overrideWithValue(mapService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await openPlaceSheet(tester);

    expect(find.text('Где встречаемся'), findsOneWidget);

    await tester.enterText(placeSheetSearchField, 'Тверская');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Тверская улица'), findsOneWidget);
    expect(find.text('Тверская улица, Москва · Яндекс'), findsOneWidget);
    expect(mapService.lastSearchPlacesGeocodeFirst, isTrue);
    expect(mapService.lastSearchPlacesNear?.latitude, closeTo(55.7558, 0.0001));
    expect(
      mapService.lastSearchPlacesNear?.longitude,
      closeTo(37.6173, 0.0001),
    );
  });

  testWidgets('create meetup place sheet falls back to platform geocoding',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) {},
        overrides: [
          yandexMapServiceProvider.overrideWithValue(
            _UnavailableYandexMapService(),
          ),
          appAddressGeocodingServiceProvider.overrideWithValue(
            const _FakeAddressGeocodingService(
              latitude: 12.2388,
              longitude: 109.1967,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await openPlaceSheet(tester);
    await tester.enterText(placeSheetSearchField, 'Нячанг');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InkWell, 'Нячанг'), findsOneWidget);
    expect(
      find.text('Найдено по системному геокодеру · Адрес'),
      findsOneWidget,
    );
  });

  testWidgets(
      'create meetup place sheet falls back to platform reverse geocoding',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        overrides: [
          yandexMapServiceProvider.overrideWithValue(
            _UnavailableYandexMapService(),
          ),
          appLocationServiceProvider.overrideWithValue(
            const _FakeLocationService(
              latitude: 12.2388,
              longitude: 109.1967,
            ),
          ),
          appReverseGeocodingServiceProvider.overrideWithValue(
            const _FakeReverseGeocodingService(
              city: 'Нячанг',
              street: 'Tran Phu',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Ужин');
    await openPlaceSheet(tester);
    await tester.scrollUntilVisible(
      find.text('Моё местоположение'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(InkWell, 'Моё местоположение'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Моё местоположение · Tran Phu, Нячанг'));
    expect(
      find.text('Моё местоположение · Tran Phu, Нячанг'),
      findsOneWidget,
    );

    await enterDescription(tester, 'Короткое описание');
    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastLatitude, 12.2388);
    expect(repository!.lastLongitude, 109.1967);
  });

  testWidgets('create meetup place sheet shows several business results',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) {},
        overrides: [
          yandexMapServiceProvider.overrideWithValue(_FakeYandexMapService()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await openPlaceSheet(tester);

    await tester.enterText(placeSheetSearchField, 'Кофе');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Кофемания'), findsOneWidget);
    expect(find.text('ABC Coffee'), findsOneWidget);
  });

  testWidgets('create meetup submits coordinates from selected yandex place',
      (tester) async {
    _FakeCreateMeetupRepository? repository;

    await tester.pumpWidget(
      _wrap(
        (value) => repository = value,
        overrides: [
          yandexMapServiceProvider.overrideWithValue(_FakeYandexMapService()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await enterTitle(tester, 'Кофе после работы');
    await openPlaceSheet(tester);
    await tester.enterText(placeSheetSearchField, 'Тверская');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Тверская улица').last);
    await tester.pumpAndSettle();

    await enterDescription(tester, 'Короткая встреча в центре');
    await tapCreate(tester);

    expect(repository, isNotNull);
    expect(repository!.lastLatitude, 55.765);
    expect(repository!.lastLongitude, 37.605);
    expect(repository!.lastDistanceKm, isNull);
  });
}

final _routeSummary = EveningRouteTemplateSummary.fromJson(const {
  'id': 'template-cozy',
  'routeId': 'r-cozy-circle',
  'title': 'Тёплый круг на Покровке',
  'blurb': 'Аперитив, лёгкий стендап и долгий разговор в кофейне',
  'city': 'Москва',
  'area': 'Чистые пруды → Покровка',
  'vibe': 'Камерный вечер',
  'budget': 'mid',
  'durationLabel': '19:00 — 00:30',
  'totalPriceFrom': 1400,
  'totalSavings': 650,
  'stepsPreview': [
    {'title': 'Бар', 'venue': 'Brix Wine', 'emoji': '🍇', 'time': '19:00'},
    {'title': 'Шоу', 'venue': 'Standup Store', 'emoji': '🎤', 'time': '20:30'},
    {'title': 'Афтер', 'venue': 'Кафе Заря', 'emoji': '☕', 'time': '22:30'},
  ],
  'partnerOffersPreview': [],
  'nearestSessions': [],
});
