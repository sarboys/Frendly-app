import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:big_break_mobile/shared/models/evening_route_template.dart';
import 'package:big_break_mobile/shared/models/evening_session.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_filters.dart';
import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:big_break_mobile/features/after_dark/presentation/after_dark_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@visibleForTesting
const maxRecentSearchQueries = 3;

class SearchResultsData {
  const SearchResultsData({
    required this.meetups,
    required this.evenings,
    required this.routes,
    required this.posters,
    required this.affiche,
  });

  final List<Event> meetups;
  final List<AfterDarkEvent> evenings;
  final List<EveningRouteTemplateSummary> routes;
  final List<Poster> posters;
  final List<AfficheEvent> affiche;
}

final searchRecentQueriesProvider =
    StateNotifierProvider<SearchRecentQueriesController, List<String>>(
  (ref) => SearchRecentQueriesController(),
);

class SearchRecentQueriesController extends StateNotifier<List<String>> {
  SearchRecentQueriesController() : super(const []);

  void add(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) {
      return;
    }

    final normalizedKey = normalized.toLowerCase();
    state = [
      normalized,
      for (final item in state)
        if (item.toLowerCase() != normalizedKey) item,
    ].take(maxRecentSearchQueries).toList(growable: false);
  }

  void remove(String query) {
    state = state.where((item) => item != query).toList(growable: false);
  }

  void clear() {
    state = const [];
  }

  String _normalize(String query) {
    return query.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class SearchResultsQuery {
  const SearchResultsQuery({
    required this.query,
    required this.activeFilters,
    required this.sheetFilters,
  });

  final String query;
  final List<String> activeFilters;
  final EventFilters sheetFilters;

  @override
  bool operator ==(Object other) {
    return other is SearchResultsQuery &&
        other.query == query &&
        listEquals(other.activeFilters, activeFilters) &&
        other.sheetFilters == sheetFilters;
  }

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAll(activeFilters),
        sheetFilters,
      );
}

final searchResultsProvider =
    FutureProvider.autoDispose.family<SearchResultsData, SearchResultsQuery>((
  ref,
  query,
) async {
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() {
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('search_results_disposed');
    }
  });
  final grouped = await repository.searchGrouped(
    q: query.query,
    lifestyle: query.sheetFilters.lifestyle,
    price: query.sheetFilters.price,
    gender: query.sheetFilters.gender,
    access: query.sheetFilters.access,
    date: query.sheetFilters.date,
    meetupsLimit: 8,
    eveningsLimit: 6,
    routesLimit: 6,
    postersLimit: 8,
    afficheLimit: 8,
    city: _searchCity(ref),
    cancelToken: cancelToken,
  );

  return SearchResultsData(
    meetups: filterSearchEvents(
      events: grouped.meetups,
      query: query.query,
      activeFilters: query.activeFilters,
      sheetFilters: query.sheetFilters,
    ),
    evenings: filterSearchAfterDarkEvents(
      events: grouped.evenings,
      query: query.query,
      activeFilters: query.activeFilters,
    ),
    routes: filterSearchRoutes(
      routes: grouped.routes,
      query: query.query,
      activeFilters: query.activeFilters,
    ),
    posters: filterSearchPosters(
      posters: grouped.posters,
      query: query.query,
      activeFilters: query.activeFilters,
      sheetFilters: query.sheetFilters,
    ),
    affiche: filterSearchAfficheEvents(
      events: grouped.affiche,
      query: query.query,
      activeFilters: query.activeFilters,
      sheetFilters: query.sheetFilters,
    ),
  );
});

