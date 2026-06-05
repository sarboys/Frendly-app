import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/meetings/presentation/meeting_boost.dart';

void main() {
  test('meeting boost catalog matches front2 tiers', () {
    expect(meetingBoostTiers.map((tier) => tier.optionId), [
      'boost-6',
      'boost-24',
      'boost-72',
    ]);
    expect(meetingBoostTierByOption('boost-6')?.price, 100);
    expect(meetingBoostTierByOption('boost-24')?.price, 300);
    expect(meetingBoostTierByOption('boost-72')?.price, 500);
    expect(meetingBoostTierByOption('boost-6')?.hours, 1);
    expect(meetingBoostTierByOption('boost-24')?.hours, 5);
    expect(meetingBoostTierByOption('boost-72')?.hours, 24);
  });

  test('reads active boost tier from backend event payload', () {
    final tier = meetingBoostTierFromRaw({
      'promoted': true,
      'boost': {
        'optionId': 'boost-72',
      },
    });

    expect(tier?.id, '24h');
    expect(tier?.badge, 'Boost 24ч');
  });
}
