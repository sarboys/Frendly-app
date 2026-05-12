import 'package:big_break_mobile/features/communities/presentation/community_providers.dart';
import 'package:big_break_mobile/features/dating/presentation/dating_providers.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/backend_repository.dart';
import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:big_break_mobile/shared/models/create_event_route.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/event_detail.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

final createMeetupDraftProvider = StateProvider<CreateMeetupDraft?>((ref) {
  return null;
});

class CreateMeetupDraft {
  const CreateMeetupDraft({
    required this.title,
    required this.description,
    required this.emoji,
    required this.vibe,
    required this.place,
    required this.startsAt,
    required this.capacity,
    required this.mode,
    required this.lifestyle,
    required this.priceMode,
    required this.accessMode,
    required this.genderMode,
    required this.visibilityMode,
    required this.joinMode,
    required this.idempotencyKey,
    this.priceAmountFrom,
    this.priceAmountTo,
    this.inviteeUserId,
    this.afficheEventId,
    this.routeId,
    this.route,
    this.communityId,
    this.dressCode,
    this.ageRange,
    this.ratioLabel,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.consentRequired = false,
    this.rules,
    this.attachmentTitle,
    this.attachmentSubtitle,
    this.attachmentIcon = LucideIcons.ticket,
  });

  final String title;
  final String description;
  final String emoji;
  final String vibe;
  final String place;
  final DateTime startsAt;
  final int capacity;
  final String mode;
  final String lifestyle;
  final String priceMode;
  final int? priceAmountFrom;
  final int? priceAmountTo;
  final String accessMode;
  final String genderMode;
  final String visibilityMode;
  final EventJoinMode joinMode;
  final String? inviteeUserId;
  final String? afficheEventId;
  final String? routeId;
  final CreateEventRoutePayload? route;
  final String? communityId;
  final String? dressCode;
  final String? ageRange;
  final String? ratioLabel;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final bool consentRequired;
  final List<String>? rules;
  final String idempotencyKey;
  final String? attachmentTitle;
  final String? attachmentSubtitle;
  final IconData attachmentIcon;

  String get submitDescription {
    final cleanDescription = description.trim();
    if (cleanDescription.isNotEmpty) {
      return cleanDescription;
    }

    final cleanPlace = place.trim();
    if (cleanPlace.isNotEmpty) {
      return 'Встречаемся: $cleanPlace';
    }

    final cleanTitle = title.trim();
    return cleanTitle.isEmpty ? 'Встреча в Frendly' : cleanTitle;
  }

  String get timeLabel {
    final now = DateTime.now();
    final local = startsAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    if (target == today) {
      return 'Сегодня · $hour:$minute';
    }
    if (target == today.add(const Duration(days: 1))) {
      return 'Завтра · $hour:$minute';
    }
    return '${local.day}.${local.month} · $hour:$minute';
  }

  String get capacityLabel => 'до $capacity человек';

  String get priceLabel {
    return switch (priceMode) {
      'free' => 'бесплатно',
      'split' => 'скидываемся',
      'fixed' => priceAmountFrom == null ? 'платно' : '${priceAmountFrom!} ₽',
      'range' => priceAmountFrom == null && priceAmountTo == null
          ? 'платно'
          : '${priceAmountFrom ?? 0}-${priceAmountTo ?? 0} ₽',
      _ => priceMode,
    };
  }

  CreateMeetupDraft copyWith({
    String? visibilityMode,
    EventJoinMode? joinMode,
  }) {
    return CreateMeetupDraft(
      title: title,
      description: description,
      emoji: emoji,
      vibe: vibe,
      place: place,
      startsAt: startsAt,
      capacity: capacity,
      mode: mode,
      lifestyle: lifestyle,
      priceMode: priceMode,
      priceAmountFrom: priceAmountFrom,
      priceAmountTo: priceAmountTo,
      accessMode: accessMode,
      genderMode: genderMode,
      visibilityMode: visibilityMode ?? this.visibilityMode,
      joinMode: joinMode ?? this.joinMode,
      inviteeUserId: inviteeUserId,
      afficheEventId: afficheEventId,
      routeId: routeId,
      route: route,
      communityId: communityId,
      dressCode: dressCode,
      ageRange: ageRange,
      ratioLabel: ratioLabel,
      distanceKm: distanceKm,
      latitude: latitude,
      longitude: longitude,
      consentRequired: consentRequired,
      rules: rules,
      idempotencyKey: idempotencyKey,
      attachmentTitle: attachmentTitle,
      attachmentSubtitle: attachmentSubtitle,
      attachmentIcon: attachmentIcon,
    );
  }
}

Future<EventDetail> submitCreateMeetupDraft(
  WidgetRef ref,
  CreateMeetupDraft draft,
) async {
  final repository = ref.read(backendRepositoryProvider);
  final coordinates = await _resolveCreateMeetupCoordinates(ref, draft);
  final event = await repository.createEvent(
    title: draft.title,
    description: draft.submitDescription,
    emoji: draft.emoji,
    vibe: draft.vibe,
    place: draft.place,
    startsAt: draft.startsAt,
    capacity: draft.capacity,
    distanceKm: draft.distanceKm,
    latitude: coordinates?.latitude,
    longitude: coordinates?.longitude,
    mode: draft.mode,
    lifestyle: draft.lifestyle,
    priceMode: draft.priceMode,
    priceAmountFrom: draft.priceAmountFrom,
    priceAmountTo: draft.priceAmountTo,
    accessMode: draft.accessMode,
    genderMode: draft.genderMode,
    visibilityMode: draft.visibilityMode,
    joinMode: draft.joinMode,
    inviteeUserId: draft.inviteeUserId,
    afficheEventId: draft.afficheEventId,
    routeId: draft.routeId,
    route: draft.route,
    communityId: draft.communityId,
    dressCode: draft.dressCode,
    ageRange: draft.ageRange,
    ratioLabel: draft.ratioLabel,
    consentRequired: draft.consentRequired,
    rules: draft.rules,
    idempotencyKey: draft.idempotencyKey,
  );

  ref.invalidate(eventsProvider('nearby'));
  ref.invalidate(mapEventsProvider);
  ref.invalidate(datingDiscoverProvider);
  ref.invalidate(datingLikesProvider);
  ref.invalidate(meetupChatsProvider);
  ref.invalidate(hostDashboardProvider);
  if (draft.communityId case final communityId?) {
    ref.invalidate(communityProvider(communityId));
    ref.invalidate(communitiesFeedProvider);
    ref.invalidate(communitiesProvider);
  }

  return event;
}

typedef MeetupCoordinates = ({double latitude, double longitude});

@visibleForTesting
MeetupCoordinates? createMeetupPublishCoordinatesForTest(
  CreateMeetupDraft draft,
  ManualLocation? manualLocation,
) {
  return _createMeetupPublishCoordinates(draft, manualLocation);
}

Future<MeetupCoordinates?> _resolveCreateMeetupCoordinates(
  WidgetRef ref,
  CreateMeetupDraft draft,
) async {
  return _createMeetupPublishCoordinates(
    draft,
    ref.read(manualLocationProvider),
  );
}

MeetupCoordinates? _createMeetupPublishCoordinates(
  CreateMeetupDraft draft,
  ManualLocation? manualLocation,
) {
  return _validCoordinates(draft.latitude, draft.longitude) ??
      _validCoordinates(manualLocation?.latitude, manualLocation?.longitude);
}

MeetupCoordinates? _validCoordinates(double? latitude, double? longitude) {
  if (latitude == null ||
      longitude == null ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }

  return (latitude: latitude, longitude: longitude);
}