List<Event> filterSearchEvents({
  required List<Event> events,
  required String query,
  required List<String> activeFilters,
  required EventFilters sheetFilters,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return events.where((event) {
    if (!_matchesSheetFilters(event, sheetFilters)) {
      return false;
    }
    if (!_matchesDateFilter(event.startsAtIso, sheetFilters.date)) {
      return false;
    }
    if (!_matchesQuickFilters(event, activeFilters)) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      event.title,
      event.place,
      event.vibe,
      event.hostNote ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }).toList(growable: false);
}

List<EveningSessionSummary> filterSearchEvenings({
  required List<EveningSessionSummary> sessions,
  required String query,
  required List<String> activeFilters,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return sessions.where((session) {
    if (!_matchesEveningQuickFilters(session, activeFilters)) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      session.title,
      session.vibe,
      session.area ?? '',
      session.hostName ?? '',
      session.currentPlace ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }).toList(growable: false);
}

List<AfterDarkEvent> filterSearchAfterDarkEvents({
  required List<AfterDarkEvent> events,
  required String query,
  required List<String> activeFilters,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return events.where((event) {
    if (!_matchesAfterDarkQuickFilters(event, activeFilters)) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      event.title,
      event.district,
      event.vibe,
      event.category,
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }).toList(growable: false);
}

List<EveningRouteTemplateSummary> filterSearchRoutes({
  required List<EveningRouteTemplateSummary> routes,
  required String query,
  required List<String> activeFilters,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return routes.where((route) {
    if (!_matchesRouteQuickFilters(route, activeFilters)) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      route.title,
      route.area ?? '',
      route.blurb,
      route.vibe,
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }).toList(growable: false);
}

List<Poster> filterSearchPosters({
  required List<Poster> posters,
  required String query,
  required List<String> activeFilters,
  required EventFilters sheetFilters,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return posters.where((poster) {
    if (!_matchesPosterQuickFilters(poster, activeFilters)) {
      return false;
    }
    if (!_matchesPosterDateFilter(poster, sheetFilters.date)) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      poster.title,
      poster.venue,
      poster.description,
      ...poster.tags,
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }).toList(growable: false);
}

List<AfficheEvent> filterSearchAfficheEvents({
  required List<AfficheEvent> events,
  required String query,
  required List<String> activeFilters,
  required EventFilters sheetFilters,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return events.where((event) {
    if (!_matchesAfficheQuickFilters(event, activeFilters)) {
      return false;
    }
    if (!_matchesDateFilter(
        event.startsAt?.toIso8601String(), sheetFilters.date)) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      event.title,
      event.venue ?? '',
      event.address ?? '',
      event.provider ?? '',
      event.category,
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }).toList(growable: false);
}

List<PersonSummary> filterSearchPeople({
  required List<PersonSummary> people,
  required String query,
  required List<String> activeFilters,
}) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return const [];
  }

  final nearbyOnly = activeFilters.contains('Рядом');
  return people.where((person) {
    final haystack = [
      person.name,
      person.area ?? '',
      person.vibe ?? '',
      ...person.common,
    ].join(' ').toLowerCase();
    if (!haystack.contains(normalized)) {
      return false;
    }
    if (nearbyOnly && (person.area ?? '').isEmpty) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

bool _matchesDateFilter(String? startsAtIso, String date) {
  if (date == 'any') {
    return true;
  }
  if (startsAtIso == null || startsAtIso.isEmpty) {
    return false;
  }
  final parsed = DateTime.tryParse(startsAtIso)?.toLocal();
  if (parsed == null) {
    return false;
  }
  return _isoDate(parsed) == date;
}

bool _matchesPosterDateFilter(Poster poster, String date) {
  if (date == 'any') {
    return true;
  }
  return _isoDate(poster.startsAt) == date;
}

bool _matchesSheetFilters(Event event, EventFilters filters) {
  if (filters.lifestyle != 'any' && event.lifestyle != filters.lifestyle) {
    return false;
  }
  if (filters.gender != 'any' && event.genderMode != filters.gender) {
    return false;
  }
  if (filters.access != 'any' && event.accessMode != filters.access) {
    return false;
  }
  if (filters.price != 'any' && !_matchesPrice(event, filters.price)) {
    return false;
  }
  return true;
}

bool _matchesQuickFilters(Event event, List<String> activeFilters) {
  for (final filter in activeFilters) {
    if (filter == 'Сегодня' && !event.time.startsWith('Сегодня')) {
      return false;
    }
    if (filter == 'Завтра' && !event.time.startsWith('Завтра')) {
      return false;
    }
    if (filter == 'Бесплатно' && event.priceMode != 'free') {
      return false;
    }
    if (filter == 'Рядом') {
      final distance = _distanceKm(event.distance);
      if (distance == null || distance > 1.5) {
        return false;
      }
    }
    if (filter == 'Спокойно' && !event.vibe.toLowerCase().contains('спокой')) {
      return false;
    }
    if (filter == 'Активно' && !event.vibe.toLowerCase().contains('актив')) {
      return false;
    }
  }

  return true;
}

bool _matchesEveningQuickFilters(
  EveningSessionSummary session,
  List<String> activeFilters,
) {
  final wantsLive = activeFilters.contains('Live');
  final wantsGathering = activeFilters.contains('Собираются');
  if ((wantsLive || wantsGathering) &&
      !((wantsLive && session.phase == EveningSessionPhase.live) ||
          (wantsGathering &&
              (session.phase == EveningSessionPhase.scheduled ||
                  session.chatPhase == MeetupPhase.soon ||
                  session.chatPhase == MeetupPhase.upcoming)))) {
    return false;
  }

  for (final filter in activeFilters) {
    if (filter == 'Завтра' || filter == 'Бесплатно') {
      return false;
    }
    if (filter == 'Рядом' && (session.area ?? '').isEmpty) {
      return false;
    }
    final vibe = '${session.title} ${session.vibe}'.toLowerCase();
    if (filter == 'Спокойно' && !vibe.contains('спокой')) {
      return false;
    }
    if (filter == 'Активно' && !vibe.contains('актив')) {
      return false;
    }
  }

  return true;
}

bool _matchesAfterDarkQuickFilters(
  AfterDarkEvent event,
  List<String> activeFilters,
) {
  for (final filter in activeFilters) {
    if (filter == 'Сегодня' && !event.time.startsWith('Сегодня')) {
      return false;
    }
    if (filter == 'Завтра' && !event.time.startsWith('Завтра')) {
      return false;
    }
    if (filter == 'Бесплатно' && (event.priceFrom ?? 0) > 0) {
      return false;
    }
    if (filter == 'Рядом' && event.distanceKm > 1.5) {
      return false;
    }
    final vibe = '${event.title} ${event.vibe}'.toLowerCase();
    if (filter == 'Спокойно' && !vibe.contains('тих')) {
      return false;
    }
    if (filter == 'Активно' && !vibe.contains('актив')) {
      return false;
    }
  }

  return true;
}

bool _matchesRouteQuickFilters(
  EveningRouteTemplateSummary route,
  List<String> activeFilters,
) {
  for (final filter in activeFilters) {
    if (filter == 'Бесплатно' && route.totalPriceFrom > 0) {
      return false;
    }
    final vibe = '${route.title} ${route.blurb} ${route.vibe}'.toLowerCase();
    if (filter == 'Спокойно' && !vibe.contains('спокой')) {
      return false;
    }
    if (filter == 'Активно' && !vibe.contains('актив')) {
      return false;
    }
  }

  return true;
}

bool _matchesPosterQuickFilters(Poster poster, List<String> activeFilters) {
  for (final filter in activeFilters) {
    if (filter == 'Бесплатно' && poster.priceFrom > 0) {
      return false;
    }
    if (filter == 'Рядом') {
      final distance = _distanceKm(poster.distance);
      if (distance == null || distance > 1.5) {
        return false;
      }
    }
    final haystack =
        '${poster.title} ${poster.description} ${poster.tags.join(' ')}'
            .toLowerCase();
    if (filter == 'Спокойно' && !haystack.contains('спокой')) {
      return false;
    }
    if (filter == 'Активно' && !haystack.contains('актив')) {
      return false;
    }
  }

  return true;
}

bool _matchesAfficheQuickFilters(
  AfficheEvent event,
  List<String> activeFilters,
) {
  for (final filter in activeFilters) {
    if (filter == 'Сегодня' &&
        (event.startsAt == null ||
            _isoDate(event.startsAt!) != _isoDate(DateTime.now()))) {
      return false;
    }
    if (filter == 'Завтра' &&
        (event.startsAt == null ||
            _isoDate(event.startsAt!) !=
                _isoDate(DateTime.now().add(const Duration(days: 1))))) {
      return false;
    }
    if (filter == 'Бесплатно' && !event.isFree) {
      return false;
    }
    if (filter == 'Рядом' && !event.hasCoords) {
      return false;
    }
    final haystack =
        '${event.title} ${event.description ?? ''} ${event.tags.join(' ')}'
            .toLowerCase();
    if (filter == 'Спокойно' && !haystack.contains('спокой')) {
      return false;
    }
    if (filter == 'Активно' && !haystack.contains('актив')) {
      return false;
    }
  }

  return true;
}

bool _matchesPrice(Event event, String price) {
  if (price == 'free') {
    return event.priceMode == 'free';
  }

  final amount = event.priceAmountTo ?? event.priceAmountFrom;
  if (amount == null) {
    return false;
  }

  switch (price) {
    case 'cheap':
      return amount <= 1000;
    case 'mid':
      return amount > 1000 && amount <= 3000;
    case 'premium':
      return amount > 3000;
    default:
      return true;
  }
}

String _isoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

double? _distanceKm(String distanceLabel) {
  final normalized = distanceLabel.replaceAll(',', '.');
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
  return match == null ? null : double.tryParse(match.group(1)!);
}

String _searchCity(Ref ref) {
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
