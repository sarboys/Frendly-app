import 'dart:async';
import 'dart:ui';

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/device/app_reverse_geocoding_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/core/providers/core_providers.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_brand_icon.dart';
import 'package:big_break_mobile/shared/widgets/bb_system_overlays.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

const _streetWords = [
  'улица',
  'проспект',
  'переулок',
  'шоссе',
  'набережная',
  'бульвар',
  'площадь',
  'проезд',
  'тупик',
  'аллея',
  'линия',
  'đường',
  'street',
  'road',
  'avenue',
  'boulevard',
];

class _CityOption {
  const _CityOption({
    required this.region,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String region;
  final String city;
  final double latitude;
  final double longitude;
}

const _cityOptions = [
  _CityOption(
    region: 'Москва и область',
    city: 'Москва',
    latitude: 55.7558,
    longitude: 37.6173,
  ),
  _CityOption(
    region: 'Москва и область',
    city: 'Подольск',
    latitude: 55.4312,
    longitude: 37.5447,
  ),
  _CityOption(
    region: 'Москва и область',
    city: 'Химки',
    latitude: 55.8892,
    longitude: 37.4450,
  ),
  _CityOption(
    region: 'Москва и область',
    city: 'Балашиха',
    latitude: 55.7963,
    longitude: 37.9382,
  ),
  _CityOption(
    region: 'Москва и область',
    city: 'Красногорск',
    latitude: 55.8204,
    longitude: 37.3302,
  ),
  _CityOption(
    region: 'Москва и область',
    city: 'Мытищи',
    latitude: 55.9105,
    longitude: 37.7363,
  ),
  _CityOption(
    region: 'Санкт-Петербург',
    city: 'Санкт-Петербург',
    latitude: 59.9311,
    longitude: 30.3609,
  ),
  _CityOption(
    region: 'Санкт-Петербург',
    city: 'Пушкин',
    latitude: 59.7183,
    longitude: 30.4169,
  ),
  _CityOption(
    region: 'Санкт-Петербург',
    city: 'Петергоф',
    latitude: 59.8845,
    longitude: 29.8852,
  ),
  _CityOption(
    region: 'Санкт-Петербург',
    city: 'Колпино',
    latitude: 59.7507,
    longitude: 30.5886,
  ),
  _CityOption(
    region: 'Краснодарский край',
    city: 'Краснодар',
    latitude: 45.0355,
    longitude: 38.9753,
  ),
  _CityOption(
    region: 'Краснодарский край',
    city: 'Сочи',
    latitude: 43.5855,
    longitude: 39.7231,
  ),
  _CityOption(
    region: 'Краснодарский край',
    city: 'Анапа',
    latitude: 44.8950,
    longitude: 37.3163,
  ),
  _CityOption(
    region: 'Краснодарский край',
    city: 'Геленджик',
    latitude: 44.5611,
    longitude: 38.0768,
  ),
  _CityOption(
    region: 'Краснодарский край',
    city: 'Новороссийск',
    latitude: 44.7239,
    longitude: 37.7683,
  ),
  _CityOption(
    region: 'Татарстан',
    city: 'Казань',
    latitude: 55.7961,
    longitude: 49.1064,
  ),
  _CityOption(
    region: 'Татарстан',
    city: 'Набережные Челны',
    latitude: 55.7436,
    longitude: 52.3958,
  ),
  _CityOption(
    region: 'Татарстан',
    city: 'Альметьевск',
    latitude: 54.9014,
    longitude: 52.2971,
  ),
  _CityOption(
    region: 'Свердловская область',
    city: 'Екатеринбург',
    latitude: 56.8389,
    longitude: 60.6057,
  ),
  _CityOption(
    region: 'Свердловская область',
    city: 'Нижний Тагил',
    latitude: 57.9101,
    longitude: 59.9813,
  ),
  _CityOption(
    region: 'Новосибирская область',
    city: 'Новосибирск',
    latitude: 55.0084,
    longitude: 82.9357,
  ),
  _CityOption(
    region: 'Новосибирская область',
    city: 'Бердск',
    latitude: 54.7583,
    longitude: 83.1072,
  ),
  _CityOption(
    region: 'Нижегородская область',
    city: 'Нижний Новгород',
    latitude: 56.2965,
    longitude: 43.9361,
  ),
  _CityOption(
    region: 'Нижегородская область',
    city: 'Дзержинск',
    latitude: 56.2384,
    longitude: 43.4616,
  ),
];

final tonightHeaderLocationProvider = FutureProvider<String?>((ref) async {
  final manualLocation = ref.watch(manualLocationProvider);
  if (manualLocation != null) {
    return manualLocation.label;
  }

  final locationService = ref.read(appLocationServiceProvider);
  final mapService = ref.read(yandexMapServiceProvider);
  final reverseGeocodingService = ref.read(appReverseGeocodingServiceProvider);

  try {
    final position = await locationService.getCurrentPosition();
    if (position == null) {
      return null;
    }

    final point = Point(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    try {
      final resolved = await mapService.reverseGeocode(point);
      if (resolved != null) {
        final label = _shortHeaderLocationFromResolvedAddress(resolved);
        if (label != null && label.isNotEmpty) {
          return label;
        }
      }
    } catch (_) {
      // Coordinates are still a valid current location if geocoding fails.
    }

    try {
      final resolved = await reverseGeocodingService.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final label = _shortHeaderLocationFromReverseGeocodedLocation(resolved);
      if (label != null && label.isNotEmpty) {
        return label;
      }
    } catch (_) {
      // Coordinates are still a valid current location if geocoding fails.
    }

    return _coordinatesHeaderLocation(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
});

final tonightCityAvailabilityProvider = FutureProvider<bool>((ref) async {
  final manualLocation = ref.watch(manualLocationProvider);
  if (manualLocation != null) {
    return isSupportedManualLocation(manualLocation);
  }

  final locationLabelFuture = ref.watch(tonightHeaderLocationProvider.future);
  final locationLabel = await locationLabelFuture;
  return isSupportedCityLocationLabel(locationLabel);
});

class TonightScreen extends ConsumerStatefulWidget {
  const TonightScreen({super.key});

  @override
  ConsumerState<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends ConsumerState<TonightScreen> {
  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider('nearby'));
    final events = eventsAsync.valueOrNull ?? const [];

    return BbV5Scaffold(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _TonightHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: _TonightHomeHero(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: _TonightRadarCard(
                  eventsCount: events.length,
                  onOpenMap: () => context.goRoute(AppRoute.map),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _TonightGatheringNowSection(
                events: events,
                loading: eventsAsync.isLoading,
                onOpenAll: () => context.pushRoute(
                  AppRoute.search,
                  queryParameters: {'preset': 'nearby'},
                ),
                onOpenEvent: (eventId) => context.pushRoute(
                  AppRoute.eventDetail,
                  pathParameters: {'eventId': eventId},
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _TonightDatingSection(
                onOpenAll: () => context.goRoute(AppRoute.dating),
                onOpenPerson: (userId) => context.pushRoute(
                  AppRoute.userProfile,
                  pathParameters: {'userId': userId},
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _TonightAfficheSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _TonightRoutesSection(
                  onOpenAll: () => unawaited(
                    _openCityLimitedFeature(
                      context,
                      ref,
                      featureName: 'Маршруты вечера',
                      route: AppRoute.eveningRoutes,
                    ),
                  ),
                  onOpenRoute: (routeId) => context.pushRoute(
                    AppRoute.eveningPlan,
                    pathParameters: {'routeId': routeId},
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _TonightPulseSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _TonightMetricsSection(eventsCount: events.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _TonightPersonalSection(
                  onOpenStreak: () => context.pushRoute(AppRoute.streak),
                  onOpenPerks: () => context.pushRoute(AppRoute.perks),
                  onOpenMap: () => context.pushRoute(AppRoute.memoryMap),
                  onOpenVoice: () => context.pushRoute(AppRoute.aiVoice),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _TonightAiCta(
                  onTap: () => unawaited(
                    _openCityLimitedFeature(
                      context,
                      ref,
                      featureName: 'Frendly Вечер',
                      route: AppRoute.aiVoice,
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 156)),
          ],
        ),
      ),
    );
  }
}

Future<void> _openCityLimitedFeature(
  BuildContext context,
  WidgetRef ref, {
  required String featureName,
  required AppRoute route,
}) async {
  final manualLocation = ref.read(manualLocationProvider);
  final availabilityFuture = ref.read(tonightCityAvailabilityProvider.future);
  final available = manualLocation != null
      ? isSupportedManualLocation(manualLocation)
      : await availabilityFuture;

  if (!context.mounted) {
    return;
  }

  if (available) {
    context.pushRoute(route);
    return;
  }

  showCityLimitToast(ref, featureName);
}

class _TonightHomeHero extends StatelessWidget {
  const _TonightHomeHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _todayHeaderLabel(),
            style: AppTextStyles.meta.copyWith(
              fontSize: 12,
              height: 1.2,
              letterSpacing: 0,
              color: BbV5Colors.inkMute,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Город дышит —\nподключайся.',
            style: bbV5DisplayStyle(
              fontSize: 44,
              height: 0.95,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.54,
            ),
          ),
        ],
      ),
    );
  }
}

String _todayHeaderLabel() {
  return 'Среда · 06 мая';
}

class _TonightRadarCard extends StatelessWidget {
  const _TonightRadarCard({
    required this.eventsCount,
    required this.onOpenMap,
  });

  final int eventsCount;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final count = eventsCount == 0 ? 46 : eventsCount;

    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Радар вечера',
                      style: bbV5KickerStyle(
                        fontSize: 9.5,
                        letterSpacing: 2.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count встреч и афиш рядом',
                      style: bbV5DisplayStyle(
                        fontSize: 18,
                        height: 1.1,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RadarMapButton(onTap: onOpenMap),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final size in [56.0, 112.0, 168.0])
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: BbV5Colors.hair),
                    ),
                  ),
                const _RadarSweep(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: BbV5Colors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: BbV5Colors.paperHi,
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                const _RadarDot(
                  offset: Offset(-52, -32),
                  emoji: '🍷',
                  color: BbV5Colors.terra,
                ),
                const _RadarDot(
                  offset: Offset(58, -42),
                  emoji: '🥾',
                  color: BbV5Colors.brand,
                ),
                const _RadarDot(
                  offset: Offset(64, 18),
                  emoji: '💘',
                  color: BbV5Colors.rose,
                ),
                const _RadarDot(
                  offset: Offset(-50, 40),
                  emoji: '🪩',
                  color: BbV5Colors.gold,
                ),
                const _RadarDot(
                  offset: Offset(8, 56),
                  emoji: '☕',
                  color: BbV5Colors.brandDeep,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RadarLegend(label: 'Встречи', color: BbV5Colors.terra),
                _RadarLegend(label: 'Маршруты', color: BbV5Colors.brand),
                _RadarLegend(label: 'Дейтинг', color: BbV5Colors.rose),
                _RadarLegend(label: 'Афиша', color: BbV5Colors.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarMapButton extends StatelessWidget {
  const _RadarMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.map_pin,
                size: 12,
                color: BbV5Colors.ink,
              ),
              const SizedBox(width: 5),
              Text(
                'Карта',
                style: AppTextStyles.meta.copyWith(
                  fontSize: 11.5,
                  height: 1,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                  color: BbV5Colors.ink,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                LucideIcons.chevron_right,
                size: 12,
                color: BbV5Colors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarSweep extends StatelessWidget {
  const _RadarSweep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 168,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Colors.transparent,
            BbV5Colors.terra.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0, 0.09, 0.18],
        ),
      ),
    );
  }
}

class _RadarDot extends StatelessWidget {
  const _RadarDot({
    required this.offset,
    required this.emoji,
    required this.color,
  });

  final Offset offset;
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BbV5Colors.paperHi,
          shape: BoxShape.circle,
          border: Border.all(color: BbV5Colors.hair),
          boxShadow: [
            const BoxShadow(
              color: Color(0x401F241D),
              blurRadius: 14,
              spreadRadius: -4,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 10,
              spreadRadius: -8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16, height: 1)),
      ),
    );
  }
}

class _RadarLegend extends StatelessWidget {
  const _RadarLegend({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 9.5,
            letterSpacing: 0,
            color: BbV5Colors.inkSoft,
          ),
        ),
      ],
    );
  }
}

const _fallbackGatheringEvents = [
  Event(
    id: 'home-v5-brix',
    title: 'Brix',
    emoji: '🍷',
    time: '20:00',
    place: 'винный бар',
    distance: '0.4 км',
    attendees: ['А', 'Л', 'М'],
    going: 8,
    capacity: 10,
    vibe: 'вино',
    tone: EventTone.warm,
    joined: false,
  ),
  Event(
    id: 'home-v5-tverskaya',
    title: 'Тверская в огнях',
    emoji: '🎬',
    time: '21:00',
    place: 'маршрут',
    distance: '0.7 км',
    attendees: ['С', 'К', 'И'],
    going: 6,
    capacity: 10,
    vibe: 'маршрут',
    tone: EventTone.sage,
    joined: false,
  ),
];

String? _fallbackGatheringAssetPath(String eventId) {
  return switch (eventId) {
    'home-v5-brix' => 'assets/images/event-wine.jpg',
    'home-v5-tverskaya' => 'assets/images/event-cinema.jpg',
    _ => null,
  };
}

class _TonightGatheringNowSection extends StatelessWidget {
  const _TonightGatheringNowSection({
    required this.events,
    required this.loading,
    required this.onOpenAll,
    required this.onOpenEvent,
  });

