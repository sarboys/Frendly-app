import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/device/app_media_prewarm_service.dart';
import 'package:big_break_mobile/app/core/device/app_reverse_geocoding_service.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/app/theme/app_spacing.dart';
import 'package:big_break_mobile/app/theme/app_text_styles.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/dating_profile.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/utils/location_label.dart';
import 'package:big_break_mobile/shared/widgets/bb_external_event_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_brand_icon.dart';
import 'package:big_break_mobile/shared/widgets/bb_profile_photo_image.dart';
import 'package:big_break_mobile/shared/widgets/bb_system_overlays.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_promo.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

const tonightLocationSearchTimeout = Duration(seconds: 5);

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
  final city = await ref.watch(tonightEffectiveCityProvider.future);
  return city != null && city.trim().isNotEmpty;
});

final tonightEffectiveCityProvider = FutureProvider<String?>((ref) async {
  final manualLocation = ref.watch(manualLocationProvider);
  final manualCity = _cityLabelFromManualLocation(manualLocation);
  if (manualCity != null) {
    return manualCity;
  }

  final locationLabel = await ref.watch(tonightHeaderLocationProvider.future);
  return _cityLabelFromRaw(locationLabel);
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
    final promotedIds = events.isEmpty
        ? const <String>{}
        : ref.watch(
            tokenWalletProvider.select(
              (wallet) => events
                  .where((event) => wallet.isPromoted(event.id))
                  .map((event) => event.id)
                  .toSet(),
            ),
          );
    final prewarmGatheringImages = _promotedFirstEvents(
      events,
      promotedIds,
    ).take(6).map((event) => event.imageUrl);
    if (events.isNotEmpty) {
      unawaited(
        ref.read(appMediaPrewarmServiceProvider).warmExternalEventImages(
              prewarmGatheringImages,
              usage: BbExternalEventImageUsage.card,
              limit: 6,
              concurrency: 2,
            ),
      );
    }
    final effectiveCity =
        ref.watch(tonightEffectiveCityProvider).valueOrNull?.trim() ?? '';
    final routeTemplatesAsync = effectiveCity.isEmpty
        ? const AsyncValue<List<EveningRouteTemplateSummary>>.data([])
        : ref.watch(eveningRouteTemplatesProvider(effectiveCity));

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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _TonightRadarCard(
                  eventsCount: events.length,
                  onOpenMap: () => context.goRoute(AppRoute.map),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _TonightGatheringNowSection(
                events: events,
                promotedIds: promotedIds,
                loading: eventsAsync.isLoading,
                onOpenAll: () => context.pushRoute(AppRoute.meetups),
                onOpenEvent: (eventId) => context.pushRoute(
                  AppRoute.eventDetail,
                  pathParameters: {'eventId': eventId},
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _TonightDatingSection(
                onOpenAll: () => context.goRoute(AppRoute.dating),
                onOpenPerson: (personId) => context.goRoute(
                  AppRoute.dating,
                  queryParameters: {'profileId': personId},
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: _TonightAfficheSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: _TonightRoutesSection(
                  routesAsync: routeTemplatesAsync,
                  onOpenAll: () => unawaited(
                    _openCityLimitedFeature(
                      context,
                      ref,
                      featureName: 'Маршруты вечера',
                      route: AppRoute.eveningRoutes,
                    ),
                  ),
                  onOpenRoute: (templateId) => context.pushRoute(
                    AppRoute.eveningRouteDetail,
                    pathParameters: {'templateId': templateId},
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: _TonightMetricsSection(events: events),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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

class _TonightRadarCard extends StatelessWidget {
  const _TonightRadarCard({
    required this.eventsCount,
    required this.onOpenMap,
  });

  final int eventsCount;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
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
                      '$eventsCount встреч и афиш рядом',
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

const _radarSweepFrame = Duration(milliseconds: 40);
const _radarSweepPeriod = Duration(seconds: 5);

class _RadarSweep extends StatefulWidget {
  const _RadarSweep();

  @override
  State<_RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<_RadarSweep> {
  Timer? _timer;
  int _elapsedMilliseconds = 0;
  bool _tickerModeEnabled = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_radarSweepFrame, (_) {
      if (!mounted || !_tickerModeEnabled) {
        return;
      }

      setState(() {
        _elapsedMilliseconds =
            (_elapsedMilliseconds + _radarSweepFrame.inMilliseconds) %
                _radarSweepPeriod.inMilliseconds;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turn = _elapsedMilliseconds / _radarSweepPeriod.inMilliseconds;

    return Transform.rotate(
      key: const ValueKey('tonight-radar-sweep-rotation'),
      angle: turn * math.pi * 2,
      child: const _RadarSweepGradient(),
    );
  }
}

class _RadarSweepGradient extends StatelessWidget {
  const _RadarSweepGradient();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
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

class _TonightGatheringNowSection extends StatefulWidget {
  const _TonightGatheringNowSection({
    required this.events,
    required this.promotedIds,
    required this.loading,
    required this.onOpenAll,
    required this.onOpenEvent,
  });

  final List<Event> events;
  final Set<String> promotedIds;
  final bool loading;
  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenEvent;

  @override
  State<_TonightGatheringNowSection> createState() =>
      _TonightGatheringNowSectionState();
}

class _TonightGatheringNowSectionState
    extends State<_TonightGatheringNowSection> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.55);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _promotedFirstEvents(
      widget.events,
      widget.promotedIds,
    ).take(5).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
                  onTap: widget.onOpenAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.loading && visible.isEmpty)
            const _GatheringSkeletonGrid()
          else if (visible.isEmpty)
            _GatheringEmptyCard(onTap: widget.onOpenAll)
          else
            SizedBox(
              height: 244,
              child: PageView.builder(
                controller: _pageController,
                padEnds: false,
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == visible.length - 1 ? 0 : AppSpacing.sm,
                    ),
                    child: _GatheringCard(
                      key: ValueKey(
                          'tonight-gathering-card-${visible[index].id}'),
                      event: visible[index],
                      promoted: widget.promotedIds.contains(visible[index].id),
                      onTap: () => widget.onOpenEvent(visible[index].id),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GatheringEmptyCard extends StatelessWidget {
  const _GatheringEmptyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(18),
      radius: 24,
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            LucideIcons.calendar_plus,
            size: 24,
            color: BbV5Colors.brandDeep,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Пока нет встреч рядом. Открой список или создай свою.',
              style: AppTextStyles.bodySoft.copyWith(
                color: BbV5Colors.inkSoft,
              ),
            ),
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
    required this.promoted,
    required this.onTap,
    super.key,
  });

  final Event event;
  final bool promoted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.imageUrl?.trim();
    final timeLabel = _gatheringTimeLabel(event.time);
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
            border: Border.all(
              color: promoted ? BbV5PromoColors.gold : BbV5Colors.hair,
              width: promoted ? 1.4 : 1,
            ),
            boxShadow: promoted
                ? const [
                    BoxShadow(
                      color: BbV5PromoColors.glow,
                      blurRadius: 28,
                      spreadRadius: -14,
                      offset: Offset(0, 14),
                    ),
                    ...BbV5Shadows.card,
                  ]
                : BbV5Shadows.card,
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
                      if (imageUrl != null && imageUrl.isNotEmpty)
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
                        left: 8,
                        top: 8,
                        child: promoted
                            ? const BbV5PromoBadge(compact: true)
                            : const SizedBox.shrink(),
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
                      if (timeLabel.isNotEmpty)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: BbV5Colors.ink.withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: BbV5Colors.paperHi,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
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
              const SizedBox(height: 2),
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
                  padding: const EdgeInsets.only(top: 10),
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

String _gatheringTimeLabel(String value) {
  final trimmed = value.trim();
  const todayPrefix = 'Сегодня · ';
  if (trimmed.startsWith(todayPrefix)) {
    return trimmed.substring(todayPrefix.length).trim();
  }
  return trimmed;
}

class _AttendeeInitials extends StatelessWidget {
  const _AttendeeInitials({required this.attendees});

  final List<String> attendees;

  @override
  Widget build(BuildContext context) {
    final visible = attendees.take(3).toList(growable: false);
    return SizedBox(
      width: 48,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 14,
              child: Container(
                width: 20,
                height: 20,
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
    final profilesAsync = ref.watch(datingHomePreviewProvider);
    final profiles = profilesAsync.valueOrNull ?? const <DatingProfileData>[];

    return BbV5Section(
      title: 'Дейтинг · рядом',
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      right: _SectionAction(
        label: 'Все',
        color: BbV5Colors.terra,
        onTap: onOpenAll,
      ),
      child: SizedBox(
        height: 224,
        child: profilesAsync.isLoading && profiles.isEmpty
            ? const _DatingSkeletonRail()
            : profiles.isEmpty
                ? const _V5EmptyCard(message: 'Пока нет людей рядом')
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return _DatingPreviewCard(
                        profile: profile,
                        index: index,
                        onTap: () => onOpenPerson(profile.userId),
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemCount: profiles.length > 4 ? 4 : profiles.length,
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

String? _profileCardImageUrl(DatingProfileData profile) {
  final primaryPhoto = profile.primaryPhoto;
  if (primaryPhoto != null) {
    return primaryPhoto.bestUrlFor(BbImageUsageProfile.card);
  }
  if (profile.photos.isNotEmpty) {
    return profile.photos.first.bestUrlFor(BbImageUsageProfile.card);
  }
  return profile.avatarUrl;
}

class _DatingPreviewCard extends StatelessWidget {
  const _DatingPreviewCard({
    required this.profile,
    required this.index,
    required this.onTap,
  });

  final DatingProfileData profile;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _datingPalette(index);
    final fallbackTag = profile.tags.isNotEmpty ? profile.tags.first : 'арт';
    final tag = (profile.vibe ?? fallbackTag).trim();
    final area = (profile.area ?? profile.distance).trim();
    final title =
        profile.age == null ? profile.name : '${profile.name}, ${profile.age}';
    final avatarUrl = _profileCardImageUrl(profile)?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
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
                          if (hasAvatar)
                            Positioned.fill(
                              child: BbProfilePhotoImage(
                                imageUrl: avatarUrl,
                                fallbackText: _initial(profile.name),
                                usageProfile: BbImageUsageProfile.card,
                                fallbackFontSize: 42,
                              ),
                            ),
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
    final city =
        ref.watch(tonightEffectiveCityProvider).valueOrNull?.trim() ?? '';
    final afficheAsync = city.isEmpty
        ? const AsyncValue<List<AfficheEvent>>.data([])
        : ref.watch(
            afficheEventsProvider(
              AfficheEventsQuery(
                city: city,
                priceMode: 'any',
                limit: 5,
              ),
            ),
          );
    final affiche = afficheAsync.valueOrNull ?? const <AfficheEvent>[];
    final visibleAffiche = affiche.take(5).toList(growable: false);
    if (affiche.isNotEmpty) {
      unawaited(
        ref.read(appMediaPrewarmServiceProvider).warmExternalEventImages(
              visibleAffiche.map(
                (event) => event.imageUrlFor(BbExternalEventImageUsage.rail),
              ),
              usage: BbExternalEventImageUsage.rail,
              limit: 5,
            ),
      );
    }

    return BbV5Section(
      title: 'Афиша города',
      margin: EdgeInsets.zero,
      right: _SectionAction(
        key: const ValueKey('tonight-affiche-all'),
        label: 'Смотреть все',
        color: BbV5Colors.gold,
        onTap: () => context.pushRoute(AppRoute.affiche),
      ),
      child: SizedBox(
        height: 244,
        child: afficheAsync.isLoading && visibleAffiche.isEmpty
            ? const _AfficheSkeletonRail()
            : visibleAffiche.isEmpty
                ? const _V5EmptyCard(message: 'Пока нет событий в афише')
                : ListView.separated(
                    key: const ValueKey('tonight-affiche-rail'),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final event = visibleAffiche[index];
                      return SizedBox(
                        key: ValueKey('tonight-affiche-card-${event.id}'),
                        width: 168,
                        child: _AffichePreviewCard(
                          event: event,
                          onTap: () => context.pushRoute(
                            AppRoute.afficheEvent,
                            pathParameters: {'eventId': event.id},
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemCount: visibleAffiche.length,
                  ),
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
        imageUrl: event.imageUrlFor(BbExternalEventImageUsage.rail),
        usage: BbExternalEventImageUsage.rail,
      ),
      going: event.priceLabel,
      color: BbV5Colors.gold,
      onTap: onTap,
    );
  }
}

class _AfficheSkeletonRail extends StatelessWidget {
  const _AfficheSkeletonRail();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      itemBuilder: (_, __) => Container(
        width: 168,
        decoration: BoxDecoration(
          color: BbV5Colors.paperHi.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: BbV5Colors.hair),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
      itemCount: 5,
    );
  }
}

class _TonightRoutesSection extends StatelessWidget {
  const _TonightRoutesSection({
    required this.routesAsync,
    required this.onOpenAll,
    required this.onOpenRoute,
  });

  final AsyncValue<List<EveningRouteTemplateSummary>> routesAsync;
  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final routes = routesAsync.valueOrNull ?? const [];
    final visibleRoutes = routes.take(2).toList(growable: false);

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
          if (routesAsync.isLoading && visibleRoutes.isEmpty)
            const _RouteHomeLoading()
          else if (visibleRoutes.isEmpty)
            const _RouteHomeEmpty()
          else
            for (var index = 0; index < visibleRoutes.length; index++) ...[
              _RouteHomeCard(
                number: _routeNumber(index),
                route: visibleRoutes[index],
                onTap: () => onOpenRoute(visibleRoutes[index].id),
              ),
              if (index != visibleRoutes.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

String _routeNumber(int index) => (index + 1).toString().padLeft(2, '0');

class _RouteHomeCard extends StatelessWidget {
  const _RouteHomeCard({
    required this.number,
    required this.route,
    required this.onTap,
  });

  final String number;
  final EveningRouteTemplateSummary route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = _routeSummary(route);

    return BbV5Card(
      key: ValueKey('tonight-home-route-${route.id}'),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: bbV5DisplayStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.56,
              color: BbV5Colors.brandDeep,
            ).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
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
                  style: bbV5DisplayStyle(fontSize: 16, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
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
                    _RouteMeta(label: _routeBudgetLabel(route.budget)),
                    const Spacer(),
                    const Icon(
                      LucideIcons.users,
                      size: 10,
                      color: BbV5Colors.inkMute,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${route.hostsCount}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        letterSpacing: 0,
                        color: BbV5Colors.inkMute,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

class _RouteHomeLoading extends StatelessWidget {
  const _RouteHomeLoading();

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BbV5Colors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 160,
                  height: 14,
                  decoration: BoxDecoration(
                    color: BbV5Colors.hair,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 220,
                  height: 10,
                  decoration: BoxDecoration(
                    color: BbV5Colors.hair,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHomeEmpty extends StatelessWidget {
  const _RouteHomeEmpty();

  @override
  Widget build(BuildContext context) {
    return BbV5Card(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Маршрутов пока нет',
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          letterSpacing: 0,
          color: BbV5Colors.inkMute,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _routeSummary(EveningRouteTemplateSummary route) {
  final stepsCount = route.stepsPreview.length;
  final parts = <String>[
    if (stepsCount > 0) '$stepsCount ${_routePointLabel(stepsCount)}',
    if ((route.area ?? '').trim().isNotEmpty) route.area!.trim(),
    if (route.durationLabel.trim().isNotEmpty) route.durationLabel.trim(),
  ];
  return parts.join(' · ');
}

String _routePointLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) {
    return 'точка';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'точки';
  }
  return 'точек';
}

String _routeBudgetLabel(String budget) {
  switch (budget) {
    case 'free':
      return 'бесплатно';
    case 'low':
      return 'легко';
    case 'mid':
      return 'средне';
    case 'high':
      return 'выше';
    default:
      return budget.isEmpty ? 'маршрут' : budget;
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
                        style: bbV5DisplayStyle(fontSize: 14, height: 1.25),
                      ),
                      const SizedBox(height: 2),
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
                          padding: const EdgeInsets.only(top: 10),
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
    final detectedLocation = ref.watch(tonightHeaderLocationProvider);
    final locationLabel = manualLocation?.label ??
        detectedLocation.valueOrNull ??
        'Геолокация недоступна';

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
                    assetPath: BbBrandIcon.sageAssetPath,
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
        const _HeaderAfterDarkButton(),
        const SizedBox(width: AppSpacing.xs),
        const _HeaderNotificationsButton(),
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

class _HeaderAfterDarkButton extends StatelessWidget {
  const _HeaderAfterDarkButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.pushRoute(AppRoute.afterDark),
        borderRadius: BorderRadius.circular(BbV5Radii.pill),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8D5BFF), Color(0xFFFF3EA5)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x66FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FF3EA5),
                blurRadius: 20,
                spreadRadius: -8,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.moon,
            size: 16,
            color: BbV5Colors.paperHi,
          ),
        ),
      ),
    );
  }
}

class _HeaderNotificationsButton extends ConsumerWidget {
  const _HeaderNotificationsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationUnreadCountProvider).valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        BbV5IconButton(
          icon: LucideIcons.bell,
          size: 40,
          iconSize: 16,
          onPressed: () => context.pushRoute(AppRoute.notifications),
        ),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: BbV5Colors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: BbV5Colors.paperHi, width: 2),
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
    final near = _manualLocationSearchPointForQuery(query);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) {
        return;
      }

      List<ResolvedAddress> results;
      try {
        results = await mapService
            .searchPlaces(
              query,
              near: near,
              geocodeFirst: true,
            )
            .timeout(
              tonightLocationSearchTimeout,
              onTimeout: () => const <ResolvedAddress>[],
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
    final near = _manualLocationSearchPointForQuery(query);
    try {
      final resolved = await mapService
          .searchAddress(
            query,
            near: near,
          )
          .timeout(
            tonightLocationSearchTimeout,
            onTimeout: () => null,
          );
      if (!mounted) {
        return;
      }
      if (resolved == null) {
        _showSnackBar('Не нашли это место');
        return;
      }
      _applyResolvedLocation(resolved);
    } catch (_) {
      if (mounted) {
        _showSnackBar('Не нашли это место');
      }
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

  Point? _manualLocationSearchPointForQuery(String query) {
    if (_queryMatchesCityOption(query)) {
      return null;
    }

    final location = ref.read(manualLocationProvider);
    if (location == null || !isSupportedManualLocation(location)) {
      return null;
    }

    return Point(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  bool _queryMatchesCityOption(String query) {
    final normalized = query.toLowerCase().replaceAll('ё', 'е').trim();
    if (normalized.isEmpty) {
      return false;
    }

    return _cityOptions.any((option) {
      final city = option.city.toLowerCase().replaceAll('ё', 'е');
      final region = option.region.toLowerCase().replaceAll('ё', 'е');
      return city.contains(normalized) ||
          normalized.contains(city) ||
          region.contains(normalized);
    });
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
    ref.invalidate(tonightEffectiveCityProvider);
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
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
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
                                    const SizedBox(height: 2),
                                    Text(
                                      'Где ты сейчас',
                                      style: bbV5DisplayStyle(
                                        fontSize: 18,
                                        height: 1.25,
                                        letterSpacing: 0,
                                      ),
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
                                    fontSize: 12,
                                    height: 1.25,
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
                                textStyle: AppTextStyles.button.copyWith(
                                  fontSize: 13,
                                  height: 1.1,
                                ),
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
                height: 1.2,
                color: BbV5Colors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Найти город...',
                hintStyle: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  height: 1.2,
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BbV5Colors.paperHi,
                  ),
                )
              else
                const Icon(
                  LucideIcons.locate,
                  size: 16,
                  color: BbV5Colors.paperHi,
                ),
              const SizedBox(width: 8),
              Text(
                locating ? 'Определяем…' : 'Определить по геолокации',
                style: AppTextStyles.body.copyWith(
                  fontFamily: 'Sora',
                  fontSize: 13,
                  height: 1.1,
                  color: BbV5Colors.paperHi,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                size: 14,
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
                        height: 1.25,
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      option.region,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        height: 1.25,
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
                        height: 1.25,
                        color: BbV5Colors.ink,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        fontSize: 10.5,
                        height: 1.25,
                        color: BbV5Colors.inkMute,
                        letterSpacing: 0,
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

String? _cityLabelFromManualLocation(ManualLocation? location) {
  if (location == null || !isSupportedManualLocation(location)) {
    return null;
  }
  return _cityLabelFromRaw(location.city) ?? _cityLabelFromRaw(location.label);
}

String? _cityLabelFromRaw(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final firstPart = trimmed.split(RegExp(r'\s+[·-]\s+')).first.trim();
  final normalized = normalizeCityLabel(firstPart);
  if (normalized.isNotEmpty) {
    return normalized;
  }

  final fallback = normalizeCityLabel(trimmed);
  return fallback.isEmpty ? null : fallback;
}

class _TonightMetricsSection extends StatelessWidget {
  const _TonightMetricsSection({
    required this.events,
  });

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    const pulseValue = '+38';
    final pulseEvents = _pulseEventsFor(events);

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
              value: events.isEmpty ? '46' : '${events.length}',
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
        if (pulseEvents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: BbV5Kicker('Пульс города'),
          ),
          const SizedBox(height: AppSpacing.sm),
          BbV5Card(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var index = 0; index < pulseEvents.length; index++) ...[
                  _PulseEventRow(event: pulseEvents[index]),
                  if (index != pulseEvents.length - 1)
                    const Divider(height: 14, color: BbV5Colors.hairSoft),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

List<Event> _pulseEventsFor(List<Event> events) {
  final openEvents = events.where((event) {
    if (event.capacity <= 0) {
      return true;
    }
    return event.going < event.capacity;
  }).toList(growable: false);

  openEvents.sort((a, b) {
    final goingCompare = b.going.compareTo(a.going);
    if (goingCompare != 0) {
      return goingCompare;
    }
    return a.title.compareTo(b.title);
  });

  return openEvents.take(5).toList(growable: false);
}

class _PulseEventRow extends StatelessWidget {
  const _PulseEventRow({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final placesLeft =
        event.capacity <= 0 ? null : math.max(0, event.capacity - event.going);
    return Container(
      key: ValueKey('tonight-pulse-event-${event.id}'),
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BbV5Colors.hair),
            ),
            alignment: Alignment.center,
            child: Text(
              event.emoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.itemTitle.copyWith(
                    color: BbV5Colors.ink,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  placesLeft == null
                      ? '${event.going} идут · места открыты'
                      : '${event.going}/${event.capacity} идут · $placesLeft свободно',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: BbV5Colors.inkMute,
                    fontSize: 10.5,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.activity,
            size: 16,
            color: BbV5Colors.terra,
          ),
        ],
      ),
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
                    height: 1,
                    letterSpacing: -0.54,
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
            ).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
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
      padding: const EdgeInsets.all(14),
      tint: tint,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BbV5Colors.paperHi,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BbV5Colors.hair),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontFamily: 'Sora',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
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
              fontSize: 10,
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

List<Event> _promotedFirstEvents(List<Event> events, Set<String> promotedIds) {
  if (promotedIds.isEmpty || events.isEmpty) {
    return events;
  }
  return [
    ...events.where((event) => promotedIds.contains(event.id)),
    ...events.where((event) => !promotedIds.contains(event.id)),
  ];
}
