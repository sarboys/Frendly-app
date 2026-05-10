import 'package:big_break_mobile/features/create_meetup/presentation/create_meetup_draft.dart';
import 'package:big_break_mobile/features/create_meetup/presentation/publish_meetup_screen.dart';
import 'package:big_break_mobile/features/tokens/application/token_wallet_controller.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/widgets/bb_v5_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('publish screen initial draft wins over stale provider draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          createMeetupDraftProvider.overrideWith((ref) => _staleDraft),
          tokenWalletProvider
              .overrideWith((ref) => _TestTokenWalletController()),
        ],
        child: MaterialApp(
          home: PublishMeetupScreen(initialDraft: _draft),
        ),
      ),
    );

    expect(find.text('Вечерний квест и бар в центре Москвы'), findsOneWidget);
    expect(find.text('Старый черновик'), findsNothing);
  });

  testWidgets('publish bottom bar keeps the fade close to the CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          createMeetupDraftProvider.overrideWith((ref) => _draft),
          tokenWalletProvider
              .overrideWith((ref) => _TestTokenWalletController()),
        ],
        child: const MaterialApp(
          home: PublishMeetupScreen(),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(BbV5FixedBottomBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;

    expect(gradient.stops![1], greaterThanOrEqualTo(0.68));
  });

  testWidgets('publish CTA stays compact without extra footer blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          createMeetupDraftProvider.overrideWith((ref) => _draft),
          tokenWalletProvider
              .overrideWith((ref) => _TestTokenWalletController()),
        ],
        child: const MaterialApp(
          home: PublishMeetupScreen(),
        ),
      ),
    );

    final page = tester.widget<BbV5Page>(find.byType(BbV5Page));
    final padding = page.padding as EdgeInsets;

    expect(padding.bottom, lessThanOrEqualTo(96));
    expect(
      find.text('Чат откроется автоматически, как только кто-то присоединится'),
      findsNothing,
    );
  });
}

final _draft = CreateMeetupDraft(
  title: 'Вечерний квест и бар в центре Москвы',
  description: 'Маршрут по центру',
  emoji: '🗺️',
  vibe: 'Спокойно',
  place: 'Маршрут: Вечерний квест и бар в центре Москвы',
  startsAt: DateTime(2026, 5, 10, 18, 55),
  capacity: 8,
  mode: 'default',
  lifestyle: 'neutral',
  priceMode: 'free',
  accessMode: 'open',
  genderMode: 'all',
  visibilityMode: 'public',
  joinMode: EventJoinMode.open,
  idempotencyKey: 'publish-test',
  routeId: 'route-evening',
  attachmentTitle: 'Маршрут · Вечерний квест и бар в центре Москвы',
  attachmentSubtitle: '2 часа',
  attachmentIcon: LucideIcons.route,
);

final _staleDraft = CreateMeetupDraft(
  title: 'Старый черновик',
  description: 'Не должен попасть на экран маршрута',
  emoji: '☕',
  vibe: 'Спокойно',
  place: 'Старое место',
  startsAt: DateTime(2026, 5, 10, 19),
  capacity: 4,
  mode: 'default',
  lifestyle: 'neutral',
  priceMode: 'free',
  accessMode: 'open',
  genderMode: 'all',
  visibilityMode: 'public',
  joinMode: EventJoinMode.open,
  idempotencyKey: 'stale-draft',
);

class _TestTokenWalletController extends TokenWalletController {
  _TestTokenWalletController() : super(null) {
    state = const TokenWalletState(
      balance: 20,
      promoted: {},
      history: [],
    );
  }
}
