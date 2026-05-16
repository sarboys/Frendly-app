import 'package:big_break_mobile/features/streak/presentation/streak_screen.dart';
import 'package:big_break_mobile/shared/data/frendly_season_provider.dart';
import 'package:big_break_mobile/shared/models/frendly_season.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('streak screen keeps header and bottom CTA tight',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frendlySeasonProvider.overrideWith(
            (ref) async => const FrendlySeasonData(
              seasonKey: '2026-05',
              seasonLabel: 'Май · сезон',
              checkedInCount: 3,
              calendarDays: [3, 10, 15],
              currentStatus: FrendlySeasonStatusData(
                key: 'checkin-1',
                title: 'Искра',
                threshold: 1,
              ),
              nextReward: FrendlySeasonRewardData(
                key: 'checkin-5',
                threshold: 5,
                statusTitle: 'Свой круг',
                title: 'Свой круг',
                description: '150 токенов',
                rewardKind: FrendlySeasonRewardKind.tokens,
                rewardAmount: 150,
                unlocked: false,
                claimed: false,
                claimedAt: null,
              ),
              stats: FrendlySeasonStatsData(
                checkIns: 3,
                places: 2,
                people: 4,
              ),
              rewards: [],
            ),
          ),
        ],
        child: const MaterialApp(home: StreakScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    final titleTop = tester.getTopLeft(find.text('Геймификация')).dy;
    expect(titleTop, greaterThanOrEqualTo(0));
    expect(titleTop, lessThan(120));

    final buttonBottom =
        tester.getBottomLeft(find.text('Посмотреть промо заведений')).dy;
    final bottomGap = 844 - buttonBottom;
    expect(bottomGap, lessThanOrEqualTo(48));
  });
}
