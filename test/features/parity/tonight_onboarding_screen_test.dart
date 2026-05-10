import 'package:big_break_mobile/app/core/maps/mapkit_bootstrap.dart';
import 'package:big_break_mobile/app/core/maps/yandex_map_service.dart';
import 'package:big_break_mobile/app/core/device/app_location_service.dart';
import 'package:big_break_mobile/app/core/device/app_permission_service.dart';
import 'package:big_break_mobile/app/core/device/app_reverse_geocoding_service.dart';
import 'package:big_break_mobile/app/navigation/app_router.dart';
import 'package:big_break_mobile/app/navigation/app_routes.dart';
import 'package:big_break_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:big_break_mobile/features/tonight/presentation/tonight_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/onboarding_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' show Point;

import '../../test_overrides.dart';

Widget _wrap(
  Widget child, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      ...extraOverrides,
    ],
    child: MaterialApp(home: child),
  );
}

Future<void> _completeFirstOnboardingStep(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Друзья'));
  await _tapVisible(tester, find.byKey(const Key('onboarding-gender-male')));
  await tester.tap(find.text('Дальше'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();

  for (var i = 0; i < 4; i += 1) {
    final rect = tester.getRect(finder);
    if (rect.center.dy < 470) {
      break;
    }
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -90),
    );
    await tester.pumpAndSettle();
  }

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pressPrimaryAction(WidgetTester tester, String label) async {
  final button =
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
  button.onPressed?.call();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding exposes the v5 seven-step flow', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Шаг 1 из 7'), findsOneWidget);
    expect(find.text('Зачем ты здесь?'), findsOneWidget);
  });

  testWidgets('tonight screen links the new personal Frendly surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const TonightScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Твоё в Frendly'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Перки'), findsOneWidget);
    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('Сказать вслух'), findsWidgets);
  });

  testWidgets('onboarding asks phone and sms users for email before profile',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
              requiredContact: OnboardingContactRequirement.email,
            ),
          ),
          backendRepositoryProvider.overrideWith(
            (ref) => _SuccessfulContactRepository(ref: ref),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Укажи email'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Укажи email'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-email-field')),
      'not-email',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Укажи email'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-email-field')),
      'user@example.com',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Дальше'));
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Когда у тебя день рождения?'), findsOneWidget);
  });

  testWidgets('onboarding asks google and yandex users for phone with country',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
              requiredContact: OnboardingContactRequirement.phone,
            ),
          ),
          backendRepositoryProvider.overrideWith(
            (ref) => _SuccessfulContactRepository(ref: ref),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Укажи телефон'), findsOneWidget);
    expect(find.text('🇷🇺 +7'), findsOneWidget);

    await tester.tap(find.text('🇷🇺 +7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Беларусь'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('onboarding-phone-field')), '29 123 45 67');
    await tester.pump();
    await tester.ensureVisible(find.text('Дальше'));
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Когда у тебя день рождения?'), findsOneWidget);
  });

  testWidgets('onboarding blocks duplicate email on contact step',
      (tester) async {
    late _DuplicateContactRepository repository;

    await tester.pumpWidget(
      _wrapOnboardingFlow(
        (ref) => repository = _DuplicateContactRepository(ref: ref),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
              requiredContact: OnboardingContactRequirement.email,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onboarding-email-field')),
      'Used@Example.COM',
    );
    await tester.pump();
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!.call();
    await tester.pumpAndSettle();

    expect(repository.checkedEmail, 'used@example.com');
    expect(find.text('Эта почта уже привязана к другому аккаунту'),
        findsOneWidget);
    expect(find.text('Укажи email'), findsOneWidget);
    expect(find.text('Дата рождения'), findsNothing);
  });

  testWidgets('onboarding blocks duplicate phone on contact step',
      (tester) async {
    late _DuplicateContactRepository repository;

    await tester.pumpWidget(
      _wrapOnboardingFlow(
        (ref) => repository = _DuplicateContactRepository(ref: ref),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
              requiredContact: OnboardingContactRequirement.phone,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onboarding-phone-field')),
      '999 000 00 00',
    );
    await tester.pump();
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!.call();
    await tester.pumpAndSettle();

    expect(repository.checkedPhoneNumber, '+79990000000');
    expect(find.text('Этот телефон уже привязан к другому аккаунту'),
        findsOneWidget);
    expect(find.text('Укажи телефон'), findsOneWidget);
    expect(find.text('Дата рождения'), findsNothing);
  });

  testWidgets('onboarding birthday step opens date picker', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);
    await tester.enterText(find.byType(TextField), 'Москва');
    await tester.pump();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кофе'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кино'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Спокойно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-birth-date-picker')));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('onboarding includes all front interests', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);
    await tester.enterText(find.byType(TextField), 'Покровка, Москва');
    await tester.pump();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Походы'), findsOneWidget);
    expect(find.text('Фото'), findsOneWidget);
  });

  testWidgets('onboarding back button returns to previous step',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);

    expect(find.text('Где ты?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();

    expect(find.text('Зачем ты здесь?'), findsOneWidget);
    expect(find.text('Где ты?'), findsNothing);
  });

  testWidgets('onboarding opens tonight after one final tap with setup guard',
      (tester) async {
    late _RecordingOnboardingRepository repository;

    await tester.pumpWidget(
      _wrapGuardedOnboardingFlow(
        (ref) => repository = _RecordingOnboardingRepository(ref: ref),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async {
              final localValue = ref.watch(onboardingLocalStateProvider);
              if (localValue != null) {
                return localValue;
              }
              return const OnboardingData(
                intent: null,
                gender: null,
                city: null,
                area: null,
                interests: [],
                vibe: null,
              );
            },
          ),
          appPermissionServiceProvider.overrideWithValue(
            const _AllowPermissionService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);
    await tester.enterText(find.byType(TextField), 'Москва');
    await tester.pump();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кофе'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кино'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Спокойно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-birth-date-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('birth-date-sheet-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboarding-email-field')),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Разрешить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Войти в Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(find.text('tonight-opened'), findsOneWidget);
  });

  testWidgets('onboarding location step uses address input and geo CTA',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);

    expect(find.text('Адрес или город'), findsOneWidget);
    expect(find.text('Определить по гео'), findsOneWidget);
    expect(find.text('Москва'), findsNothing);
    expect(find.text('Чистые пруды'), findsNothing);
  });

  testWidgets('onboarding requires a location before continuing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);
    await _pressPrimaryAction(tester, 'Дальше');

    expect(find.text('Где ты?'), findsOneWidget);
    expect(find.text('Что тебе нравится?'), findsNothing);
  });

  testWidgets('onboarding location step shows yandex suggestions',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
          yandexMapServiceProvider.overrideWithValue(
            _FakeYandexMapService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);
    await tester.enterText(find.byType(TextField), 'Покровка');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Покровка 17'), findsOneWidget);
    expect(find.text('Покровка 19'), findsOneWidget);
  });

  testWidgets('onboarding saves only city from address suggestion',
      (tester) async {
    late _RecordingOnboardingRepository repository;

    await tester.pumpWidget(
      _wrapOnboardingFlow(
        (ref) => repository = _RecordingOnboardingRepository(ref: ref),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
          yandexMapServiceProvider.overrideWithValue(
            _FakeYandexMapService(),
          ),
          appPermissionServiceProvider.overrideWithValue(
            const _AllowPermissionService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _completeFirstOnboardingStep(tester);
    await tester.enterText(find.byType(TextField), 'Покровка');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('Покровка 17'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кофе'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кино'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Спокойно'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-birth-date-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('birth-date-sheet-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboarding-email-field')),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Разрешить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Войти в Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved?.city, 'Москва');
    expect(repository.saved?.area, isNull);
    expect(find.text('tonight-opened'), findsOneWidget);
  });

  testWidgets('onboarding requires gender selection before continuing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-gender-male')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-gender-female')), findsOneWidget);
    expect(find.text('М'), findsOneWidget);
    expect(find.text('Ж'), findsOneWidget);
    expect(find.text('Мужчина'), findsNothing);
    expect(find.text('Женщина'), findsNothing);

    await _tapVisible(tester, find.text('Друзья'));
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Зачем ты здесь?'), findsOneWidget);
    expect(find.text('Где ты?'), findsNothing);
  });

  testWidgets('onboarding requires a permission choice before final save',
      (tester) async {
    _RecordingOnboardingRepository? repository;

    await tester.pumpWidget(
      _wrapOnboardingFlow(
        (ref) => repository = _RecordingOnboardingRepository(ref: ref),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: 'both',
              gender: 'male',
              birthDate: '2000-04-24',
              city: 'Москва',
              area: 'Чистые пруды',
              interests: ['Кофе'],
              vibe: 'calm',
              email: 'user@example.com',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i += 1) {
      await _pressPrimaryAction(tester, 'Дальше');
    }

    expect(find.text('Несколько разрешений'), findsOneWidget);
    expect(find.text('Пропустить и настроить позже'), findsNothing);

    await _pressPrimaryAction(tester, 'Войти в Frendly');

    expect(repository?.saved, isNull);
    expect(find.text('Несколько разрешений'), findsOneWidget);
  });

  testWidgets('onboarding first step fits above fixed CTA on phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrap(
        const OnboardingScreen(),
        extraOverrides: [
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: null,
              gender: null,
              city: null,
              area: null,
              interests: [],
              vibe: null,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final lastOptionBottom =
        tester.getBottomLeft(find.text('И то и другое')).dy;
    final ctaTop = tester.getTopLeft(find.text('Дальше')).dy;

    expect(lastOptionBottom, lessThan(ctaTop - 16));
  });

  testWidgets('tonight header uses HomeV5 AI action instead of notification UI',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          notificationUnreadCountProvider.overrideWith((ref) async => 3),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tonight-notification-dot')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tonight-notification-bell-shake')),
      findsNothing,
    );
  });

  testWidgets('tonight header does not use onboarding city as geolocation',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          appLocationServiceProvider.overrideWithValue(
            const _NoLocationService(),
          ),
          onboardingProvider.overrideWith(
            (ref) async => const OnboardingData(
              intent: 'both',
              gender: 'male',
              city: 'Санкт-Петербург',
              area: 'Петроградка',
              interests: ['Кофе', 'Кино'],
              vibe: 'calm',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Геолокация недоступна'), findsOneWidget);
    expect(find.text('Санкт-Петербург · Петроградка'), findsNothing);
    expect(find.text('Чистые пруды'), findsNothing);
  });

  testWidgets('tonight header uses current city and street from geolocation',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          appLocationServiceProvider.overrideWithValue(
            const _FakeAppLocationService(),
          ),
          yandexMapServiceProvider.overrideWithValue(_FakeYandexMapService()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Москва - улица Покровка'), findsOneWidget);
    expect(find.textContaining('17'), findsNothing);
    expect(find.text('Москва · Чистые пруды'), findsNothing);
  });

  testWidgets('tonight header lets user choose manual location', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          appLocationServiceProvider.overrideWithValue(
            const _FakeAppLocationService(
              latitude: 12.2388,
              longitude: 109.1967,
            ),
          ),
          yandexMapServiceProvider.overrideWithValue(
            _ManualLocationYandexMapService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nha Trang - Đường Trần Phú'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tonight-location-button')));
    await tester.pumpAndSettle();

    expect(find.text('Где ты сейчас'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('tonight-location-input')),
      'Покровка',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Покровка 17'));
    await tester.pumpAndSettle();

    expect(find.text('Москва - Покровка'), findsOneWidget);
    expect(find.text('Nha Trang - Đường Trần Phú'), findsNothing);
  });

  testWidgets('tonight location search can switch away from saved city', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          manualLocationProvider.overrideWith((ref) {
            return ManualLocationController(null)
              ..setLocation(
                const ManualLocation(
                  label: 'Санкт-Петербург - Невский проспект',
                  latitude: 59.9386,
                  longitude: 30.3141,
                  city: 'Санкт-Петербург',
                ),
              );
          }),
          yandexMapServiceProvider.overrideWithValue(
            _ManualLocationYandexMapService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Санкт-Петербург - Невский проспект'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tonight-location-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tonight-location-input')),
      'Москва',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Москва'), findsWidgets);
    expect(find.textContaining('Алматы'), findsNothing);
  });

  testWidgets('tonight header uses Vietnamese city and street from geolocation',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          appLocationServiceProvider.overrideWithValue(
            const _FakeAppLocationService(
              latitude: 12.2388,
              longitude: 109.1967,
            ),
          ),
          yandexMapServiceProvider.overrideWithValue(
            _VietnamYandexMapService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nha Trang - Đường Trần Phú'), findsOneWidget);
    expect(find.textContaining('Việt Nam'), findsNothing);
    expect(find.text('Москва · Чистые пруды'), findsNothing);
  });

  testWidgets('tonight header does not depend on a country allowlist',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          appLocationServiceProvider.overrideWithValue(
            const _FakeAppLocationService(
              latitude: 1,
              longitude: 2,
            ),
          ),
          yandexMapServiceProvider.overrideWithValue(
            _GenericCountryYandexMapService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sample City - River Road'), findsOneWidget);
    expect(find.textContaining('Countryland'), findsNothing);
    expect(find.textContaining('Central Province'), findsNothing);
  });

  testWidgets('tonight header uses native geocoder when yandex geocode fails',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          appLocationServiceProvider.overrideWithValue(
            const _FakeAppLocationService(
              latitude: 12.2388,
              longitude: 109.1967,
            ),
          ),
          yandexMapServiceProvider.overrideWithValue(
            _NoAddressYandexMapService(),
          ),
          appReverseGeocodingServiceProvider.overrideWithValue(
            const _FakeReverseGeocodingService(
              city: 'Nha Trang',
              street: 'Đường Trần Phú',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nha Trang - Đường Trần Phú'), findsOneWidget);
    expect(find.text('Геолокация недоступна'), findsNothing);
  });

  testWidgets('tonight header falls back to coordinates when geocoders fail',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TonightScreen(),
        extraOverrides: [
          appLocationServiceProvider.overrideWithValue(
            const _FakeAppLocationService(
              latitude: 12.2388,
              longitude: 109.1967,
            ),
          ),
          yandexMapServiceProvider.overrideWithValue(
            _NoAddressYandexMapService(),
          ),
          appReverseGeocodingServiceProvider.overrideWithValue(
            const _NoReverseGeocodingService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12.23880, 109.19670'), findsOneWidget);
    expect(find.text('Геолокация недоступна'), findsNothing);
  });

  testWidgets('tonight renders HomeV5 affiche section', (tester) async {
    await tester.pumpWidget(_wrap(const TonightScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Афиша города'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Афиша города'), findsOneWidget);
    expect(find.text('Афиша рядом'), findsNothing);
  });
}

class _NoopMapkitBootstrap implements MapkitBootstrap {
  const _NoopMapkitBootstrap();

  @override
  Future<void> ensureInitialized() async {}
}

class _FakeYandexMapService extends YandexMapService {
  _FakeYandexMapService() : super(bootstrap: const _NoopMapkitBootstrap());

  @override
  Future<List<ResolvedAddress>> searchPlaces(
    String query, {
    Point? near,
    bool geocodeFirst = false,
  }) async {
    if (query.trim().toLowerCase() == 'москва') {
      if (!geocodeFirst) {
        return const [
          ResolvedAddress(
            name: 'Москва',
            address: 'Алматы, проспект Абая',
            point: Point(latitude: 43.2389, longitude: 76.8897),
            city: 'Алматы',
          ),
        ];
      }
      return const [
        ResolvedAddress(
          name: 'Москва',
          address: 'Россия, Москва',
          point: Point(latitude: 55.7558, longitude: 37.6173),
          city: 'Москва',
        ),
      ];
    }
    return const [
      ResolvedAddress(
        name: 'Покровка 17',
        address: 'Москва, Покровка 17',
        point: Point(latitude: 55.757, longitude: 37.648),
        category: 'Яндекс',
      ),
      ResolvedAddress(
        name: 'Покровка 19',
        address: 'Москва, Покровка 19',
        point: Point(latitude: 55.758, longitude: 37.649),
        category: 'Яндекс',
      ),
    ];
  }

  @override
  Future<ResolvedAddress?> reverseGeocode(Point point) async {
    return const ResolvedAddress(
      name: 'улица Покровка, 17',
      address: 'Россия, Москва, улица Покровка, 17',
      point: Point(latitude: 55.757, longitude: 37.648),
    );
  }
}

class _ManualLocationYandexMapService extends YandexMapService {
  _ManualLocationYandexMapService()
      : super(bootstrap: const _NoopMapkitBootstrap());

  @override
  Future<List<ResolvedAddress>> searchPlaces(
    String query, {
    Point? near,
    bool geocodeFirst = false,
  }) async {
    return const [
      ResolvedAddress(
        name: 'Покровка 17',
        address: 'Россия, Москва, Покровка 17',
        point: Point(latitude: 55.757, longitude: 37.648),
        city: 'Москва',
        street: 'Покровка',
      ),
    ];
  }

  @override
  Future<ResolvedAddress?> searchAddress(
    String query, {
    Point? near,
  }) async {
    return const ResolvedAddress(
      name: 'Покровка 17',
      address: 'Россия, Москва, Покровка 17',
      point: Point(latitude: 55.757, longitude: 37.648),
      city: 'Москва',
      street: 'Покровка',
    );
  }

  @override
  Future<ResolvedAddress?> reverseGeocode(Point point) async {
    return const ResolvedAddress(
      name: 'Đường Trần Phú, 86',
      address: 'Việt Nam, Khánh Hòa Province, Nha Trang, Đường Trần Phú, 86',
      point: Point(latitude: 12.2388, longitude: 109.1967),
      city: 'Nha Trang',
      street: 'Đường Trần Phú',
    );
  }
}

class _VietnamYandexMapService extends YandexMapService {
  _VietnamYandexMapService() : super(bootstrap: const _NoopMapkitBootstrap());

  @override
  Future<ResolvedAddress?> reverseGeocode(Point point) async {
    return const ResolvedAddress(
      name: 'Đường Trần Phú, 86',
      address: 'Việt Nam, Khánh Hòa Province, Nha Trang, Đường Trần Phú, 86',
      point: Point(latitude: 12.2388, longitude: 109.1967),
    );
  }
}

class _GenericCountryYandexMapService extends YandexMapService {
  _GenericCountryYandexMapService()
      : super(bootstrap: const _NoopMapkitBootstrap());

  @override
  Future<ResolvedAddress?> reverseGeocode(Point point) async {
    return const ResolvedAddress(
      name: 'River Road, 8',
      address: 'Countryland, Central Province, Sample City, River Road, 8',
      point: Point(latitude: 1, longitude: 2),
    );
  }
}

class _NoAddressYandexMapService extends YandexMapService {
  _NoAddressYandexMapService() : super(bootstrap: const _NoopMapkitBootstrap());

  @override
  Future<ResolvedAddress?> reverseGeocode(Point point) async => null;
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

class _NoReverseGeocodingService implements AppReverseGeocodingService {
  const _NoReverseGeocodingService();

  @override
  Future<ReverseGeocodedLocation?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return null;
  }
}

class _FakeAppLocationService implements AppLocationService {
  const _FakeAppLocationService({
    this.latitude = 55.757,
    this.longitude = 37.648,
  });

  final double latitude;
  final double longitude;

  @override
  Future<Position?> getCurrentPosition() async {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 4, 30),
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

class _NoLocationService implements AppLocationService {
  const _NoLocationService();

  @override
  Future<Position?> getCurrentPosition() async => null;

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

class _AllowPermissionService implements AppPermissionService {
  const _AllowPermissionService();

  @override
  Future<bool> requestContacts() async => true;

  @override
  Future<bool> requestCamera() async => true;

  @override
  Future<bool> requestLocation() async => true;

  @override
  Future<bool> requestMicrophone() async => true;

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<bool> requestPhotos() async => true;
}

class _RecordingOnboardingRepository extends BackendRepository {
  _RecordingOnboardingRepository({
    required super.ref,
  }) : super(dio: Dio());

  OnboardingData? saved;

  @override
  Future<OnboardingData> saveOnboarding(OnboardingData data) async {
    saved = data;
    return data;
  }
}

class _DuplicateContactRepository extends BackendRepository {
  _DuplicateContactRepository({
    required super.ref,
  }) : super(dio: Dio());

  String? checkedEmail;
  String? checkedPhoneNumber;

  @override
  Future<void> checkOnboardingContact({
    String? email,
    String? phoneNumber,
  }) async {
    checkedEmail = email;
    checkedPhoneNumber = phoneNumber;
    throw DioException(
      requestOptions: RequestOptions(path: '/onboarding/contact/check'),
      response: Response(
        requestOptions: RequestOptions(path: '/onboarding/contact/check'),
        statusCode: 409,
        data: const {
          'code': 'contact_already_used',
        },
      ),
    );
  }
}

class _SuccessfulContactRepository extends BackendRepository {
  _SuccessfulContactRepository({
    required super.ref,
  }) : super(dio: Dio());

  @override
  Future<void> checkOnboardingContact({
    String? email,
    String? phoneNumber,
  }) async {}
}

Widget _wrapOnboardingFlow(
  BackendRepository Function(Ref ref) createRepository, {
  List<Override> extraOverrides = const [],
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ProviderScope(
          overrides: [
            ...buildTestOverrides(),
            backendRepositoryProvider.overrideWith(createRepository),
            ...extraOverrides,
          ],
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoute.addPhoto.path,
        name: AppRoute.addPhoto.name,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('add-photo-opened')),
        ),
      ),
      GoRoute(
        path: AppRoute.tonight.path,
        name: AppRoute.tonight.name,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('tonight-opened')),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

Widget _wrapGuardedOnboardingFlow(
  BackendRepository Function(Ref ref) createRepository, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      backendRepositoryProvider.overrideWith(createRepository),
      ...extraOverrides,
    ],
    child: const _GuardedOnboardingApp(),
  );
}

class _GuardedOnboardingApp extends ConsumerStatefulWidget {
  const _GuardedOnboardingApp();

  @override
  ConsumerState<_GuardedOnboardingApp> createState() =>
      _GuardedOnboardingAppState();
}

class _GuardedOnboardingAppState extends ConsumerState<_GuardedOnboardingApp> {
  late final ValueNotifier<String?> _pendingSetupNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _pendingSetupNotifier = ValueNotifier<String?>(AppRoute.onboarding.path);
    _router = GoRouter(
      initialLocation: AppRoute.onboarding.path,
      refreshListenable: _pendingSetupNotifier,
      redirect: (context, state) {
        final pendingSetup = _pendingSetupNotifier.value;
        if (pendingSetup != null && state.uri.path != pendingSetup) {
          return pendingSetup;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoute.onboarding.path,
          name: AppRoute.onboarding.name,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoute.addPhoto.path,
          name: AppRoute.addPhoto.name,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('add-photo-opened')),
          ),
        ),
        GoRoute(
          path: AppRoute.tonight.path,
          name: AppRoute.tonight.name,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('tonight-opened')),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _pendingSetupNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);
    final pendingSetup = onboarding.hasValue
        ? resolvePendingSetupRoute(onboarding.valueOrNull)
        : null;
    if (_pendingSetupNotifier.value != pendingSetup) {
      _pendingSetupNotifier.value = pendingSetup;
    }

    return MaterialApp.router(routerConfig: _router);
  }
}
