import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/local_cache/app_local_database.dart';
import 'package:mobile2/app/core/local_cache/chat_local_store.dart';
import 'package:mobile2/app/core/device/app_attachment_service.dart';
import 'package:mobile2/app/core/network/chat_socket_client.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/app/dateasy_app.dart';
import 'package:mobile2/features/ai_builder/presentation/ai_builder_result_screen.dart';
import 'package:mobile2/features/ai_builder/presentation/ai_builder_screen.dart';
import 'package:mobile2/features/chats/presentation/meeting_chat_screen.dart';
import 'package:mobile2/features/communities/presentation/community_chat_screen.dart';
import 'package:mobile2/features/city/presentation/city_screen.dart';
import 'package:mobile2/features/dating/presentation/dating_filter_screen.dart';
import 'package:mobile2/features/host/presentation/host_dashboard_screen.dart';
import 'package:mobile2/features/home/presentation/home_screen.dart';
import 'package:mobile2/features/map/presentation/map_screen.dart';
import 'package:mobile2/features/meetings/presentation/meeting_detail_screen.dart';
import 'package:mobile2/features/meetings/presentation/meetings_screen.dart';
import 'package:mobile2/features/meetings/presentation/new_meeting_screen.dart';
import 'package:mobile2/features/paywall/presentation/paywall_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_edit_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_gallery_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_history_screen.dart';
import 'package:mobile2/features/profile/presentation/profile_screen.dart';
import 'package:mobile2/features/profile/presentation/public_user_screen.dart';
import 'package:mobile2/features/settings/presentation/settings_screen.dart';
import 'package:mobile2/features/share/presentation/share_screen.dart';
import 'package:mobile2/features/sos/presentation/sos_screen.dart';
import 'package:mobile2/features/splash/presentation/splash_screen.dart';
import 'package:mobile2/features/stories/presentation/stories_screen.dart';
import 'package:mobile2/features/verify/presentation/verify_screen.dart';
import 'package:mobile2/features/wallet/presentation/wallet_screen.dart';
import 'package:mobile2/features/onboarding/presentation/onboarding_screen.dart';
import 'package:mobile2/features/onboarding/application/onboarding_permission_service.dart';
import 'package:mobile2/features/welcome/application/google_auth_client.dart';
import 'package:mobile2/features/welcome/application/yandex_auth_client.dart';
import 'package:mobile2/features/welcome/presentation/welcome_screen.dart';
import 'package:mobile2/app/core/local_cache/app_cache_key.dart';
import 'package:mobile2/shared/data/affiche_client_geo_enrichment_service.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/data/backend_repository.dart';
import 'package:mobile2/shared/data/city_search_service.dart';
import 'package:mobile2/shared/data/yandex_city_search_service.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/utils/frendly_legal_links.dart';
import 'package:mobile2/shared/widgets/dateasy_top_bar.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  testWidgets('mobile2 opens welcome and opens phone auth', (tester) async {
    await _pumpDateasyAppWelcome(tester);

    expect(find.textContaining('Реальные'), findsOneWidget);
    expect(find.textContaining('встречи'), findsOneWidget);

    expect(find.text('Войти по номеру телефона'), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-google-auth')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-yandex-auth')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-apple-auth')), findsNothing);
    expect(
      find.byKey(const ValueKey('welcome-telegram-auth')),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Войти по номеру телефона'));
    await tester.pumpAndSettle();

    expect(find.text('Введи номер телефона'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);

    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();

    expect(find.text('Код из SMS'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, '9991234567');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();

    expect(find.text('Код из SMS'), findsOneWidget);
    expect(find.text('Отправить код снова'), findsOneWidget);

    final inputs = find.byType(EditableText);
    await tester.enterText(inputs.at(0), '1');
    await tester.enterText(inputs.at(1), '2');
    await tester.enterText(inputs.at(2), '3');
    await tester.enterText(inputs.at(3), '4');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    expect(find.text('Зачем ты в Frendly?'), findsOneWidget);
  });

  testWidgets('welcome shows apple auth only on iOS', (tester) async {
    await _pumpWelcomeScreenForPlatform(tester, TargetPlatform.android);

    expect(find.byKey(const ValueKey('welcome-apple-auth')), findsNothing);

    await _pumpWelcomeScreenForPlatform(tester, TargetPlatform.iOS);

    expect(find.byKey(const ValueKey('welcome-google-auth')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-yandex-auth')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-apple-auth')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('welcome-telegram-auth')),
      findsOneWidget,
    );
  });

  testWidgets('welcome opens legal pages before auth and returns back',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDateasyAppWelcome(tester);

    expect(find.byKey(const ValueKey('welcome-legal-terms')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-legal-privacy')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('welcome-legal-community-rules')),
      findsOneWidget,
    );

    await tester
        .ensureVisible(find.byKey(const ValueKey('welcome-legal-terms')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcome-legal-terms')));
    await tester.pumpAndSettle();

    expect(find.text('Пользовательское соглашение (EULA)'), findsOneWidget);
    expect(find.textContaining('Frendly'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('legal-back-to-welcome')));
    await tester.pumpAndSettle();

    expect(find.text('Войти по номеру телефона'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('welcome-legal-privacy')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcome-legal-privacy')));
    await tester.pumpAndSettle();
    expect(find.text('Политика конфиденциальности'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('legal-back-to-welcome')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('welcome-legal-community-rules')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('welcome-legal-community-rules')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Правила сообщества'), findsOneWidget);
  });

  testWidgets('mobile2 opens telegram auth and confirms code', (tester) async {
    await _pumpDateasyAppWelcome(tester);

    await tester.tap(find.byKey(const ValueKey('welcome-telegram-auth')));
    await tester.pumpAndSettle();

    expect(find.text('Вход через Telegram'), findsOneWidget);
    expect(find.textContaining('@frendly_code_bot'), findsOneWidget);
    expect(find.text('Подтвердить'), findsNothing);

    await tester.tap(find.text('Открыть Telegram'));
    await tester.pumpAndSettle();

    expect(find.text('Введи 4-значный код из бота'), findsOneWidget);
    expect(find.text('Подтвердить'), findsOneWidget);

    await tester.ensureVisible(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();

    expect(find.text('Зачем ты в Frendly?'), findsNothing);

    await tester.enterText(find.byType(EditableText).last, '1234');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();

    expect(find.text('Зачем ты в Frendly?'), findsOneWidget);
  });

  testWidgets('welcome shows auth progress while google verifies session',
      (tester) async {
    final repository = _DelayedAuthRepository();
    await tester.pumpWidget(
      DateasyApp(
        overrides: [
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
          backendRepositoryProvider.overrideWithValue(repository),
          googleAuthClientProvider.overrideWithValue(
            GoogleAuthClient(
              gateway: _FakeGoogleAuthGateway(idToken: 'google-id-token'),
              clientId: 'test-client',
              serverClientId: 'test-server',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-google-auth')));
    await tester.pump();

    expect(find.text('Авторизуем...'), findsOneWidget);

    repository.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('welcome shows auth progress while yandex verifies session',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(yandexAuthChannel, (call) async {
      expect(call.method, 'signIn');
      return 'yandex-oauth-token';
    });
    try {
      final repository = _DelayedAuthRepository();
      await tester.pumpWidget(
        DateasyApp(
          overrides: [
            appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
            backendRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('welcome-yandex-auth')));
      await tester.pump();

      expect(find.text('Авторизуем...'), findsOneWidget);

      repository.complete();
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(yandexAuthChannel, null);
    }
  });

  testWidgets('telegram auth shows auth progress while verifying code',
      (tester) async {
    final repository = _DelayedAuthRepository();
    await _pumpDateasyAppWelcome(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('welcome-telegram-auth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть Telegram'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '1234');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Подтвердить'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Подтвердить'));
    await tester.pump();

    expect(find.text('Авторизуем...'), findsOneWidget);

    repository.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('mobile2 onboarding walks through Frendly steps', (tester) async {
    await _pumpDateasyAppWelcome(tester);

    await tester.tap(find.text('Войти по номеру телефона'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, '9991234567');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();

    final inputs = find.byType(EditableText);
    await tester.enterText(inputs.at(0), '1');
    await tester.enterText(inputs.at(1), '2');
    await tester.enterText(inputs.at(2), '3');
    await tester.enterText(inputs.at(3), '4');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    expect(find.text('Зачем ты в Frendly?'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);

    const expectedSteps = [
      'Твой пол',
      'Где ты сейчас?',
      'Что тебе по кайфу?',
      'Какой твой вайб?',
      'Твой день рождения',
      'Добавь фото',
      'Контакты',
      'Расскажите немного о себе',
      'Разрешения',
    ];

    for (final title in expectedSteps) {
      if (title == 'Расскажите немного о себе') {
        await tester.enterText(find.byType(EditableText).first, 'Алекс');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }

    expect(find.text('В Frendly'), findsOneWidget);
    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(find.text('Привет, Алекс 👋'), findsOneWidget);
    await tester.drag(find.text('Привет, Алекс 👋'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Ближайшие встречи'), findsOneWidget);
    await tester.drag(find.text('Ближайшие встречи'), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('AI DATE BUILDER'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.calendarHeart));
    await tester.pumpAndSettle();

    expect(find.text('10+ встреч рядом'), findsOneWidget);
    expect(find.text('Список '), findsNothing);
    expect(find.text('AI подберёт встречу под вечер'), findsOneWidget);
    expect(find.text('Speciality coffee tasting'), findsOneWidget);

    await tester.ensureVisible(find.text('Иду').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Иду').first);
    await tester.pumpAndSettle();
    expect(find.text('✓ Иду'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding blocks next until required choices are set',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      initialOnboarding: const OnboardingData(),
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Знакомиться'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Твой пол'), findsOneWidget);

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Твой пол'), findsOneWidget);
    expect(find.text('Где ты сейчас?'), findsNothing);

    await tester.tap(find.text('Мужской'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Где ты сейчас?'), findsOneWidget);

    await tester.tap(find.text('Москва'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Что тебе по кайфу?'), findsOneWidget);

    await tester.tap(find.text('🎵 Музыка'));
    await tester.tap(find.text('☕ Кофе'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Что тебе по кайфу?'), findsOneWidget);
    expect(find.text('Какой твой вайб?'), findsNothing);

    await tester.tap(find.text('🍷 Вино'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Какой твой вайб?'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding shows date error for invalid typed birthday',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      initialOnboarding: const OnboardingData(
        intent: 'Знакомиться',
        gender: 'male',
        city: 'Москва',
        interests: ['🎵 Музыка', '☕ Кофе', '🍷 Вино'],
        vibe: 'Чилл',
        raw: _onboardingRawWithTwoPhotos,
      ),
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Твой день рождения'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '31.02.2000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Твой день рождения'), findsOneWidget);
    expect(find.text('Введите реальную дату рождения'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding contact name starts empty and is required',
      (tester) async {
    final repository = _RecordingOnboardingRepository();

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 7; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Контакты'), findsOneWidget);
    final nameInput = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(nameInput.controller.text, isEmpty);

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('Расскажите немного о себе'), findsNothing);
  });

  testWidgets(
      'mobile2 onboarding ignores generated phone name and requires real name',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      initialOnboarding: const OnboardingData(
        name: 'Пользователь 1234',
        intent: 'Знакомиться',
        gender: 'male',
        birthDate: '1998-05-21',
        city: 'Москва',
        interests: ['🎵 Музыка', '☕ Кофе', '🍷 Вино'],
        vibe: 'Чилл',
        raw: _onboardingRawWithTwoPhotos,
      ),
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 7; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Контакты'), findsOneWidget);
    final nameInput = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(nameInput.controller.text, isEmpty);

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('Расскажите немного о себе'), findsNothing);
  });

  testWidgets('mobile2 onboarding enables next after required email is entered',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      initialOnboarding: const OnboardingData(
        intent: 'Знакомиться',
        gender: 'male',
        birthDate: '1998-05-21',
        city: 'Москва',
        interests: ['🎵 Музыка', '☕ Кофе', '🍷 Вино'],
        vibe: 'Чилл',
        requiredContact: 'email',
        raw: _onboardingRawWithTwoPhotos,
      ),
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 7; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Контакты'), findsOneWidget);

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('Разрешения'), findsNothing);

    await tester.enterText(find.byType(EditableText).at(0), 'Алекс');
    await tester.enterText(find.byType(EditableText).at(1), 'alex@test.dev');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Расскажите немного о себе'), findsOneWidget);

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Разрешения'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding blocks next until two photos are uploaded',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      initialOnboarding: _completeOnboardingDataWithoutPhotos,
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 6; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Добавь фото'), findsOneWidget);
    expect(find.text('Контакты'), findsNothing);

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Добавь фото'), findsOneWidget);
    expect(find.text('Контакты'), findsNothing);
  });

  testWidgets('mobile2 onboarding saves contact name, phone and profile bio',
      (tester) async {
    final repository = _RecordingOnboardingRepository();

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 7; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('Ваше имя'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);

    final inputs = find.byType(EditableText);
    await tester.enterText(inputs.at(0), '  Нина  ');
    await tester.enterText(inputs.at(2), '9991234567');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Расскажите немного о себе'), findsOneWidget);
    await tester.enterText(
      find.byType(EditableText).first,
      'Люблю камерные встречи и прогулки по району.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved?.toJson()['displayName'], 'Нина');
    expect(repository.saved?.phoneNumber, '+79991234567');
    expect(
      repository.saved?.toJson()['bio'],
      'Люблю камерные встречи и прогулки по району.',
    );
    expect(find.text('home-opened complete=true'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding shows occupied phone contact error',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      initialOnboarding: const OnboardingData(
        name: 'Алекс',
        intent: 'Знакомиться',
        gender: 'male',
        birthDate: '1998-05-21',
        city: 'Москва',
        interests: ['🎵 Музыка', '☕ Кофе', '🍷 Вино'],
        vibe: 'Чилл',
        email: 'alex@test.dev',
        requiredContact: 'phone',
        raw: _onboardingRawWithTwoPhotos,
      ),
      occupiedContactField: 'phoneNumber',
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 7; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Контакты'), findsOneWidget);

    final inputs = find.byType(EditableText);
    await tester.enterText(inputs.at(2), '9991234567');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Этот телефон уже привязан к другому аккаунту. Войди по этому номеру на экране входа.',
      ),
      findsOneWidget,
    );
    expect(find.text('Не получилось сохранить onboarding'), findsNothing);
  });

  testWidgets('mobile2 onboarding shows occupied email contact error',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      initialOnboarding: const OnboardingData(
        name: 'Алекс',
        intent: 'Знакомиться',
        gender: 'male',
        birthDate: '1998-05-21',
        city: 'Москва',
        interests: ['🎵 Музыка', '☕ Кофе', '🍷 Вино'],
        vibe: 'Чилл',
        phoneNumber: '+79991234567',
        requiredContact: 'email',
        raw: _onboardingRawWithTwoPhotos,
      ),
      occupiedContactField: 'email',
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 7; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Контакты'), findsOneWidget);

    final inputs = find.byType(EditableText);
    await tester.enterText(inputs.at(1), 'alex@test.dev');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Этот email уже привязан к другому аккаунту. Войди через Google или Yandex с этим email.',
      ),
      findsOneWidget,
    );
    expect(find.text('Не получилось сохранить onboarding'), findsNothing);
  });

  testWidgets('mobile2 onboarding searches Yandex city and saves it',
      (tester) async {
    final repository = _RecordingOnboardingRepository();
    final citySearch = _FakeYandexCitySearchService(
      results: const [
        CitySearchResult(
          label: 'Нижнекамск',
          city: 'Нижнекамск',
          area: 'Республика Татарстан',
          source: CitySearchSource.yandex,
        ),
      ],
    );

    await tester.pumpWidget(
      _onboardingHarness(repository, citySearchService: citySearch),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, 'нижне');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(citySearch.queries, contains('нижне'));
    expect(find.text('Нижнекамск'), findsOneWidget);

    await tester.tap(find.text('Нижнекамск'));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(EditableText).first, 'Алекс');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved?.city, 'Нижнекамск');
    expect(repository.saved?.area, 'Республика Татарстан');
    expect(find.text('home-opened complete=true'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding shows city option before venue results',
      (tester) async {
    final repository = _RecordingOnboardingRepository();

    final citySearch = _FakeYandexCitySearchService();

    await tester.pumpWidget(
      _onboardingHarness(repository, citySearchService: citySearch),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, 'Москва');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(citySearch.queries, isNot(contains('Москва')));
    expect(find.text('Выбрать город'), findsOneWidget);
    expect(find.text('Кофейня на Покровке'), findsNothing);

    await tester.tap(find.text('Выбрать город'));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(EditableText).first, 'Алекс');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved?.city, 'Москва');
    expect(repository.saved?.area, 'Москва');
    expect(find.text('home-opened complete=true'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding finds default city and saves its region',
      (tester) async {
    final repository = _RecordingOnboardingRepository();

    await tester.pumpWidget(
      _onboardingHarness(
        repository,
        citySearchService: _FakeYandexCitySearchService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Алматы'), findsNothing);
    expect(find.text('Тбилиси'), findsNothing);
    expect(find.text('СПб'), findsNothing);
    expect(find.text('Санкт-Петербург'), findsWidgets);

    await tester.enterText(find.byType(EditableText).first, 'ново');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Новосибирск'), findsWidgets);

    await tester.tap(find.text('Новосибирск').first);
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index += 1) {
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(EditableText).first, 'Алекс');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved?.city, 'Новосибирск');
    expect(repository.saved?.area, 'Новосибирская область');
    expect(find.text('home-opened complete=true'), findsOneWidget);
  });

  test('profile photo upload keeps first uploaded photo as current avatar',
      () async {
    final repository = _RecordingProfilePhotoUploadRepository();
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWith(
          (ref) => const BackendUser(
            id: 'user-1',
            name: 'Алекс',
            onboardingComplete: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileActionsProvider).uploadProfilePhoto(
          filePath: '/tmp/first.jpg',
          fileName: 'first.jpg',
          mimeType: 'image/jpeg',
        );
    await container.read(profileActionsProvider).uploadProfilePhoto(
          filePath: '/tmp/second.jpg',
          fileName: 'second.jpg',
          mimeType: 'image/jpeg',
        );

    expect(
      container.read(currentUserProvider)?.avatarUrl,
      'https://cdn.test/first.jpg',
    );
  });

  test('profile photo reorder updates current avatar from first photo',
      () async {
    final repository = _RecordingProfilePhotoOrderRepository();
    final container = ProviderContainer(
      overrides: [
        backendRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWith(
          (ref) => const BackendUser(
            id: 'user-1',
            name: 'Алекс',
            avatarUrl: 'https://cdn.test/first.jpg',
            onboardingComplete: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileActionsProvider).reorderProfilePhotos(
      const ['photo-second', 'photo-first'],
    );

    expect(repository.photoOrders.single, ['photo-second', 'photo-first']);
    expect(
      container.read(currentUserProvider)?.avatarUrl,
      'https://cdn.test/second.jpg',
    );
  });

  testWidgets('mobile2 onboarding marks current user complete after save',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      fetchMeAfterSaveReturnsIncomplete: true,
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();

    for (var index = 0; index < 9; index += 1) {
      if (find.text('Контакты').evaluate().isNotEmpty) {
        await tester.enterText(find.byType(EditableText).first, 'Алекс');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(find.text('home-opened complete=true'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding permission tap shows granted state',
      (tester) async {
    final repository = _RecordingOnboardingRepository();
    final permissions = _FakeOnboardingPermissionService(
      locationResults: [OnboardingPermissionRequestResult.granted],
    );

    await tester.pumpWidget(
      _onboardingHarness(repository, permissionService: permissions),
    );
    await tester.pumpAndSettle();
    await _goToOnboardingPermissions(tester);

    await tester.tap(find.text('Разрешить').first);
    await tester.pumpAndSettle();

    expect(permissions.locationRequests, 1);
    expect(find.text('Разрешено'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding denied permission does not block finish',
      (tester) async {
    final repository = _RecordingOnboardingRepository();
    final permissions = _FakeOnboardingPermissionService(
      locationResults: [OnboardingPermissionRequestResult.denied],
    );

    await tester.pumpWidget(
      _onboardingHarness(repository, permissionService: permissions),
    );
    await tester.pumpAndSettle();
    await _goToOnboardingPermissions(tester);

    await tester.tap(find.text('Разрешить').first);
    await tester.pumpAndSettle();
    expect(find.text('Не разрешено'), findsOneWidget);

    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(find.text('home-opened complete=true'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding returns to contact when phone is required',
      (tester) async {
    final repository = _RecordingOnboardingRepository(
      saveErrorCode: 'required_phone_number',
    );

    await tester.pumpWidget(_onboardingHarness(repository));
    await tester.pumpAndSettle();
    await _goToOnboardingPermissions(tester);

    await tester.tap(find.text('В Frendly'));
    await tester.pumpAndSettle();

    expect(find.text('Контакты'), findsOneWidget);
    expect(
      find.text('Укажи телефон, чтобы закончить onboarding.'),
      findsOneWidget,
    );
    expect(find.text('Не получилось сохранить onboarding'), findsNothing);
  });

  testWidgets('mobile2 onboarding push permission registers device token',
      (tester) async {
    final repository = _RecordingOnboardingRepository();
    final permissions = _FakeOnboardingPermissionService(
      pushResults: [OnboardingPermissionRequestResult.granted],
    );

    await tester.pumpWidget(
      _onboardingHarness(repository, permissionService: permissions),
    );
    await tester.pumpAndSettle();
    await _goToOnboardingPermissions(tester);

    await tester.tap(find.text('Разрешить').at(1));
    await tester.pumpAndSettle();

    expect(permissions.pushRequests, 1);
    expect(find.text('Разрешено'), findsOneWidget);
  });

  testWidgets('mobile2 onboarding ignores stale permission responses',
      (tester) async {
    final repository = _RecordingOnboardingRepository();
    final first = Completer<OnboardingPermissionRequestResult>();
    final second = Completer<OnboardingPermissionRequestResult>();
    final permissions = _FakeOnboardingPermissionService(
      locationCompleters: [first, second],
    );

    await tester.pumpWidget(
      _onboardingHarness(repository, permissionService: permissions),
    );
    await tester.pumpAndSettle();
    await _goToOnboardingPermissions(tester);

    await tester.tap(find.text('Разрешить').first);
    await tester.pump();
    await tester.tap(find.text('Ждём').first);
    await tester.pump();

    second.complete(OnboardingPermissionRequestResult.granted);
    await tester.pumpAndSettle();
    first.complete(OnboardingPermissionRequestResult.denied);
    await tester.pumpAndSettle();

    expect(permissions.locationRequests, 2);
    expect(find.text('Разрешено'), findsOneWidget);
    expect(find.text('Не разрешено'), findsNothing);
  });

  testWidgets('mobile2 profile matches Frendly profile blocks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Алекс, 27'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Москва · Патрики'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('Frendly Plus'), findsOneWidget);
    expect(find.text('Пройти верификацию'), findsOneWidget);
    expect(find.text('+ галочка'), findsOneWidget);
    expect(find.text('Кошелёк токенов'), findsOneWidget);
    expect(find.text('Розыгрыши месяца'), findsOneWidget);
    expect(find.text('Билеты, история, победители'), findsOneWidget);
    expect(find.text('Интересы'), findsOneWidget);
    expect(find.text('Speciality coffee'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);
    expect(find.text('Мои встречи'), findsOneWidget);
    expect(find.text('Винил-вечер на крыше'), findsOneWidget);
  });

  testWidgets('mobile2 profile verification card follows backend status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpStatus(VerificationStateData state) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _backendTestApp(
          home: const ProfileScreen(),
          repository: _VerificationRepository(state: state),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpStatus(
      const VerificationStateData(
        status: 'not_started',
        selfieDone: false,
        documentDone: false,
      ),
    );
    expect(find.text('Пройти верификацию'), findsOneWidget);

    await pumpStatus(
      const VerificationStateData(
        status: 'selfie_submitted',
        selfieDone: true,
        documentDone: false,
      ),
    );
    expect(find.text('Осталось добавить фото документа'), findsOneWidget);

    await pumpStatus(
      const VerificationStateData(
        status: 'under_review',
        selfieDone: true,
        documentDone: true,
      ),
    );
    expect(find.text('Проверка идёт'), findsOneWidget);

    await pumpStatus(
      const VerificationStateData(
        status: 'verified',
        selfieDone: true,
        documentDone: true,
      ),
    );
    expect(find.text('Верификация пройдена'), findsOneWidget);
  });

  testWidgets('mobile2 public profile uses backend social actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _PublicProfileRepository();
    final router = GoRouter(
      initialLocation: '/u/user-nina',
      routes: [
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => PublicUserScreen(
            userId: state.pathParameters['userId'] ?? 'user-nina',
          ),
        ),
        GoRoute(
          path: '/chats',
          builder: (_, __) => const Scaffold(body: Text('chats-opened')),
        ),
        GoRoute(
          path: '/chats/:chatId',
          builder: (_, __) => const Scaffold(body: Text('chats-opened')),
        ),
        GoRoute(
          path: '/ai-builder',
          builder: (_, __) => const Scaffold(body: Text('ai-opened')),
        ),
        GoRoute(
          path: '/dating',
          builder: (_, __) => const Scaffold(body: Text('dating-opened')),
        ),
        GoRoute(
          path: '/report',
          builder: (_, __) => const Scaffold(body: Text('report-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нина'), findsOneWidget);
    expect(find.text('1.2 км · онлайн'), findsOneWidget);
    expect(find.text('Дизайнер из Москвы'), findsOneWidget);
    expect(find.text('32 подписчиков'), findsOneWidget);
    expect(find.text('Подписаться'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4.9'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('4.9'), findsOneWidget);

    await tester.tap(find.text('Подписаться'));
    await tester.pumpAndSettle();
    expect(repository.followActions, ['user-nina:true']);
    expect(find.text('Вы подписаны'), findsOneWidget);
    expect(find.text('33 подписчиков'), findsOneWidget);
    expect(find.byIcon(LucideIcons.bellRing), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.bellRing));
    await tester.pumpAndSettle();
    expect(repository.notificationActions, ['user-nina:false']);
    expect(find.byIcon(LucideIcons.bell), findsOneWidget);

    await tester.tap(find.text('Лайк'));
    await tester.pumpAndSettle();
    expect(repository.likeActions, ['user-nina:true']);
    expect(find.text('Лайк отправлен'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Лайкнут'), findsOneWidget);

    await tester.tap(find.text('Лайкнут'));
    await tester.pumpAndSettle();
    expect(repository.likeActions, ['user-nina:true', 'user-nina:false']);
    expect(find.text('Лайк убран'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.messageCircle));
    await tester.pumpAndSettle();
    expect(repository.directChatRequests, 1);
    expect(find.text('chats-opened'), findsOneWidget);
  });

  testWidgets('mobile2 opens own profile instead of public self profile',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/u/user-1',
      routes: [
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => PublicUserScreen(
            userId: state.pathParameters['userId'] ?? 'user-1',
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('own-profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_PublicProfileRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('own-profile'), findsOneWidget);
    expect(find.text('Подписаться'), findsNothing);
  });

  testWidgets('mobile2 public profile can remove an existing like',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _PublicProfileRepository(initialLiked: true);
    final router = GoRouter(
      initialLocation: '/u/user-nina',
      routes: [
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => PublicUserScreen(
            userId: state.pathParameters['userId'] ?? 'user-nina',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лайкнут'), findsOneWidget);

    await tester.tap(find.text('Лайкнут'));
    await tester.pumpAndSettle();

    expect(repository.likeActions, ['user-nina:false']);
    expect(find.text('Лайк убран'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Лайк'), findsOneWidget);
  });

  testWidgets('mobile2 public profile replaces actions after block',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _PublicProfileRepository(initialBlocked: true);
    final router = GoRouter(
      initialLocation: '/u/user-nina',
      routes: [
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => PublicUserScreen(
            userId: state.pathParameters['userId'] ?? 'user-nina',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заблокирован'), findsOneWidget);
    expect(find.text('Разблокировать'), findsOneWidget);
    expect(find.text('Подписаться'), findsNothing);
    expect(find.text('Лайк'), findsNothing);
    expect(find.byIcon(LucideIcons.messageCircle), findsNothing);

    await tester.tap(find.text('Разблокировать'));
    await tester.pumpAndSettle();

    expect(repository.unblockActions, ['user-nina']);
    expect(find.text('Заблокирован'), findsNothing);
    expect(find.text('Подписаться'), findsOneWidget);
    expect(find.text('Лайк'), findsOneWidget);
  });

  testWidgets('mobile2 profile gallery matches Frendly gallery controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/profile/gallery',
      routes: [
        GoRoute(
          path: '/profile/gallery',
          builder: (_, __) => const ProfileGalleryScreen(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, __) => const Scaffold(body: Text('edit-opened')),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('profile-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Галерея'), findsOneWidget);
    expect(find.text('2 фото · обновлено сегодня'), findsOneWidget);
    expect(find.text('Главное'), findsOneWidget);
    expect(find.text('Загрузить ещё фото'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-gallery-tile-0')));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dateasy-media-viewer-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();

    expect(find.text('edit-opened'), findsOneWidget);
  });

  testWidgets('mobile2 profile history uses front2 date format',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const ProfileHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('История'), findsOneWidget);
    expect(find.text('Встреч завершено'), findsOneWidget);
    expect(find.text('Винил-вечер на крыше'), findsOneWidget);
    expect(find.textContaining('19 мая · 21:00'), findsOneWidget);
  });

  testWidgets('mobile2 profile history shows empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const ProfileHistoryScreen(),
        repository: _EmptyHistoryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('История'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('История пока пустая'), findsOneWidget);
  });

  testWidgets('mobile2 profile shows hosted meetings before history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const ProfileScreen(),
        repository: _HostDashboardRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Мои встречи'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Мои встречи'), findsOneWidget);
    expect(find.text('Будущая встреча'), findsOneWidget);
    expect(find.text('Прошлая встреча'), findsNothing);
  });

  testWidgets('mobile2 profile hosted meeting opens detail on tap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => Scaffold(
            body: Text('detail ${state.pathParameters['meetingId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_HostDashboardRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Мои встречи'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Будущая встреча'));
    await tester.pumpAndSettle();

    expect(find.text('detail event-1'), findsOneWidget);
  });

  testWidgets('mobile2 settings shortcuts open linked screens', (tester) async {
    final repository = _SettingsRepository();

    Future<void> pumpSettingsRouter() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'faq',
                builder: (_, __) => const SettingsFaqScreen(),
              ),
              GoRoute(
                path: 'documents',
                builder: (_, __) => const SettingsDocumentsScreen(),
                routes: [
                  GoRoute(
                    path: 'promo-rules',
                    builder: (_, __) => const SettingsPromoRulesScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'blocked',
                builder: (_, __) => const SettingsBlockedUsersScreen(),
              ),
            ],
          ),
          GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
          GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
          GoRoute(
            path: '/profile/edit',
            builder: (_, __) => const ProfileEditScreen(),
          ),
          GoRoute(path: '/city', builder: (_, __) => const CityScreen()),
          GoRoute(path: '/sos', builder: (_, __) => const SosScreen()),
          GoRoute(path: '/verify', builder: (_, __) => const VerifyScreen()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _backendTestOverrides(repository),
          child: MaterialApp.router(
            theme: DateasyTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpSettingsRouter();
    expect(find.text('Приватность'), findsNothing);
    expect(find.text('Возраст виден'), findsNothing);
    expect(find.text('Видимость профиля'), findsOneWidget);
    expect(find.text('Заблокированные'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Мэтчи и встречи'), findsNothing);
    expect(find.text('Платежи'), findsNothing);
    expect(find.text('Кошелёк'), findsNothing);
    expect(find.text('Тёмная тема'), findsNothing);
    expect(find.text('Тихие часы'), findsNothing);

    await tester.tap(find.text('Видимость профиля'));
    await tester.pumpAndSettle();
    expect(repository.updatedSettings.last['discoverable'], false);

    await pumpSettingsRouter();
    await tester.tap(find.text('Frendly Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Frendly'), findsOneWidget);

    await pumpSettingsRouter();
    await tester.scrollUntilVisible(find.text('FAQ'), 500);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAQ'));
    await tester.pumpAndSettle();
    expect(find.text('Что такое Frendly?'), findsOneWidget);
    expect(find.text('Где посмотреть правила?'), findsOneWidget);

    await pumpSettingsRouter();
    await tester.scrollUntilVisible(find.text('Документы'), 500);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Документы'));
    await tester.pumpAndSettle();
    expect(find.text('Пользовательское соглашение'), findsOneWidget);
    expect(
      find.text('Согласие на обработку персональных данных'),
      findsOneWidget,
    );
    expect(find.text('Официальные правила Frendly Drops'), findsOneWidget);

    await tester.tap(find.text('Официальные правила Frendly Drops'));
    await tester.pumpAndSettle();
    expect(find.text('Apple не является спонсором конкурса'), findsOneWidget);
    expect(
      find.textContaining('Apple не участвует в организации'),
      findsOneWidget,
    );

    await pumpSettingsRouter();
    await tester.scrollUntilVisible(find.text('Редактировать профиль'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Редактировать'), findsOneWidget);
  });

  testWidgets('mobile2 settings blocked users opens profile and unblocks',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _BlockedUsersRepository();
    final router = GoRouter(
      initialLocation: '/settings/blocked',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'blocked',
              builder: (_, __) => const SettingsBlockedUsersScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => Scaffold(
            body: Text('profile:${state.pathParameters['userId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заблокированные'), findsOneWidget);
    expect(find.text('Нина'), findsOneWidget);
    expect(find.text('Разблокировать'), findsOneWidget);

    await tester.tap(find.text('Нина'));
    await tester.pumpAndSettle();
    expect(find.text('profile:user-nina'), findsOneWidget);

    router.go('/settings/blocked');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Разблокировать'));
    await tester.pumpAndSettle();

    expect(repository.unblockActions, ['user-nina']);
    expect(find.text('Нина'), findsNothing);
    expect(find.text('Заблокированных пользователей нет'), findsOneWidget);
  });

  testWidgets('mobile2 profile edit hides social network binding controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const ProfileEditScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Удалить аккаунт'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Соц-сети'), findsNothing);
    expect(find.text('Привязать'), findsNothing);
    expect(find.text('Instagram'), findsNothing);
    expect(find.text('Spotify'), findsNothing);
  });

  testWidgets('mobile2 city screen matches front2 picker and saves backend',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _CityRepository();
    final router = GoRouter(
      initialLocation: '/city',
      routes: [
        GoRoute(path: '/city', builder: (_, __) => const CityScreen()),
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home-opened'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Город'), findsOneWidget);
    expect(find.text('Найти город'), findsOneWidget);
    expect(find.text('Определить автоматически'), findsOneWidget);
    expect(find.text('Каталог городов локальный. Backend endpoint не найден'),
        findsNothing);
    expect(find.text('Москва'), findsWidgets);
    expect(find.text('Дубай'), findsNothing);
    expect(find.text('Тбилиси'), findsNothing);
    expect(find.text('Алматы'), findsNothing);
    expect(find.text('СПб'), findsNothing);
    expect(find.text('Санкт-Петербург'), findsWidgets);
    expect(find.text('Новосибирск'), findsWidgets);
    expect(find.text('Омск'), findsWidgets);

    await tester.enterText(find.byType(EditableText).first, 'твер');
    await tester.pumpAndSettle();

    expect(find.text('Тверь'), findsOneWidget);
    expect(find.text('Ничего не найдено'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, 'ниж');
    await tester.pumpAndSettle();

    expect(find.text('Нижний Новгород'), findsOneWidget);

    await tester.tap(find.text('Нижний Новгород'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(repository.updatedProfile.last['city'], 'Нижний Новгород');
    expect(repository.updatedProfile.last['area'], 'Нижегородская область');
    expect(find.text('home-opened'), findsOneWidget);
  });

  testWidgets('mobile2 top bar city picker saves manual city', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _CityRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const Scaffold(
            backgroundColor: DateasyColors.background,
            body: SafeArea(child: DateasyTopBar()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Москва'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Москва')).style?.fontWeight,
      FontWeight.w400,
    );

    await tester.tap(find.text('Москва'));
    await tester.pumpAndSettle();

    expect(find.text('Если включен VPN, укажи город вручную.'), findsOneWidget);
    expect(find.text('Открыть полный выбор города'), findsOneWidget);
    expect(find.text('Дубай'), findsNothing);
    expect(find.text('Тбилиси'), findsNothing);
    expect(find.text('Алматы'), findsNothing);
    expect(find.text('СПб'), findsNothing);
    expect(find.text('Санкт-Петербург'), findsOneWidget);
    expect(find.text('Новосибирск'), findsOneWidget);
    expect(find.text('Омск'), findsOneWidget);

    await tester.tap(find.text('Новосибирск'));
    await tester.pumpAndSettle();

    expect(repository.updatedProfile.last['city'], 'Новосибирск');
    expect(repository.updatedProfile.last['area'], 'Новосибирская область');
  });

  testWidgets('mobile2 verification under review blocks repeat submit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _VerificationRepository(
      state: const VerificationStateData(
        status: 'under_review',
        selfieDone: true,
        documentDone: true,
      ),
    );

    await tester.pumpWidget(
      _backendTestApp(
        home: const VerifyScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Верификация'), findsOneWidget);
    expect(find.text('Проверка идёт'), findsWidgets);
    expect(find.text('Сделать селфи'), findsNothing);

    await tester.tap(find.text('Проверка идёт').last);
    await tester.pumpAndSettle();
    expect(repository.submittedSteps, isEmpty);
  });

  testWidgets('mobile2 verification final state shows plus benefit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const VerifyScreen(),
        repository: _VerificationRepository(
          state: const VerificationStateData(
            status: 'verified',
            selfieDone: true,
            documentDone: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Верификация пройдена'), findsWidgets);
    expect(find.textContaining('3 дня Frendly+'), findsWidgets);
  });

  testWidgets('mobile2 verification returned state shows review note',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const VerifyScreen(),
        repository: _VerificationRepository(
          state: const VerificationStateData(
            status: 'not_started',
            selfieDone: false,
            documentDone: false,
            reviewNote: 'Документ размытый',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нужно пройти заново'), findsOneWidget);
    expect(find.text('Документ размытый'), findsOneWidget);
  });

  testWidgets('mobile2 sos matches front2 safety cards and masks contacts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _SosRepository();

    await tester.pumpWidget(
      _backendTestApp(
        home: const SosScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Безопасность'), findsOneWidget);
    expect(find.text('Удерживай'), findsOneWidget);
    expect(find.text('БЫСТРЫЕ ДЕЙСТВИЯ'), findsOneWidget);
    expect(find.text('Мама'), findsOneWidget);
    expect(find.text('+7 ··· 21'), findsOneWidget);
    expect(find.text('Чек-ин на встрече'), findsOneWidget);
    expect(find.text('Напомним через 2 часа, всё ли ок'), findsOneWidget);
    expect(find.text('Скрыть точную гео'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sos-checkin-toggle')));
    await tester.pumpAndSettle();

    expect(repository.updatedSafety.last['autoSharePlans'], false);
  });

  testWidgets('mobile2 wallet uses backend catalog and ledger history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const WalletScreen(),
        repository: _WalletRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Кошелёк'), findsOneWidget);
    expect(find.text('Frendly Tokens'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('Покупка токенов пока недоступна'), findsOneWidget);
    expect(find.text('199 ₽'), findsNothing);
    expect(find.text('Plus подписка'), findsOneWidget);
    expect(find.text('от 250 FT / мес'), findsOneWidget);
    expect(find.text('Буст встречи'), findsOneWidget);
    expect(find.text('80 FT / 24ч'), findsOneWidget);
    expect(find.text('Super-like'), findsOneWidget);
    expect(find.text('5 FT / шт'), findsOneWidget);
    expect(find.text('Нет endpoint'), findsNothing);
    expect(find.text('Пополнение токенов'), findsOneWidget);
    expect(find.text('+100 FT'), findsOneWidget);
    expect(find.text('Frendly+'), findsOneWidget);
    expect(find.text('-250 FT'), findsOneWidget);
  });

  test('mobile2 legal links open in in-app browser', () {
    expect(frendlyLegalLaunchMode, LaunchMode.inAppBrowserView);
  });

  testWidgets('mobile2 paywall shows Plus without purchases', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const PaywallScreen(),
        repository: _BillingRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Frendly'), findsOneWidget);
    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Plus скоро'), findsOneWidget);
    expect(find.text('Активировать за 600 FT'), findsNothing);
    expect(find.text('Оплатить через App Store'), findsNothing);
    expect(find.text('Terms of Use (EULA)'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('mobile2 paywall does not show App Store prices on iOS',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _backendTestApp(
        home: const PaywallScreen(),
        repository: _BillingRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plus скоро'), findsOneWidget);
    expect(find.text('1199'), findsNothing);
    expect(find.text('руб.'), findsNothing);
    expect(find.text('400 руб./мес'), findsNothing);
    expect(find.text('Оплатить через App Store'), findsNothing);
    expect(find.text('Активировать за 600 FT'), findsNothing);
    expect(find.text('600'), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mobile2 paywall only loads Plus catalog',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _CountingBillingRepository();
    var tick = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Stack(
                children: [
                  const PaywallScreen(),
                  Text('$tick', textDirection: TextDirection.ltr),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.walletCalls, 0);
    expect(repository.catalogCalls, 1);
    expect(repository.planCalls, 0);

    rebuild(() => tick += 1);
    await tester.pumpAndSettle();

    expect(repository.walletCalls, 0);
    expect(repository.catalogCalls, 1);
    expect(repository.planCalls, 0);
  });

  testWidgets('mobile2 map matches Frendly radar screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const MapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Места, события, люди'), findsOneWidget);
    expect(find.byIcon(LucideIcons.slidersHorizontal), findsOneWidget);
    expect(find.text('Встречи · 5'), findsOneWidget);
    expect(find.text('Маршруты · 0'), findsOneWidget);
    expect(find.text('Афиша · 0'), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
    expect(find.text('РЯДОМ СЕЙЧАС · 5'), findsOneWidget);
    expect(find.text('Rooftop 17 · винил-вечер'), findsOneWidget);
    expect(find.text('Сегодня 21:00 · 0.8 км'), findsOneWidget);
    expect(find.text('+Я'), findsWidgets);
    expect(find.byIcon(LucideIcons.navigation), findsOneWidget);
  });

  testWidgets('mobile2 splash matches Frendly splash flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DateasyTheme.theme,
        home: const SplashScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('frendly'), findsOneWidget);
    expect(find.text('встречайся · собирай вечера'), findsOneWidget);
    expect(find.byKey(const ValueKey('dateasy-splash-mark')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-dot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-dot-2')), findsOneWidget);
    expect(find.text('Продолжить'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Продолжить'), findsOneWidget);
  });

  testWidgets('mobile2 ai builder matches Frendly prompt builder',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DateasyTheme.theme,
        home: const AiBuilderScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI билдер'), findsOneWidget);
    expect(find.text('Опиши вайб —'), findsOneWidget);
    expect(find.text('соберём вечер'), findsOneWidget);
    expect(find.textContaining('Один абзац'), findsOneWidget);
    expect(find.text('ПРОМТ'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('символов'), findsOneWidget);
    expect(find.text('2-3 предложения — идеально'), findsOneWidget);
    expect(find.text('ПРИМЕРЫ ПРОМТОВ'), findsNothing);
    expect(find.text('Уютный вечер вдвоём'), findsNothing);
    expect(find.text('Активная компания на 4-6'), findsNothing);
    expect(find.text('Гастро-приключение'), findsNothing);
    expect(find.text('Креативное свидание'), findsNothing);
    expect(find.text('ПРОВЕРЬ МАРШРУТ'), findsOneWidget);
    expect(find.textContaining('AI может ошибиться'), findsOneWidget);
    expect(find.text('КАК ОПИСАТЬ КРУЧЕ'), findsOneWidget);
    expect(find.textContaining('Укажи количество людей'), findsOneWidget);
    expect(find.text('Сгенерировать вечер'), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
    expect(find.byIcon(LucideIcons.sparkles), findsWidgets);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
    expect(find.byIcon(LucideIcons.wand), findsNothing);
    expect(find.byIcon(LucideIcons.lightbulb), findsWidgets);
    expect(find.byIcon(LucideIcons.calendarHeart), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'тихий бар на двоих');
    await tester.pumpAndSettle();

    expect(find.text('Очистить'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);

    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();
    expect(find.text('Очистить'), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('mobile2 ai builder shows generation progress', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const AiBuilderScreen(),
        repository: _PendingAiBuilderRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'бар и стендап сегодня');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сгенерировать вечер'));
    await tester.pump();

    expect(find.text('Генерируем маршрут...'), findsOneWidget);
    expect(find.textContaining('Среднее время загрузки 30 секунд'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowRight), findsNothing);
  });

  testWidgets('mobile2 ai builder shows failed generation state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const AiBuilderScreen(),
        repository: _FailingAiBuilderRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'бар и стендап сегодня');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сгенерировать вечер'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось собрать маршрут'), findsOneWidget);
  });

  testWidgets('mobile2 ai builder result shows regenerate progress',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const AiBuilderResultScreen(draftId: 'draft-1'),
        repository: _PendingAiBuilderResultRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Перегенерить'), findsOneWidget);

    await tester.tap(find.text('Перегенерить'));
    await tester.pump();

    expect(find.text('Перегенерируем...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('mobile2 ai builder result shows step regenerate progress',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const AiBuilderResultScreen(draftId: 'draft-1'),
        repository: _PendingAiBuilderResultRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Перегенерировать шаг').first);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('mobile2 meeting chat matches Frendly chat blocks',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_MeetingChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speciality coffee tasting'), findsOneWidget);
    expect(find.text('4 онлайн · 6 участников'), findsOneWidget);
    expect(find.text('Сегодня · 19:30'), findsOneWidget);
    expect(find.text('Brew Lab, Патрики'), findsOneWidget);
    expect(find.text('Встреча создана · сегодня 12:04'), findsOneWidget);
    expect(find.text('Frendly'), findsNothing);
    expect(find.text('Привеет! Я хост, очень рада всем 🤍'), findsOneWidget);
    expect(find.text('Огонь, я тогда подтянусь к 19:30 ✌️'), findsOneWidget);
    expect(find.text('Сообщение в чат встречи'), findsOneWidget);
    expect(find.text('Предложи тост'), findsNothing);
    expect(find.text('Перенести'), findsNothing);
    expect(find.text('Поделиться местом'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.plus).last);
    await tester.pumpAndSettle();
    expect(find.text('Фото/видео'), findsOneWidget);
    expect(find.text('Локация'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('Меню чата'), findsOneWidget);
    expect(find.text('Участники'), findsOneWidget);
    expect(find.text('Покинуть чат'), findsOneWidget);
    expect(find.text('Поиск по чату'), findsNothing);
    expect(find.text('Закрепить чат'), findsNothing);
    expect(find.text('Отключить уведомления'), findsNothing);
    expect(find.text('Напомнить о встрече'), findsNothing);
    expect(find.text('Пожаловаться'), findsNothing);

    await tester.tap(find.text('Участники'));
    await tester.pumpAndSettle();
    expect(find.text('4 онлайн · 6 участников'), findsWidgets);
    expect(find.text('Лия'), findsWidgets);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speciality coffee tasting'));
    await tester.pumpAndSettle();
    expect(find.text('Участники'), findsOneWidget);
    expect(find.text('Лия'), findsWidgets);
  });

  testWidgets('mobile2 chat opens public profile from message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/chats/coffee',
      routes: [
        GoRoute(
          path: '/chats/:chatId',
          builder: (_, state) => MeetingChatScreen(
            meetingId: state.pathParameters['chatId'] ?? 'coffee',
          ),
        ),
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => Scaffold(
            body: Text('profile-opened-${state.pathParameters['userId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_MeetingChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Привеет! Я хост, очень рада всем 🤍'));
    await tester.pumpAndSettle();

    expect(find.text('profile-opened-u-lia'), findsOneWidget);
  });

  testWidgets('mobile2 meeting chat opens at latest messages', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(
            _MeetingChatPagedRepository(),
          ),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
  });

  testWidgets('mobile2 meeting chat scroll near top loads older messages',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingChatPagedRepository();
    final database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    final chatStore = ChatLocalStore(database);
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(repository),
          chatLocalStoreProvider.overrideWithValue(chatStore),
          currentUserProvider.overrideWith(
            (ref) => const BackendUser(id: 'user-1', name: 'Alex'),
          ),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const MeetingChatScreen(meetingId: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();

    expect(repository.cursors, [null, 'older-1']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('mobile2 chat opens public profile from participant list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/chats/coffee',
      routes: [
        GoRoute(
          path: '/chats/:chatId',
          builder: (_, state) => MeetingChatScreen(
            meetingId: state.pathParameters['chatId'] ?? 'coffee',
          ),
        ),
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => Scaffold(
            body: Text('profile-opened-${state.pathParameters['userId']}'),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('own-profile-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_MeetingChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Speciality coffee tasting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Лия').last);
    await tester.pumpAndSettle();

    expect(find.text('profile-opened-u-lia'), findsOneWidget);
  });

  testWidgets('mobile2 meeting chat back arrow returns to chats',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/coffee/chat',
      routes: [
        GoRoute(
          path: '/chats',
          builder: (_, __) => const Scaffold(body: Text('chats-opened')),
        ),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, __) => const Scaffold(body: Text('meeting-opened')),
        ),
        GoRoute(
          path: '/meetings/:meetingId/chat',
          builder: (_, state) => MeetingChatScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'coffee',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(_MeetingChatRepository()),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speciality coffee tasting'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();

    expect(find.text('chats-opened'), findsOneWidget);
    expect(find.text('meeting-opened'), findsNothing);
  });

  testWidgets('mobile2 community chat route opens shared chat screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/communities/community-1/chat',
      routes: [
        GoRoute(
          path: '/communities/:communityId',
          builder: (_, state) => Scaffold(
            body: Text(
              'community-opened-${state.pathParameters['communityId']}',
            ),
          ),
          routes: [
            GoRoute(
              path: 'chat',
              builder: (_, state) => CommunityChatScreen(
                communityId: state.pathParameters['communityId'] ?? '',
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/chats/:chatId',
          builder: (_, state) => MeetingChatScreen(
            meetingId: state.pathParameters['chatId'] ?? 'community-chat-1',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(
            _CommunityChatRepository(),
          ),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wine club'), findsOneWidget);
    expect(find.text('2 онлайн · 12 участников'), findsOneWidget);
    expect(find.text('Сообщество'), findsOneWidget);
    expect(find.text('Сообщение в чат'), findsOneWidget);
    expect(find.text('Сообщение в чат встречи'), findsNothing);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('Фото/видео'), findsOneWidget);

    await tester.tap(find.text('Сообщество'));
    await tester.pumpAndSettle();
    expect(find.text('community-opened-community-1'), findsOneWidget);
  });

  testWidgets('mobile2 community chat refreshes empty chat list after opening',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _CommunityChatRestoredSummaryRepository();
    final router = GoRouter(
      initialLocation: '/chats/community-chat-1',
      routes: [
        GoRoute(
          path: '/chats/:chatId',
          builder: (_, state) => MeetingChatScreen(
            meetingId: state.pathParameters['chatId'] ?? 'community-chat-1',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendRepositoryProvider.overrideWithValue(repository),
          appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Привет сообществу'), findsOneWidget);
    expect(find.text('Wine club'), findsOneWidget);
    expect(repository.communityFetches, greaterThan(1));
  });

  testWidgets('mobile2 meeting detail renders backend attachments and host',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/coffee',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'coffee',
          ),
        ),
        GoRoute(
          path: '/chats/:chatId',
          builder: (_, state) => Scaffold(
            body: Text('chat-opened-${state.pathParameters['chatId']}'),
          ),
        ),
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => Scaffold(
            body: Text('profile-opened-${state.pathParameters['userId']}'),
          ),
        ),
        GoRoute(
          path: '/routes/:routeId',
          builder: (_, state) => Scaffold(
            body: Text('route-opened-${state.pathParameters['routeId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_MeetingDetailRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speciality coffee tasting'), findsOneWidget);
    expect(find.text('Хост'), findsWidgets);
    expect(find.text('Лия'), findsWidgets);
    expect(find.text('4.9 · 12 встреч · проверен'), findsOneWidget);
    expect(find.text('Вложено во встречу'), findsOneWidget);
    expect(find.text('Афиша'), findsOneWidget);
    expect(find.text('Билет'), findsOneWidget);
    expect(find.text('Заведение'), findsOneWidget);
    expect(find.text('Забронировать'), findsOneWidget);
    expect(find.text('Открыть'), findsNothing);
    expect(find.text('План вечера'), findsOneWidget);
    expect(find.text('Встречаемся у бара'), findsOneWidget);
    expect(find.text('Дегустация 3 фильтров'), findsOneWidget);
    expect(find.text('Прогулка по бульвару'), findsOneWidget);
    expect(find.text('Забронировать столик'), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);
    expect(find.text('На карте'), findsOneWidget);
    expect(find.text('О встрече'), findsOneWidget);
    expect(find.text('Пробуем 3 фильтра и идем гулять'), findsOneWidget);
    expect(find.text('Кто идёт'), findsOneWidget);
    expect(find.text('Локация'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.messageCircle).first);
    await tester.pumpAndSettle();

    expect(find.text('chat-opened-chat-coffee'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail opens location map choice sheet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/coffee',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'coffee',
          ),
        ),
        GoRoute(
          path: '/routes/:routeId',
          builder: (_, state) => Scaffold(
            body: Text('route-opened-${state.pathParameters['routeId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_MeetingDetailRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Brew Lab, Патрики').last,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brew Lab, Патрики').last);
    await tester.pumpAndSettle();

    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Yandex Maps'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Маршрут').last);
    await tester.pumpAndSettle();

    expect(find.text('route-opened-route-1'), findsOneWidget);
  });

  testWidgets('mobile2 meeting report hides meeting from list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingReportRepository();
    final router = GoRouter(
      initialLocation: '/meetings/report-me',
      routes: [
        GoRoute(
          path: '/meetings',
          builder: (_, __) => const MeetingsScreen(),
        ),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'report-me',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('meeting-report-action')));
    await tester.pumpAndSettle();
    expect(find.text('Пожаловаться на встречу'), findsOneWidget);

    await tester.tap(find.text('Пожаловаться'));
    await tester.pumpAndSettle();

    expect(repository.reportedEventIds, ['report-me']);
    expect(find.text('Обычная встреча'), findsOneWidget);
    expect(find.text('Плохая встреча'), findsNothing);
  });

  testWidgets('mobile2 meeting detail hides chat action without backend chatId',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/no-chat',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'no-chat',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_MeetingNoChatRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speciality coffee tasting'), findsOneWidget);
    expect(find.text('Чат встречи'), findsNothing);
  });

  testWidgets('mobile2 meeting join toggles leave and chat action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingJoinToggleRepository();
    final router = GoRouter(
      initialLocation: '/meetings/toggle',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'toggle',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._backendTestOverrides(repository),
          chatSocketTransportFactoryProvider.overrideWithValue((_) {
            return _CountingChatTransport();
          }),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вступить'), findsOneWidget);
    expect(find.byTooltip('Чат встречи'), findsNothing);

    await tester.tap(find.text('Вступить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.joinCalls, 1);
    expect(find.text('Выйти'), findsOneWidget);
    expect(find.byTooltip('Чат встречи'), findsOneWidget);

    await tester.tap(find.text('Выйти'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.leaveCalls, 1);
    expect(find.text('Вступить'), findsOneWidget);
    expect(find.byTooltip('Чат встречи'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mobile2 joined request-only meeting uses leave action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingClosedJoinToggleRepository();
    final router = GoRouter(
      initialLocation: '/meetings/toggle',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'toggle',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._backendTestOverrides(repository),
          chatSocketTransportFactoryProvider.overrideWithValue((_) {
            return _CountingChatTransport();
          }),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Выйти'), findsOneWidget);

    await tester.tap(find.text('Выйти'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.leaveCalls, 1);
    expect(repository.joinRequestCalls, 0);
  });

  testWidgets('mobile2 meeting detail refreshes participant count',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const MeetingDetailScreen(meetingId: 'refresh'),
        repository: _MeetingRefreshRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/10'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.text('2/10'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail starts realtime for meetup chat',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var socketStarts = 0;
    final database = AppLocalDatabase.forTesting(NativeDatabase.memory());
    final chatStore = ChatLocalStore(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._backendTestOverrides(_MeetingRefreshRepository()),
          chatLocalStoreProvider.overrideWithValue(chatStore),
          chatSocketTransportFactoryProvider.overrideWithValue((_) {
            socketStarts += 1;
            return _CountingChatTransport();
          }),
        ],
        child: const MaterialApp(
          home: MeetingDetailScreen(meetingId: 'refresh'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/10'), findsOneWidget);
    expect(socketStarts, 1);
  });

  testWidgets('mobile2 host dashboard approves and rejects requests',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _HostDashboardRepository();
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (_, __) => const HostDashboardScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('profile-opened')),
        ),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => Scaffold(
            body: Text('meeting-${state.pathParameters['meetingId']}'),
          ),
        ),
        GoRoute(
          path: '/meetings/new',
          builder: (_, state) => NewMeetingScreen(
            editEventId: state.uri.queryParameters['editEventId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host dashboard'), findsOneWidget);
    expect(find.text('Заявки'), findsOneWidget);
    expect(find.text('Архив'), findsOneWidget);
    expect(find.text('Черновики'), findsNothing);
    expect(find.text('Нина'), findsOneWidget);
    expect(find.byIcon(LucideIcons.badgeCheck), findsOneWidget);
    expect(find.byIcon(LucideIcons.crown), findsOneWidget);

    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();

    expect(find.text('Прошлая встреча'), findsOneWidget);
    expect(find.text('Будущая встреча'), findsNothing);

    await tester.tap(find.text('Активные'));
    await tester.pumpAndSettle();

    expect(find.text('Будущая встреча'), findsOneWidget);
    expect(find.text('Прошлая встреча'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();

    expect(repository.approvedRequestIds, ['request-1']);
    expect(find.text('Заявка одобрена'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();

    expect(repository.rejectedRequestIds, ['request-1']);
    expect(find.text('Заявка отклонена'), findsOneWidget);
  });

  testWidgets('mobile2 host dashboard opens applicant profile from request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (_, __) => const HostDashboardScreen(),
        ),
        GoRoute(
          path: '/u/:userId',
          builder: (_, state) => Scaffold(
            body: Text('user-${state.pathParameters['userId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_HostDashboardRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Нина'));
    await tester.pumpAndSettle();

    expect(find.text('user-user-nina'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail shows front2 host actions for own event',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/own',
      routes: [
        GoRoute(
          path: '/meetings/new',
          builder: (_, state) => NewMeetingScreen(
            editEventId: state.uri.queryParameters['editEventId'],
          ),
        ),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'own',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_MeetingHostRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Продвинуть'), findsOneWidget);
    expect(find.text('Заявки'), findsOneWidget);
    expect(find.text('Пригласить'), findsNothing);
    expect(find.text('Завершить встречу'), findsOneWidget);
    expect(find.text('Вы идёте'), findsNothing);

    expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
    expect(find.byIcon(LucideIcons.zap), findsOneWidget);
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);

    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать встречу'), findsOneWidget);
    expect(find.text('Speciality coffee tasting'), findsOneWidget);
    expect(find.text('Моя встреча'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail lets host select attendees and finish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingHostRepository();
    final router = GoRouter(
      initialLocation: '/meetings/own',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'own',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Завершить встречу'));
    await tester.pumpAndSettle();

    expect(find.text('Кто был на встрече'), findsOneWidget);
    expect(find.text('Нина'), findsWidgets);

    await tester.tap(find.text('Нина').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить встречу').last);
    await tester.pumpAndSettle();

    expect(repository.finishedAttendeeIds, [
      ['user-nina'],
    ]);
    expect(find.text('Встреча завершена'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail lets host review join requests',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingHostRequestsRepository();
    final router = GoRouter(
      initialLocation: '/meetings/own',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'own',
          ),
        ),
        GoRoute(
          path: '/meetings/new',
          builder: (_, __) => const Scaffold(body: Text('edit-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заявки'), findsOneWidget);
    expect(find.text('Пригласить'), findsNothing);

    await tester.tap(find.text('Заявки'));
    await tester.pumpAndSettle();

    expect(find.text('Заявки на встречу'), findsOneWidget);
    expect(find.text('Нина'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.check).last);
    await tester.pumpAndSettle();

    expect(repository.approvedRequestIds, ['request-1']);
    expect(find.text('Заявка одобрена'), findsOneWidget);

    await tester.tap(find.text('Заявки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.x).last);
    await tester.pumpAndSettle();

    expect(repository.rejectedRequestIds, ['request-1']);
    expect(find.text('Заявка отклонена'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail reads nested host and attendee photos',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/photos',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'photos',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_MeetingPhotosRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DateasyRemoteImage &&
            widget.imageUrl == 'https://example.com/host-profile.jpg',
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DateasyRemoteImage &&
            widget.imageUrl == 'https://example.com/guest-profile.jpg',
      ),
      findsOneWidget,
    );
    final heroImage = tester
        .widgetList<DateasyRemoteImage>(find.byType(DateasyRemoteImage))
        .firstWhere(
          (widget) => widget.imageUrl == 'https://example.com/meeting.jpg',
        );
    expect(
      DateasyRemoteImage.resolveVariantImageUrl(
        imageUrl: heroImage.imageUrl,
        imageVariants: heroImage.imageVariants,
        usage: DateasyImageUsage.hero,
      ),
      'https://example.com/meeting-hero.webp',
    );
  });

  testWidgets('mobile2 empty stories can close back to meeting detail',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/stories?eventId=coffee',
      routes: [
        GoRoute(
          path: '/stories',
          builder: (_, state) => StoriesScreen(
            eventId: state.uri.queryParameters['eventId'],
          ),
        ),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => Scaffold(
            body: Text('meeting-opened-${state.pathParameters['meetingId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_EmptyStoriesRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stories пока нет'), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();

    expect(find.text('meeting-opened-coffee'), findsOneWidget);
  });

  testWidgets('mobile2 private stories use signed media and prewarm next items',
      (tester) async {
    final signedPaths = <String>[];
    final warmedPaths = <String>[];
    final attachmentService = AppAttachmentService(
      fetchSignedUrl: (path) async {
        signedPaths.add(path);
        return SignedMediaUrl(
          url: 'https://cdn.test${path.replaceFirst('/download-url', '')}.jpg',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
      },
      fetchFile: (url, _) async {
        warmedPaths.add(url);
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._backendTestOverrides(_PrivateStoriesRepository()),
          appAttachmentServiceProvider.overrideWithValue(attachmentService),
        ],
        child: const MaterialApp(
          home: StoriesScreen(eventId: 'coffee'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DateasyRemoteImage &&
            widget.imageUrl == 'https://cdn.test/media/story-1.jpg',
      ),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DateasyRemoteImage &&
            (widget.imageUrl?.contains('/media/story-') ?? false) &&
            !widget.imageUrl!.startsWith('https://cdn.test/'),
      ),
      findsNothing,
    );
    expect(signedPaths.toSet(), {
      '/media/story-1/download-url',
      '/media/story-2/download-url',
      '/media/story-3/download-url',
      '/media/story-4/download-url',
    });
    expect(warmedPaths, hasLength(4));
  });

  testWidgets('mobile2 share screen creates public event link', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _ShareRepository();

    await tester.pumpWidget(
      _backendTestApp(
        home: const ShareScreen(targetType: 'event', targetId: 'event-1'),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();

    expect(repository.createdShares, [
      {'targetType': 'event', 'targetId': 'event-1'}
    ]);
    expect(find.text('https://frendly.test/abc'), findsOneWidget);
    expect(find.text('Ссылка готова'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail sends join request for request access',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingJoinRequestRepository();
    final router = GoRouter(
      initialLocation: '/meetings/requested',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'requested',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Отправить заявку'), findsOneWidget);
    expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);

    await tester.tap(find.text('Отправить заявку'));
    await tester.pumpAndSettle();

    expect(repository.createdJoinRequest, true);
    expect(find.text('Заявка отправлена'), findsOneWidget);
    expect(find.text('Отменить заявку'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail opens requirement actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/locked',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'locked',
          ),
        ),
        GoRoute(
          path: '/verify',
          builder: (_, __) => const Scaffold(body: Text('verify-opened')),
        ),
        GoRoute(
          path: '/paywall',
          builder: (_, __) => const Scaffold(body: Text('paywall-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_MeetingLockedRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Доступ закрыт'), findsOneWidget);
    expect(find.text('Нужна верификация'), findsOneWidget);
    expect(find.text('Нужен Frendly+'), findsOneWidget);
    expect(find.text('Пройти верификацию'), findsOneWidget);

    await tester.tap(find.text('Пройти верификацию'));
    await tester.pumpAndSettle();

    expect(find.text('verify-opened'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail opens paywall requirement action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/meetings/locked',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'locked',
          ),
        ),
        GoRoute(
          path: '/verify',
          builder: (_, __) => const Scaffold(body: Text('verify-opened')),
        ),
        GoRoute(
          path: '/paywall',
          builder: (_, __) => const Scaffold(body: Text('paywall-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(_MeetingLockedRepository()),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Открыть Frendly+').last);
    await tester.pumpAndSettle();

    expect(find.text('paywall-opened'), findsOneWidget);
  });

  testWidgets('mobile2 meeting detail invites following users', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingInviteRepository();
    final router = GoRouter(
      initialLocation: '/meetings/invite',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'invite',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.userPlus));
    await tester.pumpAndSettle();

    expect(repository.followingEventIds, ['invite']);
    expect(find.text('Кого позвать'), findsOneWidget);
    expect(find.text('Нина'), findsOneWidget);
    expect(find.text('Пригласить'), findsOneWidget);

    await tester.tap(find.text('Пригласить'));
    await tester.pumpAndSettle();

    expect(repository.invitedUserIds, ['friend-1']);
    expect(find.text('Отправлено'), findsOneWidget);
  });

  testWidgets('mobile2 meeting invite search debounces and cancels old request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingInviteSearchRepository();
    final router = GoRouter(
      initialLocation: '/meetings/invite',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'invite',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.userPlus));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.queries, [null]);
    expect(repository.cancelTokens.single.isCancelled, false);

    await tester.enterText(find.byType(TextField), 'ни');
    await tester.pump(const Duration(milliseconds: 249));

    expect(repository.queries, [null]);

    await tester.pump(const Duration(milliseconds: 1));

    expect(repository.queries, [null, 'ни']);
    expect(repository.cancelTokens.first.isCancelled, true);

    repository.completeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('mobile2 meeting invite sheet loads next following page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingInvitePagedRepository();
    final router = GoRouter(
      initialLocation: '/meetings/invite',
      routes: [
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (_, state) => MeetingDetailScreen(
            meetingId: state.pathParameters['meetingId'] ?? 'invite',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _backendTestOverrides(repository),
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.userPlus));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(repository.cursors, [null, 'next-1']);
    await tester.scrollUntilVisible(
      find.text('Друг 25'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Друг 25'), findsOneWidget);
  });

  testWidgets('mobile2 new meeting matches Frendly creation blocks',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Новая встреча'), findsOneWidget);
    expect(find.text('Добавить обложку'), findsOneWidget);
    expect(find.text('Название встречи'), findsOneWidget);
    expect(find.text('Короткое описание'), findsOneWidget);
    expect(find.text('Категория'.toUpperCase()), findsOneWidget);
    expect(find.text('Кофе'), findsOneWidget);
    expect(find.text('Музыка'), findsOneWidget);
    expect(find.text('Когда'.toUpperCase()), findsOneWidget);
    expect(find.text('Длительность'.toUpperCase()), findsNothing);
    expect(find.text('1.5'), findsNothing);
    expect(find.text('Где'.toUpperCase()), findsOneWidget);
    expect(find.text('Сколько людей'.toUpperCase()), findsOneWidget);

    await tester.ensureVisible(find.text('Прикрепить'.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('Афиша'), findsOneWidget);
    expect(find.text('Промо'), findsOneWidget);
    expect(find.text('Маршрут'), findsOneWidget);

    await tester.tap(find.text('Афиша'));
    await tester.pumpAndSettle();
    expect(find.text('Прикрепить из афиши'), findsOneWidget);
    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Завтра'), findsWidgets);
    expect(find.text('Музыка'), findsWidgets);
    expect(find.text('Бар'), findsWidgets);
    expect(find.text('Арт'), findsWidgets);
    await tester.tap(find.byIcon(LucideIcons.x).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Кому доступно'.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('Только верифицированные'), findsOneWidget);
    expect(find.text('Прошли проверку Frendly'), findsOneWidget);
    expect(find.text('Только Frendly+'), findsOneWidget);

    await tester.tap(find.text('Только верифицированные'));
    await tester.pumpAndSettle();
    expect(find.text('Сначала пройди верификацию'), findsOneWidget);

    await tester.tap(find.text('Только Frendly+'));
    await tester.pumpAndSettle();
    expect(find.text('Frendly+ доступен только подписчикам'), findsOneWidget);

    await tester.ensureVisible(find.text('Кто может видеть'.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('Все рядом'), findsOneWidget);
    expect(find.text('По ссылке'), findsOneWidget);

    await tester.ensureVisible(find.text('Продвинуть встречу'));
    await tester.pumpAndSettle();
    expect(find.text('100 FT'), findsOneWidget);
    expect(find.text('300 FT'), findsOneWidget);
    expect(find.text('500 FT'), findsOneWidget);
    expect(find.text('Опубликовать встречу'), findsOneWidget);

    await tester.ensureVisible(find.text('Промо'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Промо'));
    await tester.pumpAndSettle();

    expect(find.text('Промо · заведения со скидками'), findsOneWidget);
    expect(find.text('Surf Coffee'), findsOneWidget);
    expect(find.text('−15% по Frendly'), findsWidgets);
  });

  testWidgets('mobile2 meeting edit screen preloads hosted event data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(editEventId: 'edit-1'),
        repository: _MeetingEditRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактировать встречу'), findsOneWidget);
    expect(find.text('Новая встреча'), findsNothing);
    expect(find.text('Редактируемый ужин'), findsOneWidget);
    expect(find.text('Описание из базы'), findsOneWidget);
    expect(find.text('Brix'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Сохранить изменения'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Сохранить изменения'), findsOneWidget);
  });

  testWidgets(
      'mobile2 new meeting enables gated audience toggles for allowed host',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingAccessCreateRepository();
    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Маршрут'));
    await tester.tap(find.text('Маршрут'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Вечерний маршрут').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Кому доступно'.toUpperCase()));
    await tester.tap(find.text('Только верифицированные'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Только Frendly+'));
    await tester.pumpAndSettle();

    expect(find.text('Сначала пройди верификацию'), findsNothing);
    expect(find.text('Frendly+ доступен только подписчикам'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Опубликовать встречу'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать встречу'));
    await tester.pumpAndSettle();

    expect(repository.createdData?['requiresVerification'], true);
    expect(repository.createdData?['requiresFrendlyPlus'], true);
  });

  testWidgets('mobile2 new meeting place sheet offers typed address',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выбери место'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Покровка 12');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Использовать введённый адрес'), findsOneWidget);
    await tester.tap(find.text('Использовать введённый адрес'));
    await tester.pumpAndSettle();

    expect(find.text('Покровка 12'), findsOneWidget);
  });

  testWidgets('mobile2 new meeting defaults date and time to three hours ahead',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final expectedFrom = DateTime.now().add(const Duration(hours: 3));

    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final expectedTo = DateTime.now().add(const Duration(hours: 3));
    final expectedDates = {
      _formatDateForInput(expectedFrom),
      _formatDateForInput(expectedTo),
    };
    final expectedTimes = {
      _formatTimeForInput(expectedFrom),
      _formatTimeForInput(expectedTo),
    };

    expect(
      expectedDates.any((value) => find.text(value).evaluate().isNotEmpty),
      isTrue,
    );
    expect(
      expectedTimes.any((value) => find.text(value).evaluate().isNotEmpty),
      isTrue,
    );
  });

  testWidgets('mobile2 new meeting promo fills draft before publish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingCreateRepository();
    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Промо'));
    await tester.tap(find.text('Промо'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-promo-promo-1')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Опубликовать встречу'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать встречу'));
    await tester.pumpAndSettle();

    expect(repository.createdData?['title'], 'Встречаемся в Surf Coffee');
    expect(repository.createdData?['description'], '−15% по Frendly');
    expect(repository.createdData?['externalPlaceId'], 'place-1');
  });

  testWidgets('mobile2 new meeting promo uses only backend perks',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
        repository: _EmptyPerksMeetingCreateRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Промо'));
    await tester.tap(find.text('Промо'));
    await tester.pumpAndSettle();

    expect(find.text('В вашем городе нет промо'), findsOneWidget);
    expect(find.text('Surf Coffee'), findsNothing);
    expect(find.text('Brew Lab'), findsNothing);
  });

  testWidgets('mobile2 new meeting route fills draft before publish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingCreateRepository();
    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Маршрут'));
    await tester.tap(find.text('Маршрут'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Вечерний маршрут').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Вечерний маршрут'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Опубликовать встречу'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать встречу'));
    await tester.pumpAndSettle();

    expect(repository.createdData?['routeId'], 'route-1');
    expect(repository.createdData?['place'], contains('Вечерний маршрут'));
  });

  testWidgets('mobile2 new meeting promotes event after boosted publish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _MeetingCreateRepository();
    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Промо'));
    await tester.tap(find.text('Промо'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-promo-promo-1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Продвинуть встречу'));
    await tester.tap(find.text('Разгон'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Опубликовать встречу · −300 FT'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать встречу · −300 FT'));
    await tester.pumpAndSettle();

    expect(repository.createdData?['title'], 'Встречаемся в Surf Coffee');
    expect(repository.createdPromotions, [
      {
        'targetKind': 'event',
        'targetId': 'created-1',
        'optionId': 'boost-24',
      },
    ]);
  });

  testWidgets('mobile2 meetings filters count loaded meetings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const MeetingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Завтра'), findsOneWidget);
    expect(find.text('Эти выходные'), findsOneWidget);
    expect(find.text('Все'), findsWidgets);
    expect(find.text('10'), findsWidgets);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('8'), findsNothing);
    expect(find.text('6'), findsNothing);

    await tester.drag(find.byType(ListView).at(1), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(find.text('Бар'), findsOneWidget);
    expect(find.text('Арт'), findsOneWidget);
    expect(find.text('7'), findsNothing);
    expect(find.text('4'), findsNothing);
  });

  testWidgets('mobile2 home nearby meetings renders five upcoming cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _SixHomeMeetingsRepository();
    await tester.pumpWidget(
      _backendTestApp(
        home: const HomeScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ближайшие встречи'));
    await tester.pumpAndSettle();

    expect(repository.fetchEventLimits.first, 5);
    expect(find.text('Ближайшая встреча 1'), findsOneWidget);
    expect(find.text('Ближайшая встреча 5'), findsOneWidget);
    expect(find.text('Ближайшая встреча 6'), findsNothing);
  });

  testWidgets('mobile2 meetings loads ten cards then paginates on scroll',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _PagedMeetingsRepository();
    await tester.pumpWidget(
      _backendTestApp(
        home: const MeetingsScreen(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchEventLimits.first, 10);
    expect(repository.fetchEventCursors.first, isNull);
    expect(find.text('10+ встреч рядом'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(repository.fetchEventLimits, [10, 10]);
    expect(repository.fetchEventCursors, [null, 'page-2']);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2200));
    await tester.pumpAndSettle();

    expect(find.text('13 встреч рядом'), findsOneWidget);
  });

  testWidgets('mobile2 meetings category counts are zero when list is empty',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const MeetingsScreen(),
        repository: _EmptyMeetingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 встреч рядом'), findsOneWidget);
    expect(find.text('Встреч пока нет'), findsOneWidget);
    expect(find.text('10'), findsNothing);
    expect(find.text('8'), findsNothing);
    expect(find.text('6'), findsNothing);
  });

  testWidgets('mobile2 new meeting afisha sheet keeps front2 bottom height',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(),
        repository: _LongAfficheRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Афиша'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Афиша'));
    await tester.pumpAndSettle();

    final titleTop = tester.getTopLeft(find.text('Прикрепить из афиши')).dy;
    expect(titleTop, greaterThan(150));
    expect(find.text('Афиша 1'), findsOneWidget);
  });

  testWidgets('mobile2 new meeting applies affiche query prefill',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(afficheEventId: 'poster-1'),
        repository: _AfficheCreateRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Идем на Rooftop cinema'), findsOneWidget);
    expect(find.text('Кино на крыше'), findsOneWidget);
    expect(find.text('2026-05-20'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Rooftop 17'), findsWidgets);
    expect(find.text('Петровка 1'), findsOneWidget);
  });

  testWidgets('mobile2 new meeting publish sends affiche event id',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _AfficheCreateRepository();
    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(afficheEventId: 'poster-1'),
        repository: repository,
        overrides: [
          afficheClientGeoEnrichmentServiceProvider.overrideWithValue(
            AfficheClientGeoEnrichmentService(
              searcher: const _EmptyAfficheGeoSearcher(),
              backendSaver: repository.saveAfficheClientGeo,
              cacheStore: null,
              userScope: AppCacheUserScope.user('user-1'),
              throttle: Duration.zero,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Опубликовать встречу'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать встречу'));
    await tester.pumpAndSettle();

    expect(repository.createdData?['afficheEventId'], 'poster-1');
  });

  testWidgets('mobile2 new meeting waits for affiche geo before publish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _AfficheCreateRepository();
    final searcher = _PendingAfficheGeoSearcher();
    await tester.pumpWidget(
      _backendTestApp(
        home: const NewMeetingScreen(afficheEventId: 'poster-1'),
        repository: repository,
        overrides: [
          afficheClientGeoEnrichmentServiceProvider.overrideWithValue(
            AfficheClientGeoEnrichmentService(
              searcher: searcher,
              backendSaver: repository.saveAfficheClientGeo,
              cacheStore: null,
              userScope: AppCacheUserScope.user('user-1'),
              throttle: Duration.zero,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Опубликовать встречу'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать встречу'));
    await tester.pump();

    expect(repository.createdData, isNull);

    searcher.completeWith(
      const AfficheClientGeoPlaceResult(
        latitude: 55.763,
        longitude: 37.564,
        name: 'Rooftop 17',
        displayName: 'Rooftop 17, Петровка 1',
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.createdData?['afficheEventId'], 'poster-1');
    expect(repository.createdData?['latitude'], 55.763);
    expect(repository.createdData?['longitude'], 37.564);
  });

  testWidgets('mobile2 dating filters match Frendly controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _backendTestApp(
        home: const DatingFilterScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Фильтры'), findsOneWidget);
    expect(find.text('Кого показывать'), findsOneWidget);
    expect(find.text('Девушки'), findsOneWidget);
    expect(find.text('Парни'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Возраст'), findsOneWidget);
    expect(find.text('18–99'), findsOneWidget);
    expect(find.text('Расстояние'), findsOneWidget);
    expect(find.text('500 км'), findsOneWidget);
    expect(find.text('Цель'), findsOneWidget);
    expect(find.text('Свидание'), findsOneWidget);
    expect(find.text('Networking'), findsOneWidget);
    expect(find.text('Вайбы'), findsOneWidget);
    expect(find.text('Творческий'), findsOneWidget);
    expect(find.text('Только верифицированные'), findsOneWidget);
    expect(find.text('Профили с галочкой Frendly'), findsOneWidget);
    expect(find.text('Только Frendly+'), findsOneWidget);
    expect(find.text('Онлайн сейчас'), findsOneWidget);
    expect(find.text('Новые на этой неделе'), findsOneWidget);
    expect(find.text('Применить фильтры'), findsOneWidget);

    await tester.tap(find.text('Парни'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Активный'));
    await tester.pumpAndSettle();
    expect(find.text('Активный'), findsOneWidget);

    await tester.tap(find.text('Только верифицированные'));
    await tester.pumpAndSettle();
    expect(find.text('Только верифицированные'), findsOneWidget);
  });
}

Future<void> _pumpDateasyAppWelcome(
  WidgetTester tester, {
  BackendRepository? repository,
}) async {
  await tester.pumpWidget(
    DateasyApp(
      overrides: [
        appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        backendRepositoryProvider.overrideWithValue(
          repository ?? _AuthFlowRepository(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpWelcomeScreenForPlatform(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
        backendRepositoryProvider.overrideWithValue(_AuthFlowRepository()),
      ],
      child: MaterialApp(
        theme: DateasyTheme.theme.copyWith(platform: platform),
        home: const WelcomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _testAuthTokens = AuthTokens(
  accessToken: 'access',
  refreshToken: 'refresh',
);

const _testUser = BackendUser(
  id: 'user-1',
  name: 'Алекс',
  gender: 'male',
  onboardingComplete: true,
  city: 'Москва',
);

List<Override> _backendTestOverrides([BackendRepository? repository]) {
  return [
    appLocalCacheRuntimeDisabledProvider.overrideWith((_) => true),
    initialAuthTokensProvider.overrideWithValue(_testAuthTokens),
    currentUserProvider.overrideWith((_) => _testUser),
    radarNativeMapEnabledProvider.overrideWith((_) => false),
    backendRepositoryProvider.overrideWithValue(
      repository ?? _AuthFlowRepository(),
    ),
  ];
}

Widget _backendTestApp({
  required Widget home,
  BackendRepository? repository,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ..._backendTestOverrides(repository),
      ...overrides,
    ],
    child: MaterialApp(
      theme: DateasyTheme.theme,
      home: home,
    ),
  );
}

class _AuthFlowRepository extends _RecordingOnboardingRepository {
  @override
  Future<PhoneAuthChallenge> requestPhoneCode(
    String phoneNumber, {
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    return PhoneAuthChallenge(
      challengeId: 'phone-challenge',
      maskedPhone: phoneNumber,
    );
  }

  @override
  Future<AuthSession> verifyPhone({
    required String challengeId,
    required String code,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    if (code.length < 4) {
      throw const BackendActionException(message: 'invalid_code');
    }
    return const AuthSession(
      tokens: AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      userId: 'user-1',
      isNewUser: true,
    );
  }

  @override
  Future<TelegramAuthStart> startTelegramAuth({
    String? startToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    return const TelegramAuthStart(
      loginSessionId: 'telegram-session',
      botUrl: '',
      codeLength: 4,
    );
  }

  @override
  Future<AuthSession> verifyTelegramAuth({
    required String loginSessionId,
    required String code,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    if (code.length < 4) {
      throw const BackendActionException(message: 'invalid_code');
    }
    return const AuthSession(
      tokens: AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      userId: 'user-1',
      isNewUser: true,
    );
  }

  @override
  Future<AuthSession> verifyGoogleAuth({
    required String idToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    return const AuthSession(
      tokens: AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      userId: 'user-1',
      isNewUser: true,
    );
  }

  @override
  Future<AuthSession> verifyYandexAuth({
    required String oauthToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    return const AuthSession(
      tokens: AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      userId: 'user-1',
      isNewUser: true,
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchEvents({
    String? city,
    String? filter,
    String? query,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? sort,
    String? date,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    final primary = BackendCardItem(
      id: 'event-1',
      title: 'Speciality coffee tasting',
      subtitle: 'Bloom Coffee',
      startsAt: DateTime(2026, 5, 19, 19),
    );
    if (limit == 10 && cursor == null) {
      return BackendPage(
        nextCursor: 'event-page-2',
        items: [
          primary,
          for (var index = 2; index <= 10; index++)
            BackendCardItem(
              id: 'event-$index',
              title: 'Встреча $index',
              subtitle: 'Frendly spot',
              startsAt: DateTime(2026, 5, 19, 19),
            ),
        ],
      );
    }
    if (limit == 10 && cursor == 'event-page-2') {
      return BackendPage(
        items: [
          for (var index = 11; index <= 32; index++)
            BackendCardItem(
              id: 'event-$index',
              title: 'Встреча $index',
              subtitle: 'Frendly spot',
              startsAt: DateTime(2026, 5, 19, 19),
            ),
        ],
      );
    }
    if (limit == 20) {
      return BackendPage(
        items: [
          primary,
          for (var index = 2; index <= 32; index++)
            BackendCardItem(
              id: 'event-$index',
              title: 'Встреча $index',
              subtitle: 'Frendly spot',
              startsAt: DateTime(2026, 5, 19, 19),
            ),
        ],
      );
    }
    return BackendPage(items: [primary]);
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchMeetupChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchPersonalChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<BackendCardItem> joinEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: eventId,
      title: eventId == 'event-1'
          ? 'Speciality coffee tasting'
          : 'Встреча ${eventId.replaceAll('event-', '')}',
      subtitle: eventId == 'event-1' ? 'Bloom Coffee' : 'Frendly spot',
      startsAt: DateTime(2026, 5, 19, 19),
      raw: const {'participantState': 'joined'},
    );
  }

  @override
  Future<BackendCardItem> leaveEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: eventId,
      title: eventId == 'event-1'
          ? 'Speciality coffee tasting'
          : 'Встреча ${eventId.replaceAll('event-', '')}',
      subtitle: eventId == 'event-1' ? 'Bloom Coffee' : 'Frendly spot',
      startsAt: DateTime(2026, 5, 19, 19),
    );
  }

  @override
  Future<Map<String, Object?>> logout({CancelToken? cancelToken}) async {
    return const {};
  }

  @override
  Future<BackendCardItem> fetchOwnProfile({CancelToken? cancelToken}) async {
    return const BackendCardItem(
      id: 'user-1',
      title: 'Алекс',
      subtitle: 'Люблю кофе, прогулки и спокойные встречи',
      imageUrl: 'https://example.com/alex.jpg',
      city: 'Москва',
      raw: {
        'verified': true,
        'age': 27,
        'area': 'Патрики',
        'meetupCount': 12,
        'rating': 4.9,
        'stats': {
          'matchesCount': 48,
        },
        'interests': [
          'Speciality coffee',
          'Винил',
          'Прогулки',
        ],
        'photos': [
          {'url': 'https://example.com/alex-1.jpg'},
          {'url': 'https://example.com/alex-2.jpg'},
        ],
      },
    );
  }

  @override
  Future<VerificationStateData> fetchVerification({
    CancelToken? cancelToken,
  }) async {
    return const VerificationStateData(
      status: 'pending',
      selfieDone: false,
      documentDone: false,
    );
  }

  @override
  Future<SubscriptionStateData> fetchSubscription({
    CancelToken? cancelToken,
  }) async {
    return const SubscriptionStateData(status: 'inactive');
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchAffiche({
    String? city,
    String? query,
    String? date,
    String? dateFrom,
    String? dateTo,
    String? priceMode,
    String? category,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendCardItem(
          id: 'poster-1',
          title: 'Rooftop cinema',
          city: 'cinema',
          startsAt: DateTime(2026, 5, 20, 20),
        ),
      ],
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchMapEvents({
    String? city,
    String? date,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
    double? southWestLatitude,
    double? southWestLongitude,
    double? northEastLatitude,
    double? northEastLongitude,
    int limit = 80,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(
      items: [
        BackendCardItem(
          id: 'map-1',
          title: 'Rooftop 17 · винил-вечер',
          subtitle: '0.8 км',
          city: 'Сегодня 21:00',
          latitude: 55.76,
          longitude: 37.61,
        ),
        BackendCardItem(
          id: 'map-2',
          title: 'Brew Lab · спешелти',
          subtitle: '0.4 км',
          city: 'Сейчас',
          latitude: 55.75,
          longitude: 37.6,
        ),
        BackendCardItem(
          id: 'map-3',
          title: 'Noor Bar',
          subtitle: '1.1 км',
          city: 'Сегодня',
          latitude: 55.77,
          longitude: 37.62,
        ),
        BackendCardItem(
          id: 'map-4',
          title: 'Art Gallery',
          subtitle: '1.4 км',
          city: 'Завтра',
          latitude: 55.74,
          longitude: 37.59,
        ),
        BackendCardItem(
          id: 'map-5',
          title: 'Park Run',
          subtitle: '2.0 км',
          city: 'Суббота',
          latitude: 55.78,
          longitude: 37.63,
        ),
      ],
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchPerks({
    String? city,
    String? category,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(
      items: [
        BackendCardItem(
          id: 'perk-1',
          title: 'Surf Coffee',
          subtitle: '−15% по Frendly',
        ),
      ],
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchMatches({
    int limit = 10,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(
      items: [
        BackendCardItem(id: 'match-1', title: 'Маша'),
        BackendCardItem(id: 'match-2', title: 'Лера'),
      ],
    );
  }

  @override
  Future<TokenWalletData> fetchTokenWallet({CancelToken? cancelToken}) async {
    return const TokenWalletData(balance: 240);
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchHistory({
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendCardItem(
          id: 'history-1',
          title: 'Винил-вечер на крыше',
          subtitle: 'Rooftop 17',
          startsAt: DateTime(2026, 5, 19, 21),
          raw: const {'role': 'Хост'},
        ),
      ],
    );
  }

  @override
  Future<AppSettingsData> fetchSettings({CancelToken? cancelToken}) async {
    return const AppSettingsData(
      allowPush: true,
      discoverable: true,
      showAge: true,
      darkMode: true,
    );
  }

  @override
  Future<AppSettingsData> updateSettings(
    Map<String, Object?> data, {
    CancelToken? cancelToken,
  }) async {
    return AppSettingsData.fromJson(data);
  }

  @override
  Future<SafetyData> fetchSafety({CancelToken? cancelToken}) async {
    return const SafetyData(
      trustScore: 72,
      settings: AppSettingsData(
        autoSharePlans: true,
        hideExactLocation: false,
      ),
    );
  }

  @override
  Future<SafetyData> updateSafety(
    Map<String, Object?> data, {
    CancelToken? cancelToken,
  }) async {
    return SafetyData(
      trustScore: 72,
      settings: AppSettingsData.fromJson(data),
      raw: {
        'trustScore': 72,
        'settings': data,
      },
    );
  }
}

class _DelayedAuthRepository extends _AuthFlowRepository {
  final Completer<void> _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<AuthSession> verifyTelegramAuth({
    required String loginSessionId,
    required String code,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    await _completer.future;
    return super.verifyTelegramAuth(
      loginSessionId: loginSessionId,
      code: code,
      acceptedTerms: acceptedTerms,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<AuthSession> verifyGoogleAuth({
    required String idToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    await _completer.future;
    return super.verifyGoogleAuth(
      idToken: idToken,
      acceptedTerms: acceptedTerms,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<AuthSession> verifyYandexAuth({
    required String oauthToken,
    bool acceptedTerms = true,
    CancelToken? cancelToken,
  }) async {
    await _completer.future;
    return super.verifyYandexAuth(
      oauthToken: oauthToken,
      acceptedTerms: acceptedTerms,
      cancelToken: cancelToken,
    );
  }
}

class _FakeGoogleAuthGateway implements GoogleAuthGateway {
  _FakeGoogleAuthGateway({required this.idToken});

  final String idToken;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
  }) async {}

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<String?> authenticateIdToken({required List<String> scopeHint}) async {
    return idToken;
  }

  @override
  Future<void> signOut() async {}
}

class _EmptyMeetingsRepository extends _AuthFlowRepository {
  @override
  Future<BackendPage<BackendCardItem>> fetchEvents({
    String? city,
    String? filter,
    String? query,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? sort,
    String? date,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }
}

class _SixHomeMeetingsRepository extends _AuthFlowRepository {
  final fetchEventLimits = <int>[];

  @override
  Future<BackendPage<BackendCardItem>> fetchEvents({
    String? city,
    String? filter,
    String? query,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? sort,
    String? date,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    fetchEventLimits.add(limit);
    return BackendPage(
      items: [
        for (var index = 1; index <= 6; index += 1)
          BackendCardItem(
            id: 'home-upcoming-$index',
            title: 'Ближайшая встреча $index',
            subtitle: 'Frendly spot',
            startsAt: DateTime(2026, 5, 19, 18 + index),
          ),
      ],
    );
  }
}

class _PagedMeetingsRepository extends _AuthFlowRepository {
  final fetchEventLimits = <int>[];
  final fetchEventCursors = <String?>[];

  @override
  Future<BackendPage<BackendCardItem>> fetchEvents({
    String? city,
    String? filter,
    String? query,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? sort,
    String? date,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    fetchEventLimits.add(limit);
    fetchEventCursors.add(cursor);
    if (cursor == 'page-2') {
      return BackendPage(
        items: [
          for (var index = 11; index <= 13; index += 1)
            BackendCardItem(
              id: 'paged-meeting-$index',
              title: 'Пагинация встреч $index',
              subtitle: 'Frendly spot',
              startsAt: DateTime(2026, 5, 20, 18),
            ),
        ],
      );
    }
    return BackendPage(
      nextCursor: 'page-2',
      items: [
        for (var index = 1; index <= 10; index += 1)
          BackendCardItem(
            id: 'paged-meeting-$index',
            title: 'Пагинация встреч $index',
            subtitle: 'Frendly spot',
            startsAt: DateTime(2026, 5, 19, 18),
          ),
      ],
    );
  }
}

class _LongAfficheRepository extends _AuthFlowRepository {
  @override
  Future<BackendPage<BackendCardItem>> fetchAffiche({
    String? city,
    String? query,
    String? date,
    String? dateFrom,
    String? dateTo,
    String? priceMode,
    String? category,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        for (var index = 1; index <= 24; index++)
          BackendCardItem(
            id: 'poster-$index',
            title: 'Афиша $index',
            city: 'Музыка',
            startsAt: DateTime(2026, 5, 20, 20),
          ),
      ],
    );
  }
}

class _AfficheCreateRepository extends _AuthFlowRepository {
  Map<String, Object?>? createdData;
  AfficheClientGeoSaveRequest? savedGeoRequest;

  @override
  Future<BackendCardItem> fetchAfficheDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: eventId,
      title: 'Rooftop cinema',
      subtitle: 'Rooftop 17',
      city: 'Кино',
      startsAt: DateTime(2026, 5, 20, 20),
      raw: const {
        'id': 'poster-1',
        'title': 'Rooftop cinema',
        'description': 'Кино на крыше',
        'venue': 'Rooftop 17',
        'address': 'Петровка 1',
        'price': '1500 ₽',
        'actionUrl': 'https://tickets.test/poster-1',
      },
    );
  }

  @override
  Future<AfficheClientGeoSaveResult> saveAfficheClientGeo(
    AfficheClientGeoSaveRequest request, {
    CancelToken? cancelToken,
  }) async {
    savedGeoRequest = request;
    return AfficheClientGeoSaveResult(
      id: request.id,
      latitude: request.latitude,
      longitude: request.longitude,
      address: request.displayName,
      saved: true,
      code: 'saved',
    );
  }

  @override
  Future<BackendCardItem> createEvent({
    required Map<String, Object?> data,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    createdData = data;
    return const BackendCardItem(
      id: 'created-1',
      title: 'Created',
      raw: {'participantState': 'host'},
    );
  }
}

class _PendingAfficheGeoSearcher implements AfficheClientGeoPlaceSearcher {
  Completer<List<AfficheClientGeoPlaceResult>>? _pending;

  @override
  Future<List<AfficheClientGeoPlaceResult>> search(
    String query, {
    int limit = 8,
    CancelToken? cancelToken,
  }) {
    final pending = Completer<List<AfficheClientGeoPlaceResult>>();
    _pending = pending;
    return pending.future;
  }

  void completeWith(AfficheClientGeoPlaceResult result) {
    _pending?.complete([result]);
  }
}

class _EmptyAfficheGeoSearcher implements AfficheClientGeoPlaceSearcher {
  const _EmptyAfficheGeoSearcher();

  @override
  Future<List<AfficheClientGeoPlaceResult>> search(
    String query, {
    int limit = 8,
    CancelToken? cancelToken,
  }) async {
    return const [];
  }
}

class _MeetingCreateRepository extends _AuthFlowRepository {
  Map<String, Object?>? createdData;
  final createdPromotions = <Map<String, Object?>>[];

  @override
  Future<BackendPage<BackendCardItem>> fetchPerks({
    String? city,
    String? category,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(
      items: [
        BackendCardItem(
          id: 'promo-1',
          title: 'Surf Coffee',
          subtitle: '−15% по Frendly',
          city: 'Москва',
          raw: {
            'description': '−15% по Frendly',
            'venueName': 'Surf Coffee',
            'address': 'Покровка 17',
            'placeId': 'place-1',
          },
        ),
      ],
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchRoutes({
    String? city,
    String? query,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(
      items: [
        BackendCardItem(
          id: 'route-1',
          title: 'Вечерний маршрут',
          subtitle: 'Москва · 2 часа',
          city: 'Москва',
          raw: {
            'area': 'Патрики',
            'durationLabel': '2 часа',
            'blurb': 'Маршрут для вечера',
          },
        ),
      ],
    );
  }

  @override
  Future<BackendCardItem> createEvent({
    required Map<String, Object?> data,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    createdData = data;
    return const BackendCardItem(
      id: 'created-1',
      title: 'Created',
      raw: {'participantState': 'host'},
    );
  }

  @override
  Future<TokenWalletData> createPromotion({
    required String targetKind,
    required String targetId,
    String optionId = 'boost-24',
    CancelToken? cancelToken,
  }) async {
    createdPromotions.add({
      'targetKind': targetKind,
      'targetId': targetId,
      'optionId': optionId,
    });
    return const TokenWalletData(balance: 190);
  }
}

class _EmptyPerksMeetingCreateRepository extends _MeetingCreateRepository {
  @override
  Future<BackendPage<BackendCardItem>> fetchPerks({
    String? city,
    String? category,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }
}

class _MeetingEditRepository extends _MeetingCreateRepository {
  @override
  Future<BackendCardItem> fetchHostedEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: eventId,
      title: 'Редактируемый ужин',
      subtitle: 'Brix, Петровка',
      startsAt: DateTime(2026, 5, 20, 19, 30),
      raw: const {
        'description': 'Описание из базы',
        'place': 'Brix',
        'address': 'Петровка 12',
        'capacity': 8,
        'joinMode': 'request',
        'accessMode': 'request',
        'visibilityMode': 'friends',
        'genderMode': 'female',
        'requiresVerification': true,
        'requiresFrendlyPlus': true,
      },
    );
  }
}

class _MeetingAccessCreateRepository extends _MeetingCreateRepository {
  @override
  Future<VerificationStateData> fetchVerification({
    CancelToken? cancelToken,
  }) async {
    return const VerificationStateData(
      status: 'verified',
      selfieDone: true,
      documentDone: true,
    );
  }

  @override
  Future<SubscriptionStateData> fetchSubscription({
    CancelToken? cancelToken,
  }) async {
    return const SubscriptionStateData(status: 'active');
  }
}

class _WalletRepository extends _AuthFlowRepository {
  @override
  Future<TokenWalletData> fetchTokenWallet({CancelToken? cancelToken}) async {
    return const TokenWalletData(
      balance: 240,
      history: [
        BackendCardItem(
          id: 'ledger-1',
          title: '',
          raw: {
            'amount': 100,
            'type': 'topup',
            'note': 'Пополнение токенов',
            'timestamp': '2026-05-19T10:00:00.000Z',
          },
        ),
        BackendCardItem(
          id: 'ledger-2',
          title: '',
          raw: {
            'amount': 250,
            'type': 'spend',
            'note': 'Frendly+',
            'timestamp': '2026-05-18T10:00:00.000Z',
          },
        ),
      ],
      raw: {
        'promoOptions': [
          {
            'id': 'boost-24',
            'title': 'Буст · 24 часа',
            'subtitle': 'Топ ленты + бейдж',
            'cost': 80,
            'durationHours': 24,
          },
        ],
      },
    );
  }

  @override
  Future<PaymentsCatalog> fetchPaymentsCatalog({
    CancelToken? cancelToken,
  }) async {
    return const PaymentsCatalog(
      tbankEnabled: true,
      tokenPacks: [
        TokenPackProduct(
          id: 'p1',
          label: 'Базовый',
          tokens: 100,
          priceRub: 199,
        ),
      ],
    );
  }

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans({
    CancelToken? cancelToken,
  }) async {
    return const [
      SubscriptionPlan(
        id: 'month',
        label: 'Месячный',
        tokenCost: 250,
        tokenMonthlyCost: 250,
      ),
    ];
  }
}

class _CityRepository extends _AuthFlowRepository {
  final updatedProfile = <Map<String, Object?>>[];

  @override
  Future<int> fetchNotificationUnreadCount({CancelToken? cancelToken}) async {
    return 0;
  }

  @override
  Future<BackendCardItem> updateOwnProfile({
    required Map<String, Object?> data,
    CancelToken? cancelToken,
  }) async {
    updatedProfile.add(data);
    return BackendCardItem(
      id: 'user-1',
      title: 'Алекс',
      city: data['city']?.toString(),
      raw: data,
    );
  }
}

class _HostDashboardRepository extends _AuthFlowRepository {
  final approvedRequestIds = <String>[];
  final rejectedRequestIds = <String>[];

  @override
  Future<HostDashboardData> fetchHostDashboard({
    int eventsLimit = 20,
    int requestsLimit = 20,
    CancelToken? cancelToken,
  }) async {
    return HostDashboardData(
      stats: const HostDashboardStats(
        meetupsCount: 3,
        rating: 4.9,
        guestsCount: 18,
        fillRate: 80,
      ),
      pendingRequestsCount: 1,
      requests: const [
        HostJoinRequestData(
          id: 'request-1',
          eventId: 'event-1',
          eventTitle: 'Кофе на Патриках',
          userId: 'user-nina',
          userName: 'Нина',
          avatarUrl: null,
          verified: true,
          frendlyPlus: true,
        ),
      ],
      events: [
        BackendCardItem(
          id: 'event-1',
          title: 'Будущая встреча',
          subtitle: 'Скоро',
          startsAt: DateTime.now().add(const Duration(days: 2)),
          raw: const {
            'status': 'active',
            'capacity': 8,
            'participantCount': 5,
            'chatId': 'chat-event-1',
          },
        ),
        BackendCardItem(
          id: 'event-past',
          title: 'Прошлая встреча',
          subtitle: 'Вчера',
          startsAt: DateTime.now().subtract(const Duration(days: 1)),
          raw: const {
            'status': 'active',
            'capacity': 8,
            'participantCount': 5,
            'chatId': 'chat-event-past',
          },
        ),
      ],
      raw: const {
        'stats': {
          'meetupsCount': 3,
          'rating': 4.9,
          'guestsCount': 18,
          'fillRate': 80,
        },
        'pendingRequestsCount': 1,
        'requests': [
          {
            'id': 'request-1',
            'eventId': 'event-1',
            'eventTitle': 'Кофе на Патриках',
            'userId': 'user-nina',
            'userName': 'Нина',
            'verified': true,
            'frendlyPlus': true,
          }
        ],
        'events': [
          {
            'id': 'event-1',
            'title': 'Кофе на Патриках',
            'subtitle': 'Сегодня',
            'startsAt': '2026-05-20T19:00:00.000Z',
            'status': 'active',
            'capacity': 8,
            'participantCount': 5,
            'chatId': 'chat-event-1',
          }
        ],
      },
    );
  }

  @override
  Future<HostJoinRequestData> approveHostRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    approvedRequestIds.add(requestId);
    return const HostJoinRequestData(
      id: 'request-1',
      eventId: 'event-1',
      eventTitle: 'Кофе на Патриках',
      userId: 'user-nina',
      userName: 'Нина',
      status: 'approved',
      verified: true,
      frendlyPlus: true,
    );
  }

  @override
  Future<HostJoinRequestData> rejectHostRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    rejectedRequestIds.add(requestId);
    return const HostJoinRequestData(
      id: 'request-1',
      eventId: 'event-1',
      eventTitle: 'Кофе на Патриках',
      userId: 'user-nina',
      userName: 'Нина',
      status: 'rejected',
      verified: true,
      frendlyPlus: true,
    );
  }
}

class _VerificationRepository extends _AuthFlowRepository {
  _VerificationRepository({
    VerificationStateData state = const VerificationStateData(
      status: 'not_started',
      selfieDone: false,
      documentDone: false,
    ),
  }) : _state = state;

  VerificationStateData _state;

  final submittedSteps = <String>[];

  @override
  Future<VerificationStateData> fetchVerification({
    CancelToken? cancelToken,
  }) async {
    return _state;
  }

  @override
  Future<VerificationStateData> submitVerification({
    required String step,
    required String assetId,
    CancelToken? cancelToken,
  }) async {
    submittedSteps.add(step);
    if (step == 'selfie') {
      _state = const VerificationStateData(
        status: 'selfie_submitted',
        selfieDone: true,
        documentDone: false,
      );
    } else if (step == 'document') {
      _state = const VerificationStateData(
        status: 'under_review',
        selfieDone: true,
        documentDone: true,
      );
    }
    return _state;
  }
}

class _SosRepository extends _AuthFlowRepository {
  final updatedSafety = <Map<String, Object?>>[];

  @override
  Future<SafetyData> fetchSafety({CancelToken? cancelToken}) async {
    return const SafetyData(
      trustScore: 80,
      settings: AppSettingsData(autoSharePlans: true),
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchTrustedContacts({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(
      items: [
        BackendCardItem(
          id: 'contact-mom',
          title: 'Мама',
          raw: {
            'name': 'Мама',
            'channel': 'phone',
            'value': '+79991230021',
          },
        ),
      ],
    );
  }

  @override
  Future<SafetyData> updateSafety(
    Map<String, Object?> data, {
    CancelToken? cancelToken,
  }) async {
    updatedSafety.add(data);
    return SafetyData(
      trustScore: 80,
      settings: AppSettingsData.fromJson(data),
      raw: {
        'trustScore': 80,
        'settings': data,
      },
    );
  }
}

class _BillingRepository extends _AuthFlowRepository {
  @override
  Future<TokenWalletData> fetchTokenWallet({CancelToken? cancelToken}) async {
    return const TokenWalletData(balance: 700);
  }

  @override
  Future<PaymentsCatalog> fetchPaymentsCatalog({
    CancelToken? cancelToken,
  }) async {
    return const PaymentsCatalog(
      tbankEnabled: true,
      raw: {
        'perks': [
          'Безлимит лайков и свайпов',
          'Кто тебя лайкнул',
          '5 буст-вечеров в месяц',
          'AI-маршруты без лимитов',
        ],
      },
    );
  }

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans({
    CancelToken? cancelToken,
  }) async {
    return const [
      SubscriptionPlan(
        id: 'm',
        label: '1 месяц',
        tokenCost: 250,
        priceRub: 499,
        priceMonthlyRub: 499,
        tokenMonthlyCost: 250,
        appleProductId: 'frendly.plus.month',
      ),
      SubscriptionPlan(
        id: 'q',
        label: '3 месяца',
        tokenCost: 600,
        priceRub: 1199,
        priceMonthlyRub: 400,
        tokenMonthlyCost: 200,
        badge: '−20%',
        appleProductId: 'frendly.plus.quarter',
      ),
      SubscriptionPlan(
        id: 'y',
        label: '12 месяцев',
        tokenCost: 1800,
        priceRub: 3499,
        priceMonthlyRub: 292,
        tokenMonthlyCost: 150,
        badge: 'Лучшее',
        appleProductId: 'frendly.plus.year',
      ),
    ];
  }
}

class _FailingAiBuilderRepository extends _AuthFlowRepository {
  @override
  Future<EveningAiDraftData> createEveningAiDraft({
    required String prompt,
    String? city,
    CancelToken? cancelToken,
  }) async {
    throw StateError('generation failed');
  }
}

class _PendingAiBuilderRepository extends _AuthFlowRepository {
  final Completer<EveningAiDraftData> completer =
      Completer<EveningAiDraftData>();

  @override
  Future<EveningAiDraftData> createEveningAiDraft({
    required String prompt,
    String? city,
    CancelToken? cancelToken,
  }) {
    return completer.future;
  }
}

class _PendingAiBuilderResultRepository extends _AuthFlowRepository {
  final Completer<EveningAiDraftData> regenerateCompleter =
      Completer<EveningAiDraftData>();
  final Completer<EveningAiDraftData> regenerateStepCompleter =
      Completer<EveningAiDraftData>();

  @override
  Future<EveningAiDraftData> fetchEveningAiDraft(
    String draftId, {
    CancelToken? cancelToken,
  }) async {
    return _testEveningAiDraft(draftId: draftId);
  }

  @override
  Future<EveningAiDraftData> regenerateEveningAiDraft(
    String draftId, {
    CancelToken? cancelToken,
  }) {
    return regenerateCompleter.future;
  }

  @override
  Future<EveningAiDraftData> regenerateEveningAiDraftStep({
    required String draftId,
    required int stepIndex,
    CancelToken? cancelToken,
  }) {
    return regenerateStepCompleter.future;
  }
}

EveningAiDraftData _testEveningAiDraft({String draftId = 'draft-1'}) {
  return EveningAiDraftData(
    draftId: draftId,
    currentStepIndex: 0,
    route: const EveningAiRouteData(
      id: 'route-1',
      title: 'Тихий вечер',
      area: 'Патрики',
      durationLabel: '2 часа',
      totalPriceFrom: 2500,
      steps: [
        EveningAiRouteStepData(
          title: 'Винный бар',
          place: 'Brix',
          time: '19:00',
          durationLabel: '1 час',
          price: 1500,
        ),
        EveningAiRouteStepData(
          title: 'Десерт',
          place: 'Cake Lab',
          time: '20:30',
          durationLabel: '45 минут',
          price: 1000,
        ),
      ],
    ),
  );
}

class _EmptyHistoryRepository extends _AuthFlowRepository {
  @override
  Future<BackendPage<BackendCardItem>> fetchHistory({
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }
}

class _CountingBillingRepository extends _BillingRepository {
  int walletCalls = 0;
  int catalogCalls = 0;
  int planCalls = 0;

  @override
  Future<TokenWalletData> fetchTokenWallet({CancelToken? cancelToken}) {
    walletCalls += 1;
    return super.fetchTokenWallet(cancelToken: cancelToken);
  }

  @override
  Future<PaymentsCatalog> fetchPaymentsCatalog({CancelToken? cancelToken}) {
    catalogCalls += 1;
    return super.fetchPaymentsCatalog(cancelToken: cancelToken);
  }

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans({
    CancelToken? cancelToken,
  }) {
    planCalls += 1;
    return super.fetchSubscriptionPlans(cancelToken: cancelToken);
  }
}

Future<void> _goToOnboardingPermissions(WidgetTester tester) async {
  for (var index = 0; index < 9; index += 1) {
    if (find.text('Контакты').evaluate().isNotEmpty) {
      await tester.enterText(find.byType(EditableText).first, 'Алекс');
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
  }
  expect(find.text('Разрешения'), findsOneWidget);
}

Widget _onboardingHarness(
  _RecordingOnboardingRepository repository, {
  OnboardingPermissionService? permissionService,
  YandexCitySearchService? citySearchService,
}) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: Center(
            child: Consumer(
              builder: (context, ref, _) {
                final complete =
                    ref.watch(currentUserProvider)?.onboardingComplete;
                return Text('home-opened complete=$complete');
              },
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      backendRepositoryProvider.overrideWithValue(repository),
      currentUserProvider.overrideWith(
        (ref) => const BackendUser(
          id: 'user-1',
          name: 'Алекс',
          onboardingComplete: false,
        ),
      ),
      onboardingProvider.overrideWith(
        (ref) async => repository.fetchOnboarding(),
      ),
      if (permissionService != null)
        onboardingPermissionServiceProvider.overrideWithValue(
          permissionService,
        ),
      yandexCitySearchServiceProvider.overrideWithValue(
        citySearchService ?? _FakeYandexCitySearchService(),
      ),
    ],
    child: MaterialApp.router(
      theme: DateasyTheme.theme,
      routerConfig: router,
    ),
  );
}

class _FakeYandexCitySearchService extends YandexCitySearchService {
  _FakeYandexCitySearchService({this.results = const []});

  final List<CitySearchResult> results;
  final List<String> queries = [];

  @override
  Future<List<CitySearchResult>> search(String query, {int limit = 8}) async {
    queries.add(query);
    return results.take(limit).toList(growable: false);
  }
}

class _MeetingChatRepository extends BackendRepository {
  _MeetingChatRepository() : super(Dio());

  static const _summary = BackendChatSummary(
    id: 'coffee',
    title: 'Speciality coffee tasting',
    kind: 'meetup',
    raw: {
      'id': 'coffee',
      'title': 'Speciality coffee tasting',
      'kind': 'meetup',
      'eventId': 'coffee',
      'status': 'Сегодня',
      'time': '19:30',
      'contextLine': 'Brew Lab, Патрики',
      'memberProfiles': [
        {'userId': 'u-lia', 'name': 'Лия', 'online': true},
        {'userId': 'u-masha', 'name': 'Маша', 'online': true},
        {'userId': 'u-sasha', 'name': 'Саша', 'online': true},
        {'userId': 'u-kirill', 'name': 'Кирилл', 'online': true},
        {'userId': 'u-anya', 'name': 'Аня', 'online': false},
        {
          'userId': 'user-1',
          'name': 'Вы',
          'online': false,
          'isCurrentUser': true,
        },
      ],
    },
  );

  @override
  Future<BackendPage<BackendChatSummary>> fetchMeetupChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: [_summary]);
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchPersonalChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendChatMessage(
          id: 'system-1',
          chatId: chatId,
          text: 'Встреча создана · сегодня 12:04',
          senderName: 'Frendly',
          createdAt: DateTime(2026, 5, 19, 12, 4),
        ),
        BackendChatMessage(
          id: 'message-1',
          chatId: chatId,
          text: 'Привеет! Я хост, очень рада всем 🤍',
          senderId: 'u-lia',
          senderName: 'Лия',
          createdAt: DateTime(2026, 5, 19, 12, 12),
        ),
        BackendChatMessage(
          id: 'message-2',
          chatId: chatId,
          text: 'Огонь, я тогда подтянусь к 19:30 ✌️',
          senderId: 'u-sasha',
          senderName: 'Саша',
          createdAt: DateTime(2026, 5, 19, 12, 18),
        ),
      ],
    );
  }

  @override
  Future<Map<String, Object?>> markChatRead(
    String chatId, {
    required String messageId,
    CancelToken? cancelToken,
  }) async {
    return const {};
  }
}

class _CommunityChatRepository extends BackendRepository {
  _CommunityChatRepository() : super(Dio());

  static const _summary = BackendChatSummary(
    id: 'community-chat-1',
    title: 'Wine club',
    kind: 'community',
    raw: {
      'id': 'community-chat-1',
      'title': 'Wine club',
      'kind': 'community',
      'communityId': 'community-1',
      'membersCount': 12,
      'memberProfiles': [
        {'userId': 'u-lia', 'name': 'Лия', 'online': true},
        {'userId': 'u-sasha', 'name': 'Саша', 'online': true},
        {'userId': 'user-1', 'name': 'Вы', 'isCurrentUser': true},
      ],
    },
  );

  @override
  Future<BackendCardItem> fetchCommunityDetail(
    String communityId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: communityId,
      title: 'Wine club',
      raw: const {
        'id': 'community-1',
        'name': 'Wine club',
        'chatId': 'community-chat-1',
      },
    );
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchMeetupChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchPersonalChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }

  @override
  Future<BackendPage<BackendChatSummary>> fetchCommunityChats({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: [_summary]);
  }

  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendChatMessage(
          id: 'message-1',
          chatId: chatId,
          text: 'Привет сообществу',
          senderId: 'u-lia',
          senderName: 'Лия',
          createdAt: DateTime(2026, 5, 19, 12, 12),
        ),
      ],
    );
  }

  @override
  Future<Map<String, Object?>> markChatRead(
    String chatId, {
    required String messageId,
    CancelToken? cancelToken,
  }) async {
    return const {};
  }
}

class _CommunityChatRestoredSummaryRepository extends _CommunityChatRepository {
  var messagesLoaded = false;
  var communityFetches = 0;

  @override
  Future<BackendPage<BackendChatSummary>> fetchCommunityChats({
    CancelToken? cancelToken,
  }) async {
    communityFetches += 1;
    if (!messagesLoaded) {
      return const BackendPage(items: []);
    }
    return super.fetchCommunityChats(cancelToken: cancelToken);
  }

  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final page = await super.fetchChatMessages(
      chatId,
      cursor: cursor,
      limit: limit,
      cancelToken: cancelToken,
    );
    messagesLoaded = true;
    return page;
  }
}

class _MeetingChatPagedRepository extends _MeetingChatRepository {
  final List<String?> cursors = [];

  @override
  Future<BackendPage<BackendChatMessage>> fetchChatMessages(
    String chatId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    cursors.add(cursor);
    if (cursor == 'older-1') {
      return BackendPage(
        items: [
          BackendChatMessage(
            id: 'older-message',
            chatId: chatId,
            text: 'Самое раннее сообщение',
            senderName: 'Frendly',
            createdAt: DateTime(2026, 5, 19, 11),
            raw: {
              'id': 'older-message',
              'chatId': chatId,
              'text': 'Самое раннее сообщение',
              'senderName': 'Frendly',
              'createdAt': '2026-05-19T11:00:00.000',
            },
          ),
        ],
      );
    }
    return BackendPage(
      nextCursor: 'older-1',
      items: List.generate(
        80,
        (index) => BackendChatMessage(
          id: 'message-$index',
          chatId: chatId,
          text: 'Сообщение $index',
          senderId: index.isEven ? 'u-lia' : 'user-1',
          senderName: index.isEven ? 'Лия' : 'Вы',
          createdAt: DateTime(2026, 5, 19, 12, index),
          raw: {
            'id': 'message-$index',
            'chatId': chatId,
            'text': 'Сообщение $index',
            'senderId': index.isEven ? 'u-lia' : 'user-1',
            'senderName': index.isEven ? 'Лия' : 'Вы',
            'mine': index.isOdd,
            'createdAt': DateTime(2026, 5, 19, 12, index).toIso8601String(),
          },
        ),
      ),
    );
  }
}

class _MeetingDetailRepository extends _AuthFlowRepository {
  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: eventId,
      title: 'Speciality coffee tasting',
      subtitle: 'Brew Lab, Патрики',
      imageUrl: 'https://example.com/coffee.jpg',
      startsAt: DateTime(2026, 5, 19, 19, 30),
      city: 'Москва',
      latitude: 55.764,
      longitude: 37.592,
      raw: const {
        'description': 'Пробуем 3 фильтра и идем гулять',
        'place': 'Brew Lab, Патрики',
        'going': 4,
        'capacity': 6,
        'chatId': 'chat-coffee',
        'ticketUrl': 'https://tickets.example/coffee',
        'ticketPriceFrom': 490,
        'ticketProvider': 'MTS Live',
        'ticketVenue': 'Brew Lab',
        'partnerName': 'Brew Lab',
        'partnerOffer': '-20% по Frendly',
        'bookingUrl': 'https://book.example/brew',
        'routeId': 'route-1',
        'routePointCount': 3,
        'routePoints': [
          {
            'id': 'route-step-1',
            'title': 'Встречаемся у бара',
            'time': '19:30',
            'venue': 'Brew Lab',
            'address': 'Цветной 12',
            'latitude': 55.764,
            'longitude': 37.592,
            'ticketSourceCode': 'tomesto',
            'ticketUrl': 'https://book.example/brew-lab',
            'ticketProvider': 'Tomesto',
          },
          {
            'id': 'route-step-2',
            'title': 'Дегустация 3 фильтров',
            'time': '19:45',
            'venue': 'Roastery',
            'address': 'Петровка 3',
            'latitude': 55.761,
            'longitude': 37.612,
            'ticketSourceCode': 'advcake_ticketland',
            'ticketUrl': 'https://tickets.example/filter',
            'ticketProvider': 'Ticketland',
            'ticketPrice': 1200,
          },
          {
            'id': 'route-step-3',
            'title': 'Прогулка по бульвару',
            'time': '20:30',
            'venue': 'Бульвар',
            'address': 'Трубная площадь',
            'latitude': 55.767,
            'longitude': 37.621,
          },
        ],
        'vibe': 'Coffee',
        'requiresVerification': true,
        'host': {
          'id': 'host-1',
          'displayName': 'Лия',
          'verified': true,
          'rating': 4.9,
          'meetupCount': 12,
          'avatarUrl': 'https://example.com/lia.jpg',
        },
        'attendees': [
          {
            'id': 'user-nina',
            'displayName': 'Нина',
            'avatarUrl': 'https://example.com/nina.jpg',
          },
        ],
        'participantState': 'joined',
      },
    );
  }
}

class _MeetingReportRepository extends _MeetingDetailRepository {
  final reportedEventIds = <String>[];

  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: eventId,
      title: 'Плохая встреча',
      subtitle: 'Неподходящий контент',
      startsAt: DateTime(2026, 5, 19, 19),
      city: 'Москва',
      raw: const {
        'description': 'Описание с плохим контентом',
        'place': 'Бар',
        'going': 1,
        'capacity': 4,
        'host': {
          'id': 'host-1',
          'displayName': 'Организатор',
        },
      },
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchEvents({
    String? city,
    String? filter,
    String? query,
    String? lifestyle,
    String? price,
    String? gender,
    String? access,
    String? sort,
    String? date,
    bool requiresVerification = false,
    bool requiresFrendlyPlus = false,
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: [
        BackendCardItem(
          id: 'report-me',
          title: 'Плохая встреча',
          subtitle: 'Неподходящий контент',
          startsAt: DateTime(2026, 5, 19, 19),
        ),
        BackendCardItem(
          id: 'normal-meeting',
          title: 'Обычная встреча',
          subtitle: 'Coffee',
          startsAt: DateTime(2026, 5, 19, 20),
        ),
      ],
    );
  }

  @override
  Future<Map<String, Object?>> createReport({
    String? targetUserId,
    String? targetEventId,
    String targetType = 'user',
    required String reason,
    String details = '',
    bool blockRequested = false,
    CancelToken? cancelToken,
  }) async {
    if (targetType == 'event' && targetEventId != null) {
      reportedEventIds.add(targetEventId);
    }
    return {
      'id': 'report-1',
      'status': 'open',
      'targetEventId': targetEventId,
      'blockRequested': false,
    };
  }
}

class _MeetingJoinToggleRepository extends _MeetingDetailRepository {
  var joined = false;
  var joinCalls = 0;
  var leaveCalls = 0;

  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return _event();
  }

  @override
  Future<BackendCardItem> joinEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    joinCalls += 1;
    joined = true;
    return _event();
  }

  @override
  Future<BackendCardItem> leaveEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    leaveCalls += 1;
    joined = false;
    return _event();
  }

  BackendCardItem _event() {
    return BackendCardItem(
      id: 'toggle',
      title: 'Toggle coffee',
      subtitle: 'Brew Lab',
      startsAt: DateTime(2026, 5, 20, 20),
      city: 'Москва',
      raw: {
        'description': 'Проверяем вход и выход',
        'place': 'Brew Lab',
        'going': joined ? 2 : 1,
        'capacity': 6,
        'chatId': 'chat-toggle',
        'participantState': joined ? 'joined' : 'left',
        'host': const {
          'id': 'host-1',
          'displayName': 'Лия',
        },
      },
    );
  }
}

class _MeetingClosedJoinToggleRepository extends _MeetingJoinToggleRepository {
  _MeetingClosedJoinToggleRepository() {
    joined = true;
  }

  var joinRequestCalls = 0;

  @override
  Future<BackendCardItem> createJoinRequest(
    String eventId, {
    String? note,
    CancelToken? cancelToken,
  }) async {
    joinRequestCalls += 1;
    return _event();
  }

  @override
  BackendCardItem _event() {
    final event = super._event();
    return BackendCardItem(
      id: event.id,
      title: event.title,
      subtitle: event.subtitle,
      imageUrl: event.imageUrl,
      downloadUrlPath: event.downloadUrlPath,
      startsAt: event.startsAt,
      city: event.city,
      latitude: event.latitude,
      longitude: event.longitude,
      raw: {
        ...event.raw,
        'accessMode': 'request',
        'joinMode': 'request',
      },
    );
  }
}

class _EmptyStoriesRepository extends _AuthFlowRepository {
  @override
  Future<BackendPage<BackendCardItem>> fetchEventStories(
    String eventId, {
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }
}

class _PrivateStoriesRepository extends _AuthFlowRepository {
  @override
  Future<BackendPage<BackendCardItem>> fetchEventStories(
    String eventId, {
    int limit = 20,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return BackendPage(
      items: List.generate(5, (index) {
        final number = index + 1;
        return BackendCardItem.fromJson({
          'id': 'story-$number',
          'caption': 'Story $number',
          'authorName': 'Алекс',
          'media': {
            'url': '/media/story-$number',
            'downloadUrlPath': '/media/story-$number/download-url',
          },
          'createdAt': '2026-05-19T10:00:00.000Z',
        });
      }),
    );
  }
}

class _ShareRepository extends _MeetingDetailRepository {
  final List<Map<String, String>> createdShares = [];

  @override
  Future<Map<String, Object?>> createShare({
    required String targetType,
    required String targetId,
    CancelToken? cancelToken,
  }) async {
    createdShares.add({'targetType': targetType, 'targetId': targetId});
    return {
      'slug': 'abc',
      'url': 'https://frendly.test/abc',
      'targetType': targetType,
      'targetId': targetId,
    };
  }
}

class _MeetingJoinRequestRepository extends _MeetingDetailRepository {
  bool createdJoinRequest = false;

  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return _requestEvent(joinRequestStatus: null);
  }

  @override
  Future<BackendCardItem> createJoinRequest(
    String eventId, {
    String? note,
    CancelToken? cancelToken,
  }) async {
    createdJoinRequest = true;
    return _requestEvent(joinRequestStatus: 'pending');
  }

  BackendCardItem _requestEvent({required String? joinRequestStatus}) {
    return BackendCardItem(
      id: 'requested',
      title: 'Closed dinner',
      subtitle: 'Secret Bar',
      startsAt: DateTime(2026, 5, 20, 20),
      city: 'Москва',
      raw: {
        'description': 'Встреча по заявкам',
        'place': 'Secret Bar',
        'accessMode': 'request',
        'joinMode': 'request',
        'joinRequestStatus': joinRequestStatus,
        'participantState': 'none',
        'entryRequirements': const {
          'canJoin': true,
          'missing': <String>[],
        },
      },
    );
  }
}

class _MeetingHostRepository extends _MeetingDetailRepository {
  final finishedAttendeeIds = <List<String>>[];

  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return _hostEvent(eventId);
  }

  @override
  Future<BackendCardItem> fetchHostedEvent(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return _hostEvent(eventId);
  }

  @override
  Future<Map<String, Object?>> finishHostedEvent(
    String eventId, {
    required List<String> attendedUserIds,
    CancelToken? cancelToken,
  }) async {
    finishedAttendeeIds.add(attendedUserIds);
    return {
      'eventId': eventId,
      'status': 'finished',
      'attendedUserIds': attendedUserIds,
    };
  }

  BackendCardItem _hostEvent(String eventId) {
    return BackendCardItem(
      id: eventId,
      title: 'Speciality coffee tasting',
      subtitle: 'Brew Lab, Патрики',
      imageUrl: 'https://example.com/coffee.jpg',
      startsAt: DateTime(2026, 5, 19, 19, 30),
      city: 'Москва',
      raw: const {
        'description': 'Моя встреча',
        'place': 'Brew Lab, Патрики',
        'going': 1,
        'capacity': 6,
        'participantState': 'none',
        'host': {
          'id': 'user-1',
          'displayName': 'Алекс',
          'avatarUrl': 'https://example.com/alex.jpg',
        },
        'attendees': [
          {
            'userId': 'user-1',
            'displayName': 'Алекс',
            'avatarUrl': 'https://example.com/alex.jpg',
            'attendanceStatus': 'not_checked_in',
          },
          {
            'userId': 'user-nina',
            'displayName': 'Нина',
            'avatarUrl': 'https://example.com/nina.jpg',
            'attendanceStatus': 'not_checked_in',
          },
        ],
      },
    );
  }
}

class _MeetingHostRequestsRepository extends _MeetingHostRepository {
  final approvedRequestIds = <String>[];
  final rejectedRequestIds = <String>[];

  @override
  Future<HostDashboardData> fetchHostDashboard({
    int eventsLimit = 20,
    int requestsLimit = 20,
    CancelToken? cancelToken,
  }) async {
    return const HostDashboardData(
      stats: HostDashboardStats(meetupsCount: 1),
      pendingRequestsCount: 1,
      requests: [
        HostJoinRequestData(
          id: 'request-1',
          eventId: 'own',
          eventTitle: 'Speciality coffee tasting',
          userId: 'user-nina',
          userName: 'Нина',
          verified: true,
          frendlyPlus: true,
        ),
      ],
      raw: {
        'stats': {'meetupsCount': 1},
        'pendingRequestsCount': 1,
        'requests': [
          {
            'id': 'request-1',
            'eventId': 'own',
            'eventTitle': 'Speciality coffee tasting',
            'userId': 'user-nina',
            'userName': 'Нина',
            'verified': true,
            'frendlyPlus': true,
          },
        ],
      },
    );
  }

  @override
  Future<HostJoinRequestData> approveHostRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    approvedRequestIds.add(requestId);
    return const HostJoinRequestData(
      id: 'request-1',
      eventId: 'own',
      eventTitle: 'Speciality coffee tasting',
      userId: 'user-nina',
      userName: 'Нина',
      status: 'approved',
      verified: true,
      frendlyPlus: true,
    );
  }

  @override
  Future<HostJoinRequestData> rejectHostRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    rejectedRequestIds.add(requestId);
    return const HostJoinRequestData(
      id: 'request-1',
      eventId: 'own',
      eventTitle: 'Speciality coffee tasting',
      userId: 'user-nina',
      userName: 'Нина',
      status: 'rejected',
      verified: true,
      frendlyPlus: true,
    );
  }
}

class _MeetingNoChatRepository extends _MeetingDetailRepository {
  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    final meeting = await super.fetchEventDetail(eventId);
    final raw = Map<String, Object?>.of(meeting.raw)..remove('chatId');
    return BackendCardItem(
      id: meeting.id,
      title: meeting.title,
      subtitle: meeting.subtitle,
      imageUrl: meeting.imageUrl,
      startsAt: meeting.startsAt,
      city: meeting.city,
      latitude: meeting.latitude,
      longitude: meeting.longitude,
      raw: raw,
    );
  }
}

class _MeetingRefreshRepository extends _MeetingDetailRepository {
  var loads = 0;

  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    loads += 1;
    return BackendCardItem(
      id: eventId,
      title: 'Coffee refresh',
      subtitle: 'Brew Lab',
      startsAt: DateTime(2026, 5, 20, 20),
      raw: {
        'description': 'Проверяем обновление участников',
        'place': 'Brew Lab',
        'going': loads == 1 ? 1 : 2,
        'capacity': 10,
        'participantState': 'joined',
        'chatId': 'chat-refresh',
        'host': const {
          'id': 'host-1',
          'displayName': 'Лия',
          'verified': true,
        },
        'attendees': const [
          {
            'id': 'user-1',
            'displayName': 'Алекс',
          },
        ],
      },
    );
  }
}

class _CountingChatTransport implements ChatSocketTransport {
  final StreamController<Object?> _controller = StreamController<Object?>();

  @override
  Stream<Object?> get stream => _controller.stream;

  @override
  void send(String data) {}

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

class _MeetingPhotosRepository extends _MeetingDetailRepository {
  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: 'photos',
      title: 'Photo coffee',
      subtitle: 'Brew Lab',
      imageUrl: 'https://example.com/meeting.jpg',
      startsAt: DateTime(2026, 5, 19, 19, 30),
      raw: const {
        'imageVariants': {
          'hero': {'url': 'https://example.com/meeting-hero.webp'},
        },
        'description': 'Проверяем фото',
        'place': 'Brew Lab',
        'host': {
          'id': 'host-1',
          'displayName': 'Лия',
          'profile': {
            'avatarUrl': 'https://example.com/host-profile.jpg',
          },
        },
        'participants': [
          {
            'user': {
              'id': 'guest-1',
              'displayName': 'Нина',
              'profile': {
                'avatarUrl': 'https://example.com/guest-profile.jpg',
              },
            },
          },
        ],
      },
    );
  }
}

class _MeetingLockedRepository extends _MeetingDetailRepository {
  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: 'locked',
      title: 'Verified dinner',
      subtitle: 'Secret Bar',
      startsAt: DateTime(2026, 5, 20, 20),
      city: 'Москва',
      raw: const {
        'description': 'Только для проверенных участников',
        'place': 'Secret Bar',
        'accessMode': 'open',
        'participantState': 'none',
        'requiresVerification': true,
        'requiresFrendlyPlus': true,
        'entryRequirements': {
          'canJoin': false,
          'missing': ['verification', 'frendly_plus'],
        },
      },
    );
  }
}

class _MeetingInviteRepository extends _MeetingDetailRepository {
  final List<String> followingEventIds = [];
  final List<String> invitedUserIds = [];

  @override
  Future<BackendCardItem> fetchEventDetail(
    String eventId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: 'invite',
      title: 'Coffee friends',
      subtitle: 'Brew Lab',
      startsAt: DateTime(2026, 5, 20, 20),
      city: 'Москва',
      raw: const {
        'description': 'Встреча для друзей',
        'place': 'Brew Lab',
        'participantState': 'joined',
      },
    );
  }

  @override
  Future<BackendPage<BackendCardItem>> fetchFollowingPeople({
    required String eventId,
    String? q,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    followingEventIds.add(eventId);
    return const BackendPage(
      items: [
        BackendCardItem(
          id: 'friend-1',
          title: 'Нина',
          subtitle: 'Кофе и прогулки',
          imageUrl: 'https://example.com/nina.jpg',
          raw: {
            'inviteState': 'available',
          },
        ),
      ],
    );
  }

  @override
  Future<Map<String, Object?>> inviteUserToEvent(
    String eventId,
    String userId, {
    CancelToken? cancelToken,
  }) async {
    invitedUserIds.add(userId);
    return const {'inviteState': 'pending_invite'};
  }
}

class _MeetingInviteSearchRepository extends _MeetingInviteRepository {
  final List<String?> queries = [];
  final List<CancelToken> cancelTokens = [];
  final List<Completer<BackendPage<BackendCardItem>>> _requests = [];

  @override
  Future<BackendPage<BackendCardItem>> fetchFollowingPeople({
    required String eventId,
    String? q,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) {
    queries.add(q);
    if (cancelToken != null) {
      cancelTokens.add(cancelToken);
    }
    final completer = Completer<BackendPage<BackendCardItem>>();
    _requests.add(completer);
    return completer.future;
  }

  void completeAll() {
    for (final request in _requests) {
      if (!request.isCompleted) {
        request.complete(const BackendPage(items: []));
      }
    }
  }
}

class _MeetingInvitePagedRepository extends _MeetingInviteRepository {
  final List<String?> cursors = [];

  @override
  Future<BackendPage<BackendCardItem>> fetchFollowingPeople({
    required String eventId,
    String? q,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    cursors.add(cursor);
    if (cursor == 'next-1') {
      return const BackendPage(
        items: [
          BackendCardItem(
            id: 'friend-25',
            title: 'Друг 25',
            raw: {'inviteState': 'available'},
          ),
        ],
      );
    }
    return BackendPage(
      nextCursor: 'next-1',
      items: List.generate(
        25,
        (index) => BackendCardItem(
          id: 'friend-$index',
          title: 'Друг $index',
          raw: const {'inviteState': 'available'},
        ),
      ),
    );
  }
}

class _PublicProfileRepository extends _AuthFlowRepository {
  _PublicProfileRepository({
    this.initialLiked = false,
    this.initialBlocked = false,
  });

  final bool initialLiked;
  final bool initialBlocked;
  final List<String> likeActions = [];
  final List<String> followActions = [];
  final List<String> notificationActions = [];
  final List<String> unblockActions = [];
  int directChatRequests = 0;

  @override
  Future<BackendCardItem> fetchPublicUser(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    return BackendCardItem(
      id: 'user-nina',
      title: 'Нина',
      imageUrl: 'https://example.com/nina.jpg',
      raw: {
        'id': 'user-nina',
        'displayName': 'Нина',
        'verified': true,
        'online': true,
        'age': 26,
        'bio': 'Дизайнер из Москвы',
        'distanceKm': 1.2,
        'meetupCount': 32,
        'rating': 4.9,
        'interests': [
          'Speciality coffee',
          'Винил',
          'Галереи',
        ],
        'photos': [
          {'url': 'https://example.com/nina-1.jpg'},
          {'url': 'https://example.com/nina-2.jpg'},
        ],
        'social': {
          'liked': initialLiked,
          'followers': 32,
          'iFollow': false,
          'followNotifications': false,
        },
        'blockedByMe': initialBlocked,
      },
    );
  }

  @override
  Future<Map<String, Object?>> createDirectChat(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    directChatRequests += 1;
    return const {'id': 'direct-chat-nina'};
  }

  @override
  Future<Map<String, Object?>> setProfileReaction({
    required String userId,
    required String kind,
    required bool active,
    CancelToken? cancelToken,
  }) async {
    if (kind == 'like') {
      likeActions.add('$userId:$active');
    }
    return {'iLike': active};
  }

  @override
  Future<ProfileSocialData> fetchProfileSocial(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    return ProfileSocialData(
      followers: 32,
      likes: 0,
      superLikes: 0,
      iFollow: false,
      iLike: initialLiked,
      iSuper: false,
      followNotifications: false,
      raw: {
        'followers': 32,
        'likes': 0,
        'superLikes': 0,
        'iFollow': false,
        'iLike': initialLiked,
        'iSuper': false,
        'followNotifications': false,
        'blockedByMe': initialBlocked,
      },
    );
  }

  @override
  Future<ProfileSocialData> setProfileFollow({
    required String userId,
    required bool active,
    CancelToken? cancelToken,
  }) async {
    followActions.add('$userId:$active');
    return const ProfileSocialData(
      followers: 33,
      likes: 0,
      superLikes: 0,
      iFollow: true,
      iLike: false,
      iSuper: false,
      followNotifications: true,
      raw: {
        'followers': 33,
        'likes': 0,
        'superLikes': 0,
        'iFollow': true,
        'iLike': false,
        'iSuper': false,
        'followNotifications': true,
      },
    );
  }

  @override
  Future<ProfileSocialData> setProfileFollowNotifications({
    required String userId,
    required bool enabled,
    CancelToken? cancelToken,
  }) async {
    notificationActions.add('$userId:$enabled');
    return ProfileSocialData(
      followers: 33,
      likes: 0,
      superLikes: 0,
      iFollow: true,
      iLike: false,
      iSuper: false,
      followNotifications: enabled,
      raw: {
        'followers': 33,
        'likes': 0,
        'superLikes': 0,
        'iFollow': true,
        'iLike': false,
        'iSuper': false,
        'followNotifications': enabled,
      },
    );
  }

  @override
  Future<void> deleteBlock({
    required String targetUserId,
    CancelToken? cancelToken,
  }) async {
    unblockActions.add(targetUserId);
  }
}

class _SettingsRepository extends _AuthFlowRepository {
  final List<Map<String, Object?>> updatedSettings = [];

  @override
  Future<AppSettingsData> updateSettings(
    Map<String, Object?> data, {
    CancelToken? cancelToken,
  }) async {
    updatedSettings.add(data);
    return AppSettingsData.fromJson({
      'allowPush': true,
      'discoverable': data['discoverable'] ?? true,
      'showAge': data['showAge'] ?? true,
      'darkMode': data['darkMode'] ?? true,
    });
  }

  @override
  Future<BackendPage<BlockedUserData>> fetchBlocks({
    CancelToken? cancelToken,
  }) async {
    return const BackendPage(items: []);
  }
}

class _BlockedUsersRepository extends _AuthFlowRepository {
  final List<String> unblockActions = [];
  final List<BlockedUserData> _blocks = [
    const BlockedUserData(
      id: 'block-1',
      blockedUserId: 'user-nina',
      displayName: 'Нина',
    ),
  ];

  @override
  Future<BackendPage<BlockedUserData>> fetchBlocks({
    CancelToken? cancelToken,
  }) async {
    return BackendPage(items: List<BlockedUserData>.of(_blocks));
  }

  @override
  Future<void> deleteBlock({
    required String targetUserId,
    CancelToken? cancelToken,
  }) async {
    unblockActions.add(targetUserId);
    _blocks.removeWhere((block) => block.blockedUserId == targetUserId);
  }
}

const Map<String, Object?> _onboardingRawWithTwoPhotos = {
  'photos': [
    {
      'id': 'photo-1',
      'url': 'https://cdn.test/onboarding-1.jpg',
      'order': 0,
    },
    {
      'id': 'photo-2',
      'url': 'https://cdn.test/onboarding-2.jpg',
      'order': 1,
    },
  ],
};

const _completeOnboardingDataWithoutPhotos = OnboardingData(
  intent: 'Знакомиться',
  gender: 'male',
  birthDate: '1998-05-21',
  city: 'Москва',
  interests: ['🎵 Музыка', '☕ Кофе', '🍷 Вино'],
  vibe: 'Чилл',
);

const _completeOnboardingData = OnboardingData(
  intent: 'Знакомиться',
  gender: 'male',
  birthDate: '1998-05-21',
  city: 'Москва',
  interests: ['🎵 Музыка', '☕ Кофе', '🍷 Вино'],
  vibe: 'Чилл',
  raw: _onboardingRawWithTwoPhotos,
);

class _RecordingOnboardingRepository extends BackendRepository {
  _RecordingOnboardingRepository({
    this.fetchMeAfterSaveReturnsIncomplete = false,
    this.initialOnboarding = _completeOnboardingData,
    this.occupiedContactField,
    this.saveErrorCode,
  }) : super(Dio());

  final bool fetchMeAfterSaveReturnsIncomplete;
  final OnboardingData initialOnboarding;
  final String? occupiedContactField;
  final String? saveErrorCode;
  final List<String> placeQueries = [];
  OnboardingData? saved;

  @override
  Future<OnboardingData> fetchOnboarding({CancelToken? cancelToken}) async {
    return initialOnboarding;
  }

  @override
  Future<BackendPage<BackendCardItem>> searchPlaces({
    required String query,
    String? city,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    placeQueries.add(query);
    return const BackendPage(
      items: [
        BackendCardItem(
          id: 'place-1',
          title: 'Кофейня на Покровке',
          subtitle: 'Покровка 17',
          city: 'Москва',
          latitude: 55.757,
          longitude: 37.648,
        ),
      ],
    );
  }

  @override
  Future<OnboardingData> saveOnboarding(
    OnboardingData data, {
    CancelToken? cancelToken,
  }) async {
    if (saveErrorCode != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/onboarding/me'),
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(path: '/onboarding/me'),
          statusCode: 400,
          data: {
            'code': saveErrorCode,
            'message': 'Onboarding save failed',
          },
        ),
      );
    }
    saved = data;
    return data;
  }

  @override
  Future<BackendUser> fetchMe({CancelToken? cancelToken}) async {
    return BackendUser(
      id: 'user-1',
      name: 'Алекс',
      onboardingComplete: !fetchMeAfterSaveReturnsIncomplete,
      city: saved?.city,
    );
  }

  @override
  Future<Map<String, Object?>> checkOnboardingContact({
    String? email,
    String? phoneNumber,
    CancelToken? cancelToken,
  }) async {
    if (occupiedContactField != null) {
      throw BackendActionException(
        message: 'Contact is already used',
        code: 'contact_already_used',
        details: {'field': occupiedContactField},
      );
    }
    return const {'available': true};
  }
}

class _FakeOnboardingPermissionService implements OnboardingPermissionService {
  _FakeOnboardingPermissionService({
    this.locationResults = const [],
    this.pushResults = const [],
    this.locationCompleters = const [],
  });

  final List<OnboardingPermissionRequestResult> locationResults;
  final List<OnboardingPermissionRequestResult> pushResults;
  final List<Completer<OnboardingPermissionRequestResult>> locationCompleters;
  int locationRequests = 0;
  int pushRequests = 0;
  int contactsRequests = 0;

  @override
  Future<OnboardingPermissionRequestResult> requestLocation() async {
    final index = locationRequests;
    locationRequests += 1;
    if (index < locationCompleters.length) {
      return locationCompleters[index].future;
    }
    return index < locationResults.length
        ? locationResults[index]
        : OnboardingPermissionRequestResult.denied;
  }

  @override
  Future<OnboardingPermissionRequestResult> requestPush() async {
    final index = pushRequests;
    pushRequests += 1;
    return index < pushResults.length
        ? pushResults[index]
        : OnboardingPermissionRequestResult.denied;
  }

  @override
  Future<OnboardingPermissionRequestResult> requestContacts() async {
    contactsRequests += 1;
    return OnboardingPermissionRequestResult.denied;
  }
}

class _RecordingProfilePhotoUploadRepository extends BackendRepository {
  _RecordingProfilePhotoUploadRepository() : super(Dio());

  int uploadCount = 0;

  @override
  Future<Map<String, Object?>> uploadProfilePhotoFile({
    required String filePath,
    required String fileName,
    required String mimeType,
    CancelToken? cancelToken,
  }) async {
    uploadCount += 1;
    final id = uploadCount == 1 ? 'first' : 'second';
    final url = 'https://cdn.test/$id.jpg';
    return {
      'assetId': 'asset-$id',
      'status': 'ready',
      'url': url,
      'photo': {
        'id': 'photo-$id',
        'url': url,
        'order': uploadCount - 1,
      },
    };
  }
}

class _RecordingProfilePhotoOrderRepository extends BackendRepository {
  _RecordingProfilePhotoOrderRepository() : super(Dio());

  final photoOrders = <List<String>>[];

  @override
  Future<Map<String, Object?>> reorderProfilePhotos(
    List<String> photoIds, {
    CancelToken? cancelToken,
  }) async {
    photoOrders.add(photoIds);
    final urlsById = {
      'photo-first': 'https://cdn.test/first.jpg',
      'photo-second': 'https://cdn.test/second.jpg',
    };
    return {
      'photos': [
        for (final photoId in photoIds)
          {
            'id': photoId,
            'url': urlsById[photoId],
          },
      ],
    };
  }
}

String _formatDateForInput(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatTimeForInput(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
