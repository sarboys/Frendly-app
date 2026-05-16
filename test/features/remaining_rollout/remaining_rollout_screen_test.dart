import 'package:big_break_mobile/features/match/presentation/match_screen.dart';
import 'package:big_break_mobile/features/paywall/presentation/paywall_screen.dart';
import 'package:big_break_mobile/features/phone_auth/presentation/phone_auth_screen.dart';
import 'package:big_break_mobile/features/report/presentation/report_screen.dart';
import 'package:big_break_mobile/features/safety/presentation/safety_hub_screen.dart';
import 'package:big_break_mobile/features/share_card/presentation/share_card_screen.dart';
import 'package:big_break_mobile/features/stories/presentation/stories_screen.dart';
import 'package:big_break_mobile/features/verification/presentation/verification_screen.dart';
import 'package:big_break_mobile/features/welcome/presentation/welcome_screen.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/models/public_share.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_overrides.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      ...overrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('welcome screen renders start CTA', (tester) async {
    await tester.pumpWidget(_wrap(const WelcomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Начать'), findsOneWidget);
  });

  testWidgets('phone auth screen renders code CTA', (tester) async {
    await tester.pumpWidget(_wrap(const PhoneAuthScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Получить код'), findsOneWidget);
  });

  testWidgets('verification screen renders upload CTA', (tester) async {
    await tester.pumpWidget(_wrap(const VerificationScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Документ'), findsAtLeastNWidgets(1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Что будет с документом'), findsOneWidget);
  });

  testWidgets('safety hub renders title', (tester) async {
    await tester.pumpWidget(_wrap(const SafetyHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Безопасность'), findsOneWidget);
    expect(find.textContaining('SOS'), findsWidgets);
  });

  testWidgets('report screen renders submit CTA', (tester) async {
    await tester.pumpWidget(_wrap(const ReportScreen(userId: 'user-anya')));
    await tester.pumpAndSettle();

    expect(find.text('Отправить жалобу'), findsOneWidget);
    expect(find.textContaining('Жалоба на Аня К'), findsOneWidget);
    expect(find.text('Фейковый профиль'), findsOneWidget);
  });

  testWidgets('stories screen renders story caption', (tester) async {
    await tester.pumpWidget(_wrap(const StoriesScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    expect(find.text('Лучший столик у окна 🌆'), findsOneWidget);
    expect(find.textContaining('Винный вечер на крыше'), findsOneWidget);
  });

  testWidgets('share card renders link', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ShareCardScreen(eventId: 'e1'),
        overrides: [
          backendRepositoryProvider.overrideWith(
            (ref) => _FakeShareRepository(ref),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('frendly.app/e/e1'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
  });

  testWidgets('match screen renders score', (tester) async {
    await tester.pumpWidget(_wrap(const MatchScreen(userId: 'user-anya')));
    await tester.pumpAndSettle();

    expect(find.textContaining('87%'), findsOneWidget);
    expect(find.textContaining('совпадение'), findsOneWidget);
    expect(find.textContaining('Написать'), findsOneWidget);
    expect(find.text('Пригласить на встречу'), findsOneWidget);
    expect(find.text('Кофе'), findsOneWidget);
    expect(find.text('Зачем здесь'), findsNothing);
    expect(find.text('Активность'), findsNothing);
  });

  testWidgets('paywall screen renders subscription CTA', (tester) async {
    await tester.pumpWidget(_wrap(const PaywallScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Frendly+'), findsOneWidget);
    expect(find.text('Восстановить'), findsOneWidget);
    expect(find.text('Доступ к Dating'), findsOneWidget);
    expect(find.text('Кто смотрел профиль'), findsOneWidget);
    expect(find.textContaining('Расширенные фильтры'), findsOneWidget);
  });
}

class _FakeShareRepository extends BackendRepository {
  _FakeShareRepository(Ref ref) : super(ref: ref, dio: Dio());

  @override
  Future<PublicShareLink> createPublicShare({
    required String targetType,
    required String targetId,
  }) async {
    return PublicShareLink(
      slug: '$targetType/$targetId',
      targetType: targetType,
      targetId: targetId,
      appPath: '/$targetType/$targetId',
      url: 'https://frendly.app/e/$targetId',
      deepLink: 'bigbreak://$targetType/$targetId',
    );
  }
}
