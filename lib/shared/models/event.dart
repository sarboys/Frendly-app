import 'package:big_break_mobile/shared/models/backend_url.dart';

enum EventTone { warm, evening, sage }

enum EventJoinMode { open, request }

enum EventJoinRequestStatus { pending, approved, rejected, canceled }

enum EventAttendanceStatus { notCheckedIn, checkedIn, left }

enum EventLiveStatus { idle, live, finished }

enum EventTicketSourceKind { affiche }

class EventBookingPromo {
  const EventBookingPromo({
    required this.title,
    this.description,
    this.validUntil,
    this.bookingUrl,
    this.sourceUrl,
  });

  final String title;
  final String? description;
  final String? validUntil;
  final String? bookingUrl;
  final String? sourceUrl;

  factory EventBookingPromo.fromJson(Map<String, dynamic> json) {
    return EventBookingPromo(
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      validUntil: json['validUntil'] as String?,
      bookingUrl: json['bookingUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }
}

class EventRoutePoint {
  const EventRoutePoint({
    required this.id,
    required this.title,
    required this.emoji,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String title;
  final String emoji;
  final double latitude;
  final double longitude;

  static EventRoutePoint? fromJson(Map<String, dynamic> json) {
    final rawLatitude = json['latitude'] ?? json['lat'];
    final rawLongitude = json['longitude'] ?? json['lng'];
    if (rawLatitude is! num || rawLongitude is! num) {
      return null;
    }
    return EventRoutePoint(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📍',
      latitude: rawLatitude.toDouble(),
      longitude: rawLongitude.toDouble(),
    );
  }
}

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.emoji,
    required this.time,
    this.startsAtIso,
    this.imageUrl,
    required this.place,
    required this.distance,
    required this.attendees,
    required this.going,
    required this.capacity,
    required this.vibe,
    required this.tone,
    this.lifestyle,
    this.priceMode,
    this.priceAmountFrom,
    this.priceAmountTo,
    this.accessMode,
    this.genderMode,
    this.visibilityMode,
    this.requiresVerification = false,
    this.requiresFrendlyPlus = false,
    this.routeId,
    this.routePointCount,
    this.routePoints = const [],
    this.isAfficheBacked = false,
    this.isDate = false,
    this.hostNote,
    this.latitude,
    this.longitude,
    required this.joined,
    this.joinMode = EventJoinMode.open,
    this.joinRequestStatus,
    this.attendanceStatus = EventAttendanceStatus.notCheckedIn,
    this.liveStatus = EventLiveStatus.idle,
    this.isHost = false,
    this.ticketUrl,
    this.ticketSourceKind,
    this.ticketSourceId,
    this.ticketPriceFrom,
    this.ticketProvider,
    this.ticketVenue,
    this.bookingUrl,
    this.bookingProvider,
    this.bookingPlaceId,
    this.bookingAverageCheck,
    this.bookingCurrency,
    this.bookingPromos = const [],
  });

  final String id;
  final String title;
  final String emoji;
  final String time;
  final String? startsAtIso;
  final String? imageUrl;
  final String place;
  final String distance;
  final List<String> attendees;
  final int going;
  final int capacity;
  final String vibe;
  final EventTone tone;
  final String? lifestyle;
  final String? priceMode;
  final int? priceAmountFrom;
  final int? priceAmountTo;
  final String? accessMode;
  final String? genderMode;
  final String? visibilityMode;
  final bool requiresVerification;
  final bool requiresFrendlyPlus;
  final String? routeId;
  final int? routePointCount;
  final List<EventRoutePoint> routePoints;
  final bool isAfficheBacked;
  final bool isDate;
  final String? hostNote;
  final double? latitude;
  final double? longitude;
  final bool joined;
  final EventJoinMode joinMode;
  final EventJoinRequestStatus? joinRequestStatus;
  final EventAttendanceStatus attendanceStatus;
  final EventLiveStatus liveStatus;
  final bool isHost;
  final String? ticketUrl;
  final EventTicketSourceKind? ticketSourceKind;
  final String? ticketSourceId;
  final int? ticketPriceFrom;
  final String? ticketProvider;
  final String? ticketVenue;
  final String? bookingUrl;
  final String? bookingProvider;
  final String? bookingPlaceId;
  final int? bookingAverageCheck;
  final String? bookingCurrency;
  final List<EventBookingPromo> bookingPromos;

  bool get hasPaidTicket =>
      (ticketUrl ?? '').trim().isNotEmpty &&
      ticketPriceFrom != null &&
      ticketPriceFrom! > 0;

  bool get hasTableBooking => (bookingUrl ?? '').trim().isNotEmpty;

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      emoji: json['emoji'] as String,
      time: json['time'] as String,
      startsAtIso: json['startsAtIso'] as String?,
      imageUrl: resolveBackendUrl(json['imageUrl'] as String?),
      place: json['place'] as String,
      distance: json['distance'] as String,
      attendees: ((json['attendees'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      going: (json['going'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      vibe: json['vibe'] as String,
      tone: parseTone(json['tone'] as String?),
      lifestyle: json['lifestyle'] as String?,
      priceMode: json['priceMode'] as String?,
      priceAmountFrom: (json['priceAmountFrom'] as num?)?.toInt(),
      priceAmountTo: (json['priceAmountTo'] as num?)?.toInt(),
      accessMode: json['accessMode'] as String?,
      genderMode: json['genderMode'] as String?,
      visibilityMode: json['visibilityMode'] as String?,
      requiresVerification: (json['requiresVerification'] as bool?) ?? false,
      requiresFrendlyPlus: (json['requiresFrendlyPlus'] as bool?) ?? false,
      routeId: json['routeId'] as String?,
      routePointCount: (json['routePointCount'] as num?)?.toInt(),
      routePoints: ((json['routePoints'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => EventRoutePoint.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .whereType<EventRoutePoint>()
          .toList(growable: false),
      isAfficheBacked: (json['isAfficheBacked'] as bool?) ?? false,
      isDate: (json['isDate'] as bool?) ?? false,
      hostNote: json['hostNote'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      joined: (json['joined'] as bool?) ?? false,
      joinMode: parseJoinMode(json['joinMode'] as String?),
      joinRequestStatus:
          parseJoinRequestStatus(json['joinRequestStatus'] as String?),
      attendanceStatus:
          parseAttendanceStatus(json['attendanceStatus'] as String?),
      liveStatus: parseLiveStatus(json['liveStatus'] as String?),
      isHost: (json['isHost'] as bool?) ?? false,
      ticketUrl: json['ticketUrl'] as String?,
      ticketSourceKind:
          parseTicketSourceKind(json['ticketSourceKind'] as String?),
      ticketSourceId: json['ticketSourceId'] as String?,
      ticketPriceFrom: (json['ticketPriceFrom'] as num?)?.toInt(),
      ticketProvider: json['ticketProvider'] as String?,
      ticketVenue: json['ticketVenue'] as String?,
      bookingUrl: json['bookingUrl'] as String?,
      bookingProvider: json['bookingProvider'] as String?,
      bookingPlaceId: json['bookingPlaceId'] as String?,
      bookingAverageCheck: (json['bookingAverageCheck'] as num?)?.toInt(),
      bookingCurrency: json['bookingCurrency'] as String?,
      bookingPromos: ((json['bookingPromos'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => EventBookingPromo.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }

  static EventTone parseTone(String? raw) {
    switch (raw) {
      case 'evening':
        return EventTone.evening;
      case 'sage':
        return EventTone.sage;
      case 'warm':
      default:
        return EventTone.warm;
    }
  }

  static EventJoinMode parseJoinMode(String? raw) {
    switch (raw) {
      case 'request':
        return EventJoinMode.request;
      case 'open':
      default:
        return EventJoinMode.open;
    }
  }

  static EventJoinRequestStatus? parseJoinRequestStatus(String? raw) {
    switch (raw) {
      case 'pending':
        return EventJoinRequestStatus.pending;
      case 'approved':
        return EventJoinRequestStatus.approved;
      case 'rejected':
        return EventJoinRequestStatus.rejected;
      case 'canceled':
        return EventJoinRequestStatus.canceled;
      default:
        return null;
    }
  }

  static EventAttendanceStatus parseAttendanceStatus(String? raw) {
    switch (raw) {
      case 'checked_in':
        return EventAttendanceStatus.checkedIn;
      case 'left':
        return EventAttendanceStatus.left;
      case 'not_checked_in':
      default:
        return EventAttendanceStatus.notCheckedIn;
    }
  }

  static EventLiveStatus parseLiveStatus(String? raw) {
    switch (raw) {
      case 'live':
        return EventLiveStatus.live;
      case 'finished':
        return EventLiveStatus.finished;
      case 'idle':
      default:
        return EventLiveStatus.idle;
    }
  }

  static EventTicketSourceKind? parseTicketSourceKind(String? raw) {
    switch (raw) {
      case 'affiche':
        return EventTicketSourceKind.affiche;
      default:
        return null;
    }
  }
}