  final List<Event> events;
  final bool loading;
  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final realEvents = events.take(2).toList(growable: false);
    final useFallback = realEvents.isEmpty && !loading;
    final visible = useFallback ? _fallbackGatheringEvents : realEvents;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Expanded(child: BbV5Kicker('Сейчас собираются')),
                _SectionAction(
                  key: const ValueKey('tonight-gathering-all'),
                  label: 'Смотреть все',
                  color: BbV5Colors.brandDeep,
                  onTap: onOpenAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading && visible.isEmpty)
            const _GatheringSkeletonGrid()
          else
            Row(
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  Expanded(
                    child: _GatheringCard(
                      event: visible[index],
                      assetImagePath: useFallback
                          ? _fallbackGatheringAssetPath(visible[index].id)
                          : null,
                      onTap: useFallback
                          ? onOpenAll
                          : () => onOpenEvent(visible[index].id),
                    ),
                  ),
                  if (index != visible.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _GatheringSkeletonGrid extends StatelessWidget {
  const _GatheringSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < 2; index++) ...[
          Expanded(
            child: Container(
              height: 244,
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BbV5Colors.hair),
              ),
            ),
          ),
          if (index == 0) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _GatheringCard extends StatelessWidget {
  const _GatheringCard({
    required this.event,
    required this.assetImagePath,
    required this.onTap,
  });

  final Event event;
  final String? assetImagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.imageUrl?.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 244,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (assetImagePath case final imagePath?)
                        Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        )
                      else if (imageUrl != null && imageUrl.isNotEmpty)
                        BbExternalEventImage(
                          imageUrl: imageUrl,
                          usage: BbExternalEventImageUsage.card,
                        )
                      else
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _eventGradient(event.tone),
                          ),
                          child: Center(
                            child: Text(
                              event.emoji,
                              style: const TextStyle(fontSize: 42, height: 1),
                            ),
                          ),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x8C000000),
                            ],
                            stops: [0.4, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: BbV5Colors.paperHi.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: BbV5Colors.hair),
                          ),
                          child: const Icon(
                            LucideIcons.star,
                            size: 14,
                            color: BbV5Colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bbV5DisplayStyle(fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                '${event.place} · ${event.distance}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0,
                  color: BbV5Colors.inkMute,
                ),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: BbV5Colors.hairSoft),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      _AttendeeInitials(attendees: event.attendees),
                      const Spacer(),
                      Text(
                        '${event.going} идут',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                          color: BbV5Colors.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _eventToneColor(event.tone),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _eventToneColor(EventTone tone) {
    return switch (tone) {
      EventTone.sage => BbV5Colors.brand,
      EventTone.evening => BbV5Colors.gold,
      EventTone.warm => BbV5Colors.terra,
    };
  }

  LinearGradient _eventGradient(EventTone tone) {
    return switch (tone) {
      EventTone.sage => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BbV5Colors.brandSoft, BbV5Colors.brand],
        ),
      EventTone.evening => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BbV5Colors.gold, BbV5Colors.terra],
        ),
      EventTone.warm => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BbV5Colors.terraSoft, BbV5Colors.paperDeep],
        ),
    };
  }
}

