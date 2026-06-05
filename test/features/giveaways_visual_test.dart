import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/features/giveaways/presentation/giveaways_screen.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';

void main() {
  testWidgets('giveaways screen matches the front2 Drops structure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dropsHomeProvider.overrideWith((ref) async => _fakeDropsHome()),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const GiveawaysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Frendly Drops'), findsOneWidget);
    expect(find.text('Подарки для активных пользователей'), findsOneWidget);
    expect(find.text('3 × iPhone 16 Pro'), findsOneWidget);
    expect(find.text('Активные дропы'), findsOneWidget);
    expect(find.text('Задания месяца'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('История билетов'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('История билетов'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Победители прошлого Drop'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Победители прошлого Drop'), findsOneWidget);
    expect(find.text('Анна, Москва'), findsOneWidget);
  });

  testWidgets('giveaways ticket button opens the tasks sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dropsHomeProvider.overrideWith((ref) async => _fakeDropsHome()),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const GiveawaysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Получить билеты').first);
    await tester.pumpAndSettle();

    expect(find.text('Как получить больше билетов'), findsOneWidget);
    expect(
        find.text(
            'Билеты нельзя купить. Их получают за реальную активность в Frendly.'),
        findsOneWidget);
    expect(find.text('Понятно'), findsOneWidget);
  });

  testWidgets('giveaways screen hides non MVP tasks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dropsHomeProvider.overrideWith((ref) async => _fakeDropsHome()),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const GiveawaysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Купить билет через афишу'), findsNothing);
    expect(find.text('Забронировать столик на встрече'), findsNothing);
    expect(find.text('Получить рейтинг 4.5+'), findsNothing);
    expect(find.text('Репост в Telegram / VK'), findsNothing);
  });

  testWidgets('giveaways conditions link opens detailed monthly task rules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dropsHomeProvider.overrideWith((ref) async => _fakeDropsHome()),
        ],
        child: MaterialApp(
          theme: DateasyTheme.theme,
          home: const GiveawaysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Условия'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Условия'));
    await tester.pumpAndSettle();

    expect(find.text('Назад'), findsOneWidget);
    expect(find.text('Условия заданий'), findsOneWidget);
    expect(find.text('Пройти верификацию'), findsOneWidget);
    expect(find.text('Ежедневный вход'), findsOneWidget);
    expect(find.text('Провести встречу'), findsOneWidget);
    expect(find.text('Посетить встречу'), findsOneWidget);
    expect(find.text('Пригласить друга'), findsOneWidget);
    expect(find.text('Оформить Frendly+'), findsOneWidget);
    expect(find.text('Продвинуть встречу'), findsOneWidget);
    expect(find.textContaining('30 билетов'), findsWidgets);
    expect(find.textContaining('по Москве'), findsOneWidget);
    expect(find.textContaining('6 часов'), findsOneWidget);
    expect(find.textContaining('3 гостя'), findsOneWidget);
    expect(find.textContaining('2 гостя'), findsOneWidget);
  });

  testWidgets('giveaways screen links to official promo rules', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/giveaways',
      routes: [
        GoRoute(
          path: '/giveaways',
          builder: (_, __) => const GiveawaysScreen(),
        ),
        GoRoute(
          path: '/settings/documents/promo-rules',
          builder: (_, __) => const Scaffold(body: Text('rules-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dropsHomeProvider.overrideWith((ref) async => _fakeDropsHome()),
        ],
        child: MaterialApp.router(
          theme: DateasyTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Официальные правила'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Официальные правила'));
    await tester.pumpAndSettle();

    expect(find.text('rules-opened'), findsOneWidget);
  });
}

