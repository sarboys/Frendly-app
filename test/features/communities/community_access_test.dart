import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/communities/application/community_access.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('detects community owner and moderator access from backend raw fields',
      () {
    expect(canManageCommunityRaw({'isOwner': true}), true);
    expect(canManageCommunityRaw({'owned': true}), true);
    expect(canManageCommunityRaw({'role': 'owner'}), true);
    expect(canManageCommunityRaw({'role': 'host'}), true);
    expect(canManageCommunityRaw({'role': 'moderator'}), true);
    expect(canManageCommunityRaw({'role': 'member'}), false);
    expect(canManageCommunityRaw({}), false);
  });

  test('detects Frendly Plus access for community creation', () {
    expect(
      communityHasFrendlyPlusAccess(
        const SubscriptionStateData(status: 'active'),
      ),
      true,
    );
    expect(
      communityHasFrendlyPlusAccess(
        const SubscriptionStateData(status: 'trial'),
      ),
      true,
    );
    expect(
      communityHasFrendlyPlusAccess(
        const SubscriptionStateData(status: 'inactive'),
      ),
      false,
    );
    expect(
      communityHasFrendlyPlusAccess(
        const SubscriptionStateData(status: ''),
      ),
      false,
    );
    expect(communityHasFrendlyPlusAccess(null), false);
  });
}