class _AttendeeInitials extends StatelessWidget {
  const _AttendeeInitials({required this.attendees});

  final List<String> attendees;

  @override
  Widget build(BuildContext context) {
    final visible = attendees.take(3).toList(growable: false);
    return SizedBox(
      width: 52,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 14,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BbV5Colors.paperHi,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                child: Text(
                  _initial(visible[index]),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 8.5,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TonightDatingSection extends ConsumerWidget {
  const _TonightDatingSection({
    required this.onOpenAll,
    required this.onOpenPerson,
  });

  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleProvider);
    final people = peopleAsync.valueOrNull ?? const <PersonSummary>[];

    return BbV5Section(
      title: 'Дейтинг · рядом',
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      right: _SectionAction(
        label: 'Все',
        color: BbV5Colors.terra,
        onTap: onOpenAll,
      ),
      child: SizedBox(
        height: 224,
        child: peopleAsync.isLoading && people.isEmpty
            ? const _DatingSkeletonRail()
            : people.isEmpty
                ? const _V5EmptyCard(message: 'Пока нет людей рядом')
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return _DatingPreviewCard(
                        person: person,
                        index: index,
                        onTap: () => onOpenPerson(person.id),
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemCount: people.length > 4 ? 4 : people.length,
                  ),
      ),
    );
  }
}

class _DatingSkeletonRail extends StatelessWidget {
  const _DatingSkeletonRail();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      itemBuilder: (_, __) => Container(
        width: 150,
        decoration: BoxDecoration(
          color: BbV5Colors.paperHi.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: BbV5Colors.hair),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
      itemCount: 4,
    );
  }
}

class _DatingPreviewCard extends StatelessWidget {
  const _DatingPreviewCard({
    required this.person,
    required this.index,
    required this.onTap,
  });

  final PersonSummary person;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _datingPalette(index);
    final fallbackTag = person.common.isNotEmpty ? person.common.first : 'арт';
    final tag = (person.vibe ?? fallbackTag).trim();
    final area = (person.area ?? 'рядом').trim();
    final title =
        person.age == null ? person.name : '${person.name}, ${person.age}';

