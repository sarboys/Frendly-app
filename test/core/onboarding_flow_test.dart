import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('onboarding save updates current user city before profile refetch',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _OnboardingSaveRepository(fetchMeFails: true);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        backendRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentUserProvider.notifier).state = const BackendUser(
      id: 'user-1',
      name: 'Алекс',
      onboardingComplete: false,
    );

    await container.read(onboardingFlowControllerProvider).save(
          const OnboardingData(
            name: 'Алекс',
            gender: 'male',
            city: 'Нижневартовск',
            area: 'Ханты-Мансийский автономный округ',
          ),
        );

    final user = container.read(currentUserProvider);
    expect(user?.onboardingComplete, isTrue);
    expect(user?.city, 'Нижневартовск');
  });
}

class _OnboardingSaveRepository extends BackendRepository {
  _OnboardingSaveRepository({required this.fetchMeFails}) : super(Dio());

  final bool fetchMeFails;

  @override
  Future<OnboardingData> saveOnboarding(
    OnboardingData data, {
    CancelToken? cancelToken,
  }) async {
    return data;
  }

  @override
  Future<BackendUser> fetchMe({CancelToken? cancelToken}) async {
    if (fetchMeFails) {
      throw DioException(requestOptions: RequestOptions(path: '/profile/me'));
    }
    return const BackendUser(
      id: 'user-1',
      name: 'Алекс',
      onboardingComplete: true,
      city: 'Нижневартовск',
    );
  }
}