DropsHomeData _fakeDropsHome() {
  final mainDrop = DropData(
    id: 'june-iphone',
    type: 'main_monthly',
    status: 'active',
    title: '3 × iPhone 16 Pro',
    description: '256 GB · цвет на выбор победителя',
    prizeSummary: '3 победителя',
    drawAt: DateTime.utc(2026, 6, 30, 17),
    drawDate: '30 июня',
    daysLeft: 12,
    participantCount: 8420,
    myTickets: 7,
    maxTicketsPerUser: 30,
    requiresVerified: true,
    eligibility: const DropEligibilityData(canParticipate: true),
  );
  final plusDrop = DropData(
    id: 'plus-drop',
    type: 'frendly_plus',
    status: 'active',
    title: '10 × Frendly+ на 3 месяца',
    description: 'Только для подписчиков',
    prizeSummary: '10 победителей',
    drawAt: DateTime.utc(2026, 6, 27, 17),
    drawDate: '27 июня',
    daysLeft: 9,
    participantCount: 942,
    myTickets: 0,
    maxTicketsPerUser: 10,
    requiresVerified: true,
    requiresFrendlyPlus: true,
    eligibility: const DropEligibilityData(
      canParticipate: false,
      missing: ['frendly_plus'],
    ),
  );
  return DropsHomeData(
    mainDrop: mainDrop,
    drops: [mainDrop, plusDrop],
    ticketProgress: DropTicketProgressData(
      monthKey: '2026-06',
      earned: 9,
      reserved: 9,
      availableTickets: 0,
      max: 30,
      nextResetAt: DateTime.utc(2026, 7, 1),
    ),
    tasks: const [
      DropTaskData(
        id: 'verify',
        source: 'verification',
        title: 'Пройти верификацию',
        description: 'Разово после подтверждения профиля',
        conditionDetails: [
          '+3 билета начисляются один раз после подтверждения профиля.',
          'Повторная верификация не дает новые билеты.',
        ],
        rewardTickets: 3,
        progress: 3,
        status: 'completed',
        cta: DropTaskCtaData(label: 'Готово', route: '/verify'),
      ),
      DropTaskData(
        id: 'daily',
        source: 'daily_login',
        title: 'Ежедневный вход',
        description: 'Один раз в день',
        conditionDetails: [
          '+1 билет начисляется за вход в приложение один раз в день.',
          'День считается по Москве, максимум 7 билетов в месяц.',
        ],
        rewardTickets: 1,
        monthlyLimit: 7,
        progress: 2,
        status: 'available',
        cta: DropTaskCtaData(label: '+1 сегодня', action: 'claim_daily_login'),
      ),
      DropTaskData(
        id: 'host',
        source: 'host_meeting',
        title: 'Провести встречу',
        description: 'После подтверждения участников',
        conditionDetails: [
          '+1 билет начисляется организатору после завершения встречи.',
          'Встреча должна быть создана минимум за 6 часов до старта.',
          'Нужно минимум 3 гостя и минимум 2 гостя с подтвержденным присутствием.',
        ],
        rewardTickets: 1,
        monthlyLimit: 5,
        status: 'available',
        cta: DropTaskCtaData(label: 'Создать', route: '/meetings/new'),
      ),
      DropTaskData(
        id: 'attend',
        source: 'visit_meeting',
        title: 'Посетить встречу',
        description: 'После подтверждения присутствия',
        conditionDetails: [
          '+2 билета начисляются гостю после встречи.',
          'Нужно вступить во встречу до старта и реально прийти.',
          'Организатор должен отметить присутствие, максимум 10 билетов в месяц.',
        ],
        rewardTickets: 2,
        monthlyLimit: 10,
        status: 'available',
        cta: DropTaskCtaData(label: 'К встречам', route: '/meetings'),
      ),
      DropTaskData(
        id: 'referral',
        source: 'referral',
        title: 'Пригласить друга',
        description: 'После верификации друга',
        conditionDetails: [
          '+3 билета начисляются, когда друг пришел по твоей ссылке или коду.',
          'Билеты появляются после того, как приглашенный друг пройдет верификацию.',
        ],
        rewardTickets: 3,
        status: 'available',
        cta: DropTaskCtaData(
          label: 'Позвать',
          route: '/share',
          action: 'create_referral_link',
        ),
      ),
      DropTaskData(
        id: 'plus',
        source: 'subscription',
        title: 'Оформить Frendly+',
        description: 'После подтверждения оплаты',
        conditionDetails: [
          '+5 билетов начисляются после подтвержденной оплаты Frendly+.',
          'Подписка за токены тоже считается, если активация прошла успешно.',
        ],
        rewardTickets: 5,
        status: 'available',
        cta: DropTaskCtaData(label: 'Подписка', route: '/paywall'),
      ),
      DropTaskData(
        id: 'boost',
        source: 'boost',
        title: 'Продвинуть встречу',
        description: 'После активации продвижения',
        conditionDetails: [
          '+1 билет начисляется после активации продвижения встречи.',
          'Максимум 5 билетов за продвижение в месяц.',
        ],
        rewardTickets: 1,
        monthlyLimit: 5,
        status: 'available',
        cta: DropTaskCtaData(label: 'Услуга', route: '/meetings'),
      ),
    ],
    history: [
      DropHistoryData(
        id: 'history-1',
        source: 'verification',
        status: 'active',
        title: 'Верификация профиля',
        ticketCount: 3,
        createdAt: DateTime.utc(2026, 6, 1),
      ),
    ],
    pastWinners: const [
      DropWinnerData(
        id: 'winner-1',
        name: 'Анна',
        city: 'Москва',
        prize: 'iPhone 15',
        ticket: 'A8F92',
      ),
    ],
    eligibility: const DropUserEligibilityData(
      canParticipate: true,
      verified: true,
    ),
  );
}
