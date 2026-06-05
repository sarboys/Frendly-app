import 'package:mobile2/shared/models/backend_models.dart';

bool meetingViewerHasJoined(BackendCardItem meeting) {
  final raw = meeting.raw;
  final joined = raw['joined'] ?? raw['isJoined'];
  if (joined is bool) {
    return joined;
  }
  final value = raw['participantState'] ??
      raw['viewerState'] ??
      raw['participationState'] ??
      raw['attendanceState'] ??
      raw['rsvpState'];
  final text = value?.toString().toLowerCase();
  return text == 'joined' ||
      text == 'going' ||
      text == 'approved' ||
      text == 'participant' ||
      text == 'host';
}

BackendCardItem meetingWithActionResponse(
  BackendCardItem original,
  BackendCardItem response,
) {
  if (response.id == original.id) {
    return response;
  }
  final responseEventId = response.raw['eventId']?.toString().trim();
  if (responseEventId != original.id) {
    return response;
  }
  final status = response.raw['status']?.toString().trim().toLowerCase();
  final nextStatus =
      status == null || status.isEmpty || status == 'canceled' ? null : status;
  final raw = <String, Object?>{
    ...original.raw,
    'joinRequestStatus': nextStatus,
    'requestStatus': nextStatus,
  };
  if (response.raw['id'] != null) {
    raw['joinRequestId'] = response.raw['id'];
  }
  return BackendCardItem(
    id: original.id,
    title: original.title,
    subtitle: original.subtitle,
    imageUrl: original.imageUrl,
    downloadUrlPath: original.downloadUrlPath,
    startsAt: original.startsAt,
    city: original.city,
    latitude: original.latitude,
    longitude: original.longitude,
    raw: raw,
  );
}