    return SizedBox(
      width: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BbV5Colors.hair),
              boxShadow: BbV5Shadows.card,
            ),
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: palette,
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x00000000),
                                  Color(0x59000000),
                                ],
                                stops: [0.5, 1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: _MiniTag(label: tag),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.copyWith(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: 'Sora',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.map_pin,
                                    size: 11,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      area,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: BbV5Colors.accent,
                      foregroundColor: BbV5Colors.paperHi,
                      padding: EdgeInsets.zero,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(LucideIcons.heart, size: 14),
                    label: Text(
                      'Лайк',
                      style: AppTextStyles.button.copyWith(
                        color: BbV5Colors.paperHi,
                        fontSize: 11.5,
                      ),
                    ),
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

class _TonightAfficheSection extends ConsumerWidget {
  const _TonightAfficheSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = _tonightAfficheCity(ref);
    final afficheAsync = ref.watch(
      afficheEventsProvider(
        AfficheEventsQuery(
          city: city,
          priceMode: 'any',
          limit: 2,
        ),
      ),
    );
    final affiche = afficheAsync.valueOrNull ?? const <AfficheEvent>[];

    return BbV5Section(
      title: 'Афиша города',
      margin: EdgeInsets.zero,
      right: _SectionAction(
        label: 'Смотреть все',
        color: BbV5Colors.gold,
        onTap: () => context.pushRoute(AppRoute.affiche),
      ),
      child: afficheAsync.isLoading && affiche.isEmpty
          ? const _TwoCardSkeletonGrid()
          : affiche.isEmpty
              ? const _V5EmptyCard(message: 'Пока нет событий в афише')
              : Row(
                  children: [
                    for (var index = 0; index < affiche.length; index++) ...[
                      Expanded(
                        child: _AffichePreviewCard(
                          event: affiche[index],
                          onTap: () => context.pushRoute(
                            AppRoute.afficheEvent,
                            pathParameters: {'eventId': affiche[index].id},
                          ),
                        ),
                      ),
                      if (index != affiche.length - 1)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
    );
  }
}

class _AffichePreviewCard extends StatelessWidget {
  const _AffichePreviewCard({
    required this.event,
    required this.onTap,
  });

  final AfficheEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if ((event.venue ?? '').trim().isNotEmpty) event.venue!.trim(),
      if ((event.timeLabel ?? '').trim().isNotEmpty) event.timeLabel!.trim(),
    ].join(' · ');

    return _ImagePreviewCard(
      title: event.title,
      subtitle: sub.isEmpty ? event.placeLabel : sub,
      tag: event.category,
      image: BbExternalEventImage(
        imageUrl: event.imageUrl,
        usage: BbExternalEventImageUsage.rail,
      ),
      going: event.priceLabel,
      color: BbV5Colors.gold,
      onTap: onTap,
    );
  }
}

class _TonightRoutesSection extends StatelessWidget {
  const _TonightRoutesSection({
    required this.onOpenAll,
    required this.onOpenRoute,
  });

  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'Маршруты вечера',
      margin: EdgeInsets.zero,
      right: _SectionAction(
        label: 'Все',
        color: BbV5Colors.brandDeep,
        onTap: onOpenAll,
      ),
      child: Column(
        children: [
          for (var index = 0; index < _homeRoutePreviews.length; index++) ...[
            _RouteHomeCard(
              route: _homeRoutePreviews[index],
              onTap: () => onOpenRoute(_homeRoutePreviews[index].routeId),
            ),
            if (index != _homeRoutePreviews.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _HomeRoutePreview {
  const _HomeRoutePreview({
    required this.routeId,
    required this.number,
    required this.title,
    required this.summary,
    required this.vibe,
    required this.level,
    required this.going,
  });

  final String routeId;
  final String number;
  final String title;
  final String summary;
  final String vibe;
  final String level;
  final int going;
}

const _homeRoutePreviews = [
  _HomeRoutePreview(
    routeId: 'r-social-dance',
    number: '01',
    title: 'Тверская в огнях',
    summary: '3 точки · 2.4 км · 2.5 ч',
    vibe: 'романтика',
    level: 'лёгкий',
    going: 6,
  ),
  _HomeRoutePreview(
    routeId: 'r-date-noir',
    number: '02',
    title: 'Замоскворечье ночью',
    summary: '4 точки · 3.1 км · 3 ч',
    vibe: 'атмосфера',
    level: 'средне',
    going: 11,
  ),
];

class _RouteHomeCard extends StatelessWidget {
  const _RouteHomeCard({
    required this.route,
    required this.onTap,
  });

  final _HomeRoutePreview route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      key: ValueKey('tonight-home-route-${route.routeId}'),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.number,
            style: bbV5DisplayStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.56,
              color: BbV5Colors.brandDeep,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bbV5DisplayStyle(fontSize: 16, height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  route.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    color: BbV5Colors.inkMute,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RouteMeta(label: route.vibe),
                    const _RouteDivider(),
                    _RouteMeta(label: route.level),
                    const Spacer(),
                    const Icon(
                      LucideIcons.users,
                      size: 10,
                      color: BbV5Colors.inkMute,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${route.going}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        letterSpacing: 0,
                        color: BbV5Colors.inkMute,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BbV5Colors.accent,
              shape: BoxShape.circle,
              boxShadow: BbV5Shadows.ink,
            ),
            child: const Icon(
              LucideIcons.arrow_up_right,
              size: 16,
              color: BbV5Colors.paperHi,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMeta extends StatelessWidget {
  const _RouteMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontSize: 9.5,
          letterSpacing: 1.33,
          color: BbV5Colors.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RouteDivider extends StatelessWidget {
  const _RouteDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: BbV5Colors.hair,
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.meta.copyWith(
                fontSize: 10.5,
                height: 1.1,
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevron_right, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BbV5Colors.hair),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          letterSpacing: 0.9,
          color: BbV5Colors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TwoCardSkeletonGrid extends StatelessWidget {
  const _TwoCardSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < 2; index++) ...[
          Expanded(
            child: Container(
              height: 244,
              decoration: BoxDecoration(
                color: BbV5Colors.paperHi.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BbV5Colors.hair),
              ),
            ),
          ),
          if (index == 0) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _V5EmptyCard extends StatelessWidget {
  const _V5EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.meta.copyWith(color: BbV5Colors.inkMute),
      ),
    );
  }
}

class _ImagePreviewCard extends StatelessWidget {
  const _ImagePreviewCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.image,
    required this.going,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String tag;
  final Widget image;
  final String going;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 244,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BbV5Colors.hair),
              boxShadow: BbV5Shadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image,
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0x73000000),
                              ],
                              stops: [0.4, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: _MiniTag(label: tag),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: BbV5Colors.paperHi.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              border: Border.all(color: BbV5Colors.hair),
                            ),
                            child: const Icon(
                              LucideIcons.star,
                              size: 15,
                              color: BbV5Colors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bbV5DisplayStyle(fontSize: 14, height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          letterSpacing: 0,
                          color: BbV5Colors.inkMute,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: BbV5Colors.hairSoft),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  going,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10.5,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w600,
                                    color: BbV5Colors.inkSoft,
                                  ),
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
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

List<Color> _datingPalette(int index) {
  const palettes = [
    [Color(0xFFD8B4A0), Color(0xFFA87966)],
    [Color(0xFF9CB39F), Color(0xFF5F7C68)],
    [Color(0xFFD9C088), Color(0xFF9F833E)],
    [Color(0xFFC58572), Color(0xFF7F4234)],
  ];
  return palettes[index % palettes.length];
}

class _TonightHeader extends ConsumerWidget {
  const _TonightHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manualLocation = ref.watch(manualLocationProvider);
    final locationLabel =
        manualLocation?.city ?? manualLocation?.label ?? 'Москва';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            key: const ValueKey('tonight-location-button'),
            onTap: () => _showTonightLocationSheet(context),
            borderRadius: BorderRadius.circular(28),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: BbV5Colors.hair),
                    boxShadow: BbV5Shadows.pill,
                  ),
                  child: const BbBrandIcon(
                    size: 44,
                    radius: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FRENDLY',
                        style: AppTextStyles.caption.copyWith(
                          fontFamily: 'Sora',
                          fontSize: 10,
                          letterSpacing: 2.2,
                          color: BbV5Colors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.map_pin,
                            size: 12,
                            color: BbV5Colors.inkMute,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                letterSpacing: 0,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            LucideIcons.chevron_down,
                            size: 12,
                            color: BbV5Colors.inkMute,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        BbV5IconButton(
          icon: LucideIcons.search,
          size: 40,
          iconSize: 16,
          onPressed: () => _showTonightSearchModal(context),
        ),
        const SizedBox(width: AppSpacing.xs),
        _HeaderAiButton(
          onTap: () => unawaited(
            _openCityLimitedFeature(
              context,
              ref,
              featureName: 'Frendly Вечер',
              route: AppRoute.aiCreate,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAiButton extends StatelessWidget {
  const _HeaderAiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('tonight-header-ai'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 14,
                color: BbV5Colors.terra,
              ),
              const SizedBox(width: 6),
              Text(
                'AI',
                style: AppTextStyles.meta.copyWith(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: BbV5Colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showTonightSearchModal(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Закрыть поиск',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _TonightSearchOverlay(originContext: context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

const _searchRecentKey = 'v5.search.recent';

enum _SearchKind { all, meetup, club, person, route, poster }

class _SearchModalFilter {
  const _SearchModalFilter(this.kind, this.label);

  final _SearchKind kind;
  final String label;
}

class _SearchModalItem {
  const _SearchModalItem({
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final _SearchKind kind;
  final String title;
  final String subtitle;
}

const _searchModalFilters = [
  _SearchModalFilter(_SearchKind.all, 'Всё'),
  _SearchModalFilter(_SearchKind.meetup, 'Встречи'),
  _SearchModalFilter(_SearchKind.club, 'Клубы'),
  _SearchModalFilter(_SearchKind.person, 'Люди'),
  _SearchModalFilter(_SearchKind.route, 'Маршруты'),
  _SearchModalFilter(_SearchKind.poster, 'Афиша'),
];

const _searchModalItems = [
  _SearchModalItem(
    kind: _SearchKind.meetup,
    title: 'Brix · вино после работы',
    subtitle: 'сегодня · 20:00 · 0.4 км',
  ),
  _SearchModalItem(
    kind: _SearchKind.meetup,
    title: 'Late jazz · Powerhouse',
    subtitle: 'сегодня · 23:00 · 1.2 км',
  ),
  _SearchModalItem(
    kind: _SearchKind.meetup,
    title: 'Утренний забег',
    subtitle: 'сб · 8:00 · Парк Горького',
  ),
  _SearchModalItem(
    kind: _SearchKind.club,
    title: 'Винный четверг',
    subtitle: '428 участников · ужины',
  ),
  _SearchModalItem(
    kind: _SearchKind.club,
    title: 'Wellness Mornings',
    subtitle: '212 участников · спорт',
  ),
  _SearchModalItem(
    kind: _SearchKind.club,
    title: 'Fine Dining Society',
    subtitle: '94 участника · закрытый',
  ),
  _SearchModalItem(
    kind: _SearchKind.person,
    title: 'Аня, 26',
    subtitle: '0.4 км · арт',
  ),
  _SearchModalItem(
    kind: _SearchKind.person,
    title: 'Лев, 29',
    subtitle: '0.8 км · джаз',
  ),
  _SearchModalItem(
    kind: _SearchKind.person,
    title: 'Мира, 24',
    subtitle: '1.1 км · фото',
  ),
  _SearchModalItem(
    kind: _SearchKind.route,
    title: 'Тверская в огнях',
    subtitle: '3 точки · 2.4 км · романтика',
  ),
  _SearchModalItem(
    kind: _SearchKind.route,
    title: 'Замоскворечье ночью',
    subtitle: '4 точки · 3.1 км · атмосфера',
  ),
  _SearchModalItem(
    kind: _SearchKind.poster,
    title: 'Стендап-четверг',
    subtitle: 'Stand-Up Store · 21:00',
  ),
  _SearchModalItem(
    kind: _SearchKind.poster,
    title: 'Therr Maitz',
    subtitle: 'Stadium · 8 мая · 19:00',
  ),
];

class _TonightSearchOverlay extends ConsumerStatefulWidget {
  const _TonightSearchOverlay({required this.originContext});

  final BuildContext originContext;

  @override
  ConsumerState<_TonightSearchOverlay> createState() =>
      _TonightSearchOverlayState();
}

class _TonightSearchOverlayState extends ConsumerState<_TonightSearchOverlay> {
  late final TextEditingController _controller;
  late final Future<SharedPreferences> _preferencesFuture;
  var _query = '';
  var _filter = _SearchKind.all;
  var _recent = const <String>[];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final preferences = ref.read(sharedPreferencesProvider);
    _preferencesFuture = preferences == null
        ? SharedPreferences.getInstance()
        : Future.value(preferences);
    unawaited(_loadRecent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await _preferencesFuture;
    if (!mounted) {
      return;
    }
    setState(() {
      _recent = prefs.getStringList(_searchRecentKey) ?? const <String>[];
    });
  }

  Future<void> _rememberRecent(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) {
      return;
    }

    final next = [clean, ..._recent.where((item) => item != clean)]
        .take(5)
        .toList(growable: false);
    if (mounted) {
      setState(() => _recent = next);
    }

    final prefs = await _preferencesFuture;
    await prefs.setStringList(_searchRecentKey, next);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const <String>[]);
    final prefs = await _preferencesFuture;
    await prefs.remove(_searchRecentKey);
  }

  List<_SearchModalItem> get _results {
    final normalized = _query.trim().toLowerCase();
    return _searchModalItems.where((item) {
      if (_filter != _SearchKind.all && item.kind != _filter) {
        return false;
      }
      if (normalized.isEmpty) {
        return true;
      }
      final source = '${item.title} ${item.subtitle}'.toLowerCase();
      return source.contains(normalized);
    }).toList(growable: false);
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _openItem(_SearchModalItem item) {
    unawaited(_rememberRecent(item.title));
    _close();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final origin = widget.originContext;
      if (!origin.mounted) {
        return;
      }

      switch (item.kind) {
        case _SearchKind.meetup:
          origin.pushRoute(
            AppRoute.search,
            queryParameters: {'preset': 'nearby'},
          );
        case _SearchKind.club:
          origin.goRoute(AppRoute.communities);
        case _SearchKind.person:
          origin.goRoute(AppRoute.dating);
        case _SearchKind.route:
          origin.pushRoute(AppRoute.eveningRoutes);
        case _SearchKind.poster:
          origin.pushRoute(AppRoute.affiche);
        case _SearchKind.all:
          origin.pushRoute(AppRoute.search);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final modalMaxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final resultsMaxHeight =
        (modalMaxHeight - 126).clamp(160.0, 460.0).toDouble();
    final results = _results;
    final showRecent = _query.trim().isEmpty && _recent.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ColoredBox(
                  color: BbV5Colors.ink.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    maxHeight: modalMaxHeight,
                  ),
                  child: GestureDetector(
                    onTap: () {},
                    behavior: HitTestBehavior.opaque,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [BbV5Colors.paperHi, BbV5Colors.paper],
                        ),
                        border: Border.all(color: BbV5Colors.hair),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4A1F241D),
                            blurRadius: 36,
                            spreadRadius: -14,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: DefaultTextStyle.merge(
                          style: AppTextStyles.body.copyWith(
                            color: BbV5Colors.ink,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SearchModalInput(
                                        controller: _controller,
                                        onChanged: (value) {
                                          setState(() => _query = value);
                                        },
                                        onSubmitted: (value) {
                                          unawaited(_rememberRecent(value));
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _SearchModalCloseButton(onTap: _close),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 32,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    itemBuilder: (context, index) {
                                      final filter = _searchModalFilters[index];
                                      return _SearchModalFilterChip(
                                        label: filter.label,
                                        active: filter.kind == _filter,
                                        onTap: () {
                                          setState(() => _filter = filter.kind);
                                        },
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 6),
                                    itemCount: _searchModalFilters.length,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: resultsMaxHeight,
                                  ),
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    children: [
                                      if (showRecent) ...[
                                        _SearchModalRecentHeader(
                                          onClear: () => unawaited(
                                            _clearRecent(),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        for (final recent in _recent) ...[
                                          _SearchModalRecentRow(
                                            title: recent,
                                            onTap: () {
                                              _controller.text = recent;
                                              _controller.selection =
                                                  TextSelection.collapsed(
                                                offset: recent.length,
                                              );
                                              setState(() => _query = recent);
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            top: 2,
                                            bottom: 8,
                                          ),
                                          child: BbV5Kicker('Подсказки'),
                                        ),
                                      ],
                                      for (var index = 0;
                                          index < results.length;
                                          index++) ...[
                                        _SearchModalResultRow(
                                          item: results[index],
                                          onTap: () =>
                                              _openItem(results[index]),
                                        ),
                                        if (index != results.length - 1)
                                          const SizedBox(height: 6),
                                      ],
                                      if (results.isEmpty)
                                        const _SearchModalEmptyState(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchModalInput extends StatelessWidget {
  const _SearchModalInput({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 16,
            color: BbV5Colors.inkMute,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: BbV5Colors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Найти людей, клубы, места…',
                hintStyle: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: BbV5Colors.inkMute,
                ),
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchModalCloseButton extends StatelessWidget {
  const _SearchModalCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            shape: BoxShape.circle,
            border: Border.all(color: BbV5Colors.hair),
            boxShadow: BbV5Shadows.pill,
          ),
          child: const Icon(
            LucideIcons.x,
            size: 17,
            color: BbV5Colors.ink,
          ),
        ),
      ),
    );
  }
}

class _SearchModalFilterChip extends StatelessWidget {
  const _SearchModalFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Ink(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? BbV5Colors.accent : BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(BbV5Radii.pill),
            border: Border.all(
              color: active ? BbV5Colors.accent : BbV5Colors.hair,
            ),
            boxShadow: active ? BbV5Shadows.ink : BbV5Shadows.pill,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontFamily: 'Sora',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: active ? BbV5Colors.paperHi : BbV5Colors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchModalResultRow extends StatelessWidget {
  const _SearchModalResultRow({
    required this.item,
    required this.onTap,
  });

  final _SearchModalItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BbV5Colors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(color: BbV5Colors.hair),
                  ),
                  child: Icon(
                    _searchModalIcon(item.kind),
                    size: 16,
                    color: BbV5Colors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: BbV5Colors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.map_pin,
                            size: 11,
                            color: BbV5Colors.inkMute,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                letterSpacing: 0,
                                color: BbV5Colors.inkMute,
                              ),
                            ),
                          ),
                        ],
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

class _SearchModalRecentHeader extends StatelessWidget {
  const _SearchModalRecentHeader({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: BbV5Kicker('Недавние')),
        InkWell(
          onTap: onClear,
          borderRadius: BorderRadius.circular(BbV5Radii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              'Очистить',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                letterSpacing: 0,
                color: BbV5Colors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchModalRecentRow extends StatelessWidget {
  const _SearchModalRecentRow({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.clock,
                size: 15,
                color: BbV5Colors.inkMute,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12.5,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                    color: BbV5Colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchModalEmptyState extends StatelessWidget {
  const _SearchModalEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Text(
            'Ничего не нашли',
            textAlign: TextAlign.center,
            style: bbV5DisplayStyle(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Попробуй другой запрос',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              letterSpacing: 0,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _searchModalIcon(_SearchKind kind) {
  return switch (kind) {
    _SearchKind.person => LucideIcons.users,
    _SearchKind.club => LucideIcons.heart,
    _SearchKind.meetup => LucideIcons.calendar,
    _SearchKind.route => LucideIcons.route,
    _SearchKind.poster => LucideIcons.ticket,
    _SearchKind.all => LucideIcons.search,
  };
}

Future<void> _showTonightLocationSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _TonightLocationSheet(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _TonightLocationSheet extends ConsumerStatefulWidget {
  const _TonightLocationSheet();

  @override
  ConsumerState<_TonightLocationSheet> createState() =>
      _TonightLocationSheetState();
}

class _TonightLocationSheetState extends ConsumerState<_TonightLocationSheet> {
  late final TextEditingController _controller;
  Timer? _searchDebounce;
  var _suggestions = const <ResolvedAddress>[];
  var _searching = false;
  var _saving = false;
  var _locating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(manualLocationProvider)?.label ?? '',
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    final mapService = ref.read(yandexMapServiceProvider);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) {
        return;
      }

      List<ResolvedAddress> results;
      try {
        results = await mapService.searchPlaces(
          query,
          geocodeFirst: true,
        );
      } catch (_) {
        if (mounted && _controller.text.trim() == query) {
          setState(() {
            _suggestions = const [];
            _searching = false;
          });
        }
        return;
      }

      if (!mounted || _controller.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  Future<void> _saveTypedLocation() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final mapService = ref.read(yandexMapServiceProvider);
    try {
      final resolved = await mapService.searchAddress(
        query,
      );
      if (!mounted) {
        return;
      }
      if (resolved == null) {
        _showSnackBar('Не нашли это место');
        return;
      }
      _applyResolvedLocation(resolved);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _applyResolvedLocation(ResolvedAddress address) {
    if (!mounted) {
      return;
    }

    final fallbackLabel = address.name.trim().isNotEmpty
        ? address.name.trim()
        : address.address.trim();
    final label =
        _shortHeaderLocationFromResolvedAddress(address) ?? fallbackLabel;
    ref.read(manualLocationProvider.notifier).setLocation(
          ManualLocation(
            label: label,
            latitude: address.point.latitude,
            longitude: address.point.longitude,
            city: _manualLocationCityFromResolvedAddress(address),
          ),
        );
    _refreshTonightLocation();
    Navigator.of(context).pop();
  }

  List<_CityOption> _cityResults() {
    final query = _controller.text.trim().toLowerCase().replaceAll('ё', 'е');
    if (query.isEmpty) {
      return _cityOptions.take(12).toList(growable: false);
    }

    return _cityOptions.where((option) {
      final city = option.city.toLowerCase().replaceAll('ё', 'е');
      final region = option.region.toLowerCase().replaceAll('ё', 'е');
      return city.contains(query) || region.contains(query);
    }).toList(growable: false);
  }

  bool _isSelectedCity(_CityOption option) {
    final manualLocation = ref.read(manualLocationProvider);
    return manualLocation?.city == option.city ||
        manualLocation?.label == option.city;
  }

  void _applyCityOption(_CityOption option) {
    ref.read(manualLocationProvider.notifier).setLocation(
          ManualLocation(
            label: option.city,
            city: option.city,
            latitude: option.latitude,
            longitude: option.longitude,
          ),
        );
    _refreshTonightLocation();
    Navigator.of(context).pop();
  }

  Future<void> _detectCurrentLocation() async {
    if (_locating) {
      return;
    }

    final locationService = ref.read(appLocationServiceProvider);
    final mapService = ref.read(yandexMapServiceProvider);
    final reverseGeocodingService =
        ref.read(appReverseGeocodingServiceProvider);
    final manualLocationNotifier = ref.read(manualLocationProvider.notifier);
    setState(() => _locating = true);
    try {
      final position = await locationService.getCurrentPosition();
      if (!mounted) {
        return;
      }
      if (position == null) {
        _showSnackBar('Не удалось определить местоположение');
        return;
      }

      final point = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      try {
        final resolved = await mapService.reverseGeocode(point);
        if (!mounted) {
          return;
        }
        if (resolved != null) {
          _applyResolvedLocation(resolved);
          return;
        }
      } catch (_) {
        // Fall back to platform reverse geocoding below.
      }

      try {
        final resolved = await reverseGeocodingService.reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (!mounted) {
          return;
        }
        final label =
            _shortHeaderLocationFromReverseGeocodedLocation(resolved) ??
                _coordinatesHeaderLocation(
                  position.latitude,
                  position.longitude,
                );
        manualLocationNotifier.setLocation(
          ManualLocation(
            label: label,
            latitude: position.latitude,
            longitude: position.longitude,
            city: resolved?.city,
          ),
        );
        _refreshTonightLocation();
        Navigator.of(context).pop();
      } catch (_) {
        if (!mounted) {
          return;
        }
        manualLocationNotifier.setLocation(
          ManualLocation(
            label: _coordinatesHeaderLocation(
              position.latitude,
              position.longitude,
            ),
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
        _refreshTonightLocation();
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _refreshTonightLocation() {
    ref.invalidate(tonightHeaderLocationProvider);
    ref.invalidate(tonightCityAvailabilityProvider);
    ref.invalidate(eventsProvider('nearby'));
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final cityResults = _cityResults();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(
                  color: BbV5Colors.ink.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                  ),
                  child: BbV5Card(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const BbV5Kicker('Город'),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Где ты сейчас',
                                      style: bbV5DisplayStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                              ),
                              BbV5IconButton(
                                icon: LucideIcons.x,
                                onPressed: () => Navigator.of(context).pop(),
                                size: 36,
                                iconSize: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _CitySearchField(
                            controller: _controller,
                            onChanged: _handleChanged,
                            onSubmitted: (_) => _saveTypedLocation(),
                          ),
                          const SizedBox(height: 12),
                          _AutoLocationRow(
                            locating: _locating,
                            onTap: () => unawaited(_detectCurrentLocation()),
                          ),
                          const SizedBox(height: 16),
                          if (cityResults.isNotEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: cityResults.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final option = cityResults[index];
                                  return _CityOptionRow(
                                    option: option,
                                    selected: _isSelectedCity(option),
                                    onTap: () => _applyCityOption(option),
                                  );
                                },
                              ),
                            )
                          else if (!_searching && _suggestions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'Ничего не найдено',
                                  style: AppTextStyles.meta.copyWith(
                                    color: BbV5Colors.inkMute,
                                  ),
                                ),
                              ),
                            ),
                          if (_searching || _suggestions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: _searching && _suggestions.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: BbV5Colors.accent,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Ищем место'),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: _suggestions.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(height: 6),
                                      itemBuilder: (context, index) {
                                        final item = _suggestions[index];
                                        return _LocationSuggestionRow(
                                          address: item,
                                          onTap: () =>
                                              _applyResolvedLocation(item),
                                        );
                                      },
                                    ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _saving ? null : _saveTypedLocation,
                              style: FilledButton.styleFrom(
                                elevation: 0,
                                backgroundColor: BbV5Colors.accent,
                                foregroundColor: BbV5Colors.paperHi,
                                shape: const StadiumBorder(),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: BbV5Colors.paperHi,
                                      ),
                                    )
                                  : const Text('Сохранить вручную'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitySearchField extends StatelessWidget {
  const _CitySearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BbV5Colors.paperHi,
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        border: Border.all(color: BbV5Colors.hair),
        boxShadow: BbV5Shadows.pill,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.search,
            size: 16,
            color: BbV5Colors.inkMute,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('tonight-location-input'),
              controller: controller,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: BbV5Colors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Найти город...',
                hintStyle: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: BbV5Colors.inkMute,
                ),
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoLocationRow extends StatelessWidget {
  const _AutoLocationRow({
    required this.locating,
    required this.onTap,
  });

  final bool locating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbV5Colors.accent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: locating ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (locating)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BbV5Colors.paperHi,
                  ),
                )
              else
                const Icon(
                  LucideIcons.locate,
                  size: 17,
                  color: BbV5Colors.paperHi,
                ),
              const SizedBox(width: 8),
              Text(
                locating ? 'Определяем…' : 'Определить по геолокации',
                style: AppTextStyles.body.copyWith(
                  color: BbV5Colors.paperHi,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityOptionRow extends StatelessWidget {
  const _CityOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _CityOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? BbV5Colors.accent : BbV5Colors.paperHi;
    final foreground = selected ? BbV5Colors.paperHi : BbV5Colors.ink;
    final muted = selected
        ? BbV5Colors.paperHi.withValues(alpha: 0.72)
        : BbV5Colors.inkMute;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? BbV5Colors.accent : BbV5Colors.hair,
            ),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.map_pin,
                size: 15,
                color: selected ? BbV5Colors.paperHi : BbV5Colors.inkMute,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      option.region,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: muted,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  LucideIcons.check,
                  size: 16,
                  color: BbV5Colors.paperHi,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSuggestionRow extends StatelessWidget {
  const _LocationSuggestionRow({
    required this.address,
    required this.onTap,
  });

  final ResolvedAddress address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: BbV5Colors.paperHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BbV5Colors.hair),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BbV5Colors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: BbV5Colors.hair),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.map_pin,
                  size: 16,
                  color: BbV5Colors.inkMute,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      address.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        color: BbV5Colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: BbV5Colors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _shortHeaderLocationFromResolvedAddress(ResolvedAddress address) {
  final city = address.city?.trim();
  final street = address.street?.trim();
  if (city != null && city.isNotEmpty) {
    if (street != null && street.isNotEmpty && street != city) {
      return '$city - $street';
    }

    return city;
  }

  return _shortHeaderLocationFromAddress(address.address);
}

String? _manualLocationCityFromResolvedAddress(ResolvedAddress address) {
  final city = address.city?.trim();
  if (city != null && city.isNotEmpty) {
    return city;
  }

  final label = _shortHeaderLocationFromAddress(address.address);
  if (label == null || label.isEmpty) {
    return null;
  }

  final separatorIndex = label.indexOf(' - ');
  if (separatorIndex <= 0) {
    return label;
  }

  return label.substring(0, separatorIndex).trim();
}

String? _shortHeaderLocationFromReverseGeocodedLocation(
  ReverseGeocodedLocation? location,
) {
  if (location == null) {
    return null;
  }

  final city = location.city?.trim();
  final street = location.street?.trim();
  if (city != null && city.isNotEmpty) {
    if (street != null && street.isNotEmpty && street != city) {
      return '$city - $street';
    }

    return city;
  }

  return street;
}

String? _shortHeaderLocationFromAddress(String address) {
  final parts = address
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return null;
  }

  final addressParts = _withoutTrailingHouseNumber(parts);
  if (addressParts.isEmpty) {
    return null;
  }

  final streetIndex = _findStreetPartIndex(addressParts);
  if (streetIndex > 0) {
    return _composeLocationLabel(
      city: addressParts[streetIndex - 1],
      street: addressParts[streetIndex],
    );
  }

  if (addressParts.length >= 2 && addressParts.length < parts.length) {
    return _composeLocationLabel(
      city: addressParts[addressParts.length - 2],
      street: addressParts.last,
    );
  }

  return addressParts.last;
}

String _coordinatesHeaderLocation(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

String _composeLocationLabel({
  required String city,
  required String street,
}) {
  final cleanCity = city.trim();
  final cleanStreet = street.trim();
  if (cleanStreet.isEmpty || cleanCity == cleanStreet) {
    return cleanCity;
  }

  return '$cleanCity - $cleanStreet';
}

List<String> _withoutTrailingHouseNumber(List<String> parts) {
  if (parts.length < 2 || !_looksLikeHouseNumber(parts.last)) {
    return parts;
  }

  return parts.take(parts.length - 1).toList(growable: false);
}

int _findStreetPartIndex(List<String> parts) {
  for (var index = 1; index < parts.length; index += 1) {
    if (_hasStreetWord(parts[index])) {
      return index;
    }
  }

  return -1;
}

bool _hasStreetWord(String item) {
  final normalized = item.toLowerCase();
  return _streetWords.any(normalized.contains);
}

bool _looksLikeHouseNumber(String item) {
  final normalized = item.toLowerCase();
  return RegExp(r'^\d+[а-яa-z]?$').hasMatch(normalized);
}

String _tonightAfficheCity(WidgetRef ref) {
  final manualLocation = ref.watch(manualLocationProvider);
  final raw = manualLocation?.city ?? manualLocation?.label;
  final normalized = raw
          ?.toLowerCase()
          .replaceAll('ё', 'е')
          .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
          .trim() ??
      '';
  if (normalized.contains('санкт петербург') ||
      normalized.contains('saint petersburg') ||
      normalized.contains('st petersburg') ||
      RegExp(r'(^|\s)(спб|питер)(\s|$)').hasMatch(normalized)) {
    return 'Санкт-Петербург';
  }
  return 'Москва';
}

class _TonightPulseSection extends StatelessWidget {
  const _TonightPulseSection();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        time: '20:00',
        title: 'Brix · открытие винного вечера',
        sub: '8 идут',
        tag: 'встреча',
        status: 'идёт',
        color: BbV5Colors.terra,
      ),
      (
        time: '21:00',
        title: 'Маршрут «Тверская в огнях»',
        sub: 'старт у Маяковской',
        tag: 'маршрут',
        status: 'сейчас',
        color: BbV5Colors.brand,
      ),
      (
        time: '22:00',
        title: 'Стендап-четверг · Stand-Up Store',
        sub: '14 идут · 2 друга',
        tag: 'афиша',
        status: 'скоро',
        color: BbV5Colors.gold,
      ),
      (
        time: '23:00',
        title: 'Late jazz · Powerhouse',
        sub: '11 идут',
        tag: 'встреча',
        status: 'позже',
        color: BbV5Colors.terra,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Expanded(child: BbV5Kicker('Пульс города')),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: BbV5Colors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'live',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: BbV5Colors.brandDeep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BbV5Card(
          padding: EdgeInsets.zero,
          radius: 24,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _PulseRow(item: items[index]),
                if (index != items.length - 1)
                  const Divider(height: 1, color: BbV5Colors.hairSoft),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseRow extends StatelessWidget {
  const _PulseRow({required this.item});

  final ({
    String time,
    String title,
    String sub,
    String tag,
    String status,
    Color color,
  }) item;

  @override
  Widget build(BuildContext context) {
    final active = item.status == 'сейчас';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.time,
                  style: bbV5DisplayStyle(
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.32,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.status,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.44,
                    color: active ? item.color : BbV5Colors.inkMute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 40,
            color: active ? item.color : BbV5Colors.hair,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.tag,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9.5,
                        letterSpacing: 1.33,
                        color: item.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: BbV5Colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0,
                    color: BbV5Colors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.arrow_up_right,
            size: 15,
            color: BbV5Colors.inkMute,
          ),
        ],
      ),
    );
  }
}

class _TonightMetricsSection extends StatelessWidget {
  const _TonightMetricsSection({
    required this.eventsCount,
  });

  final int eventsCount;

  @override
  Widget build(BuildContext context) {
    const pulseValue = '+38';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: BbV5Kicker('Сводка'),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.34,
          children: [
            const _MetricCard(
              title: 'Pulse',
              value: pulseValue,
              unit: '%',
              sub: 'людей онлайн',
              tint: BbV5Colors.terraSoft,
            ),
            _MetricCard(
              title: 'Tonight',
              value: eventsCount == 0 ? '46' : '$eventsCount',
              unit: '',
              sub: 'встреч в городе',
              tint: BbV5Colors.brandSoft,
            ),
            const _MetricCard(
              title: 'Friends',
              value: '12',
              unit: '',
              sub: 'выходят сегодня',
            ),
            const _MetricCard(
              title: 'Hosting',
              value: '1',
              unit: '',
              sub: 'твоя встреча',
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.sub,
    this.tint,
  });

  final String title;
  final String value;
  final String unit;
  final String sub;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(16),
      tint: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BbV5Kicker(title),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: unit,
                  style: bbV5DisplayStyle(
                    fontSize: 18,
                    color: BbV5Colors.inkSoft,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bbV5DisplayStyle(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.08,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              letterSpacing: 0,
              color: BbV5Colors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _TonightPersonalSection extends StatelessWidget {
  const _TonightPersonalSection({
    required this.onOpenStreak,
    required this.onOpenPerks,
    required this.onOpenMap,
    required this.onOpenVoice,
  });

  final VoidCallback onOpenStreak;
  final VoidCallback onOpenPerks;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenVoice;

  @override
  Widget build(BuildContext context) {
    return BbV5Section(
      title: 'Твоё в Frendly',
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PersonalPortalCard(
                  title: 'Streak',
                  subtitle: '3 / 5 вечеров',
                  icon: LucideIcons.flame,
                  tint: BbV5Colors.terraSoft,
                  color: BbV5Colors.accent,
                  onTap: onOpenStreak,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _PersonalPortalCard(
                  title: 'Перки',
                  subtitle: '3 доступны',
                  icon: LucideIcons.gift,
                  tint: BbV5Colors.brandSoft,
                  color: BbV5Colors.brandDeep,
                  onTap: onOpenPerks,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _PersonalPortalCard(
                  title: 'Карта',
                  subtitle: '12 мест',
                  icon: LucideIcons.map,
                  tint: BbV5Colors.rose,
                  color: BbV5Colors.ink,
                  onTap: onOpenMap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: BbV5PillButton(
              label: 'Сказать вслух',
              icon: LucideIcons.mic,
              height: 38,
              fontSize: 12,
              onPressed: onOpenVoice,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalPortalCard extends StatelessWidget {
  const _PersonalPortalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      radius: 20,
      padding: const EdgeInsets.all(12),
      tint: tint,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontFamily: 'Sora',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.1,
              color: BbV5Colors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: BbV5Colors.inkMute,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TonightAiCta extends StatelessWidget {
  const _TonightAiCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      tint: BbV5Colors.terraSoft,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BbV5Kicker('AI · голос'),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Скажи вечер —\n'),
                TextSpan(
                  text: 'соберу за минуту.',
                  style: bbV5DisplayStyle(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: BbV5Colors.terra,
                  ),
                ),
              ],
            ),
            style: bbV5DisplayStyle(
              fontSize: 28,
              height: 1.05,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '«Винчик и джаз на двоих в центре до 23» — маршрут + люди рядом.',
            style: AppTextStyles.meta.copyWith(
              fontSize: 12,
              height: 1.55,
              letterSpacing: 0,
              color: BbV5Colors.inkSoft,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(BbV5Radii.pill),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: BbV5Colors.accent,
                  borderRadius: BorderRadius.circular(BbV5Radii.pill),
                  boxShadow: BbV5Shadows.ink,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.mic,
                      size: 16,
                      color: BbV5Colors.paperHi,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Сказать вслух',
                      style: AppTextStyles.button.copyWith(
                        fontSize: 13,
                        height: 1,
                        letterSpacing: 0,
                        color: BbV5Colors.paperHi,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'F';
  }
  return trimmed.substring(0, 1).toUpperCase();
}
