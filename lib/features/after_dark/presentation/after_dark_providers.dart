import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/after_dark/presentation/after_dark_models.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final afterDarkAccessProvider =
    FutureProvider<AfterDarkAccessData>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  await authBootstrap;
  return repository.fetchAfterDarkAccess();
});

final afterDarkEventsProvider =
    FutureProvider.autoDispose<List<AfterDarkEvent>>((ref) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository
      .fetchAfterDarkEvents(cancelToken: cancelToken)
      .then((value) => value.items);
});

final afterDarkEventDetailProvider = FutureProvider.autoDispose
    .family<AfterDarkEventDetail, String>((ref, eventId) async {
  final authBootstrap = ref.watch(authBootstrapProvider.future);
  final repository = ref.read(backendRepositoryProvider);
  final cancelToken = _autoDisposeCancelToken(ref);
  await authBootstrap;
  return repository.fetchAfterDarkEventDetail(eventId,
      cancelToken: cancelToken);
});

CancelToken _autoDisposeCancelToken(Ref ref) {
  final cancelToken = CancelToken();
  ref.onDispose(() {
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('provider_disposed');
    }
  });
  return cancelToken;
}

Future<void> openAfterDarkEntry(BuildContext context, WidgetRef ref) async {
  final accessFuture = ref.read(afterDarkAccessProvider.future);
  final access = await accessFuture;
  if (!context.mounted) {
    return;
  }

  await context.pushRoute(
    access.unlocked ? AppRoute.afterDark : AppRoute.afterDarkPaywall,
  );
}
