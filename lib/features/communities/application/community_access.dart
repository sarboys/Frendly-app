import 'package:mobile2/shared/models/backend_models.dart';

bool canManageCommunityRaw(Map<String, Object?> raw) {
  final role = raw['role']?.toString().trim().toLowerCase();
  return raw['isOwner'] == true ||
      raw['owned'] == true ||
      role == 'owner' ||
      role == 'host' ||
      role == 'moderator';
}

bool communityHasFrendlyPlusAccess(SubscriptionStateData? subscription) {
  final status = subscription?.status.trim().toLowerCase();
  return status == 'active' || status == 'trial';
}
