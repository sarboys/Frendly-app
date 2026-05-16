import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/frendly_season.dart';
import 'package:big_break_mobile/shared/models/paginated_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final frendlySeasonProvider =
    FutureProvider.autoDispose<FrendlySeasonData>((ref) {
  return ref.read(backendRepositoryProvider).fetchFrendlySeason();
});

final frendlyHistoryProvider =
    FutureProvider.autoDispose<PaginatedResponse<FrendlyHistoryItemData>>(
        (ref) {
  return ref.read(backendRepositoryProvider).fetchFrendlyHistory(limit: 20);
});

final frendlyPeopleProvider =
    FutureProvider.autoDispose<PaginatedResponse<FrendlyPersonData>>((ref) {
  return ref.read(backendRepositoryProvider).fetchFrendlyPeople(limit: 20);
});
