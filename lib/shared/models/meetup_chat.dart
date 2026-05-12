import 'package:big_break_mobile/shared/models/profile.dart';

enum MeetupPhase { live, soon, upcoming, done }

enum EveningLaunchMode { auto, manual, hybrid }

enum EveningPrivacy { open, request, invite }

enum MeetupChatTicketSourceKind { poster, affiche }

class MeetupMember {
  const MeetupMember({
    required this.name,
    this.userId,
    this.online = false,
    this.isCurrentUser = false,
    this.social = const ProfileSocialData.empty(),
  });

  final String? userId;
  final String name;
  final bool online;
  final bool isCurrentUser;
  final ProfileSocialData social;

  String get displayName => isCurrentUser ? 'Ты' : name;

  factory MeetupMember.fromJson(Map<String, dynamic> json) {
    final name = _optionalString(json['name']) ??
        _optionalString(json['displayName']) ??
        '';
    return MeetupMember(
      userId: _optionalString(json['userId']),
      name: name,
      online: (json['online'] as bool?) ?? false,
      isCurrentUser: (json['isCurrentUser'] as bool?) ?? name == 'Ты',
      social: ProfileSocialData.fromJson(json['social']),
    );
  }

  factory MeetupMember.fromName(String name) {
    return MeetupMember(
      name: name,
      isCurrentUser: name == 'Ты',
    );
  }
}

class MeetupChat {
  const MeetupChat({
    required this.id,
    required this.eventId,
    required this.title,
    required this.emoji,
    required this.time,
    required this.lastMessage,
    required this.lastAuthor,
    required this.lastTime,
    required this.unread,
    required this.members,
    this.lastMessageId,
    this.memberProfiles = const [],
    this.status,
    this.isPinned = false,
    this.typing = false,
    this.phase = MeetupPhase.upcoming,
    this.currentStep,
    this.totalSteps,
    this.currentPlace,
    this.endTime,
    this.startsInLabel,
    this.routeId,
    this.routeTemplateId,
    this.isCurated = false,
    this.badgeLabel,
    this.sessionId,
    this.mode = EveningLaunchMode.hybrid,
    this.privacy = EveningPrivacy.open,
    this.joinedCount,
    this.maxGuests,
    this.hostUserId,
    this.hostName,
    this.area,
    this.ticketUrl,
    this.ticketSourceKind,
    this.ticketSourceId,
    this.ticketPriceFrom,
    this.ticketProvider,
    this.ticketVenue,
  });

  final String id;
  final String? eventId;
  final String title;
  final String emoji;
  final String time;
  final String? lastMessageId;
  final String lastMessage;
  final String lastAuthor;
  final String lastTime;
  final int unread;
  final List<String> members;
  final List<MeetupMember> memberProfiles;
  final String? status;
  final bool isPinned;
  final bool typing;
  final MeetupPhase phase;
  final int? currentStep;
  final int? totalSteps;
  final String? currentPlace;
  final String? endTime;
  final String? startsInLabel;
  final String? routeId;
  final String? routeTemplateId;
  final bool isCurated;
  final String? badgeLabel;
  final String? sessionId;
  final EveningLaunchMode mode;
  final EveningPrivacy privacy;
  final int? joinedCount;
  final int? maxGuests;
  final String? hostUserId;
  final String? hostName;
  final String? area;
  final String? ticketUrl;
  final MeetupChatTicketSourceKind? ticketSourceKind;
  final String? ticketSourceId;
  final int? ticketPriceFrom;
  final String? ticketProvider;
  final String? ticketVenue;

  bool get hasPaidTicket =>
      (ticketUrl ?? '').trim().isNotEmpty &&
      ticketPriceFrom != null &&
      ticketPriceFrom! > 0;

  factory MeetupChat.fromJson(Map<String, dynamic> json) {
    final memberProfiles = _parseMemberProfiles(json['memberProfiles']);
    final memberNames = ((json['members'] as List?) ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final effectiveMembers = memberNames.isNotEmpty
        ? memberNames
        : memberProfiles.map((member) => member.displayName).toList(
              growable: false,
            );

    return MeetupChat(
      id: json['id'] as String,
      eventId: json['eventId'] as String?,
      title: json['title'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '💬',
      time: json['time'] as String? ?? '',
      lastMessageId: json['lastMessageId'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastAuthor: json['lastAuthor'] as String? ?? '',
      lastTime: json['lastTime'] as String? ?? '',
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      members: effectiveMembers,
      memberProfiles: memberProfiles.isNotEmpty
          ? memberProfiles
          : effectiveMembers.map(MeetupMember.fromName).toList(
                growable: false,
              ),
      status: json['status'] as String?,
      isPinned: (json['isPinned'] as bool?) ?? false,
      typing: (json['typing'] as bool?) ?? false,
      phase: parseMeetupPhase(_optionalString(json['phase']) ??
          _optionalString(json['meetupPhase'])),
      currentStep: (json['currentStep'] as num?)?.toInt(),
      totalSteps: (json['totalSteps'] as num?)?.toInt(),
      currentPlace: json['currentPlace'] as String?,
      endTime: json['endTime'] as String?,
      startsInLabel: json['startsInLabel'] as String?,
      routeId: json['routeId'] as String?,
      routeTemplateId: json['routeTemplateId'] as String?,
      isCurated: json['isCurated'] as bool? ?? false,
      badgeLabel: json['badgeLabel'] as String?,
      sessionId: json['sessionId'] as String?,
      mode: parseEveningLaunchMode(json['mode'] as String?),
      privacy: parseEveningPrivacy(json['privacy'] as String?),
      joinedCount: (json['joinedCount'] as num?)?.toInt(),
      maxGuests: (json['maxGuests'] as num?)?.toInt(),
      hostUserId: json['hostUserId'] as String?,
      hostName: json['hostName'] as String?,
      area: json['area'] as String?,
      ticketUrl: json['ticketUrl'] as String?,
      ticketSourceKind: parseMeetupChatTicketSourceKind(
        json['ticketSourceKind'] as String?,
      ),
      ticketSourceId: json['ticketSourceId'] as String?,
      ticketPriceFrom: (json['ticketPriceFrom'] as num?)?.toInt(),
      ticketProvider: json['ticketProvider'] as String?,
      ticketVenue: json['ticketVenue'] as String?,
    );
  }

  MeetupChat copyWith({
    String? id,
    String? eventId,
    String? title,
    String? emoji,
    String? time,
    String? lastMessageId,
    String? lastMessage,
    String? lastAuthor,
    String? lastTime,
    int? unread,
    List<String>? members,
    List<MeetupMember>? memberProfiles,
    String? status,
    bool? isPinned,
    bool? typing,
    MeetupPhase? phase,
    int? currentStep,
    int? totalSteps,
    String? currentPlace,
    String? endTime,
    String? startsInLabel,
    String? routeId,
    String? routeTemplateId,
    bool? isCurated,
    String? badgeLabel,
    String? sessionId,
    EveningLaunchMode? mode,
    EveningPrivacy? privacy,
    int? joinedCount,
    int? maxGuests,
    bool clearMaxGuests = false,
    String? hostUserId,
    String? hostName,
    String? area,
    String? ticketUrl,
    MeetupChatTicketSourceKind? ticketSourceKind,
    String? ticketSourceId,
    int? ticketPriceFrom,
    String? ticketProvider,
    String? ticketVenue,
  }) {
    return MeetupChat(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      time: time ?? this.time,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastAuthor: lastAuthor ?? this.lastAuthor,
      lastTime: lastTime ?? this.lastTime,
      unread: unread ?? this.unread,
      members: members ?? this.members,
      memberProfiles: memberProfiles ?? this.memberProfiles,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      typing: typing ?? this.typing,
      phase: phase ?? this.phase,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      currentPlace: currentPlace ?? this.currentPlace,
      endTime: endTime ?? this.endTime,
      startsInLabel: startsInLabel ?? this.startsInLabel,
      routeId: routeId ?? this.routeId,
      routeTemplateId: routeTemplateId ?? this.routeTemplateId,
      isCurated: isCurated ?? this.isCurated,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      sessionId: sessionId ?? this.sessionId,
      mode: mode ?? this.mode,
      privacy: privacy ?? this.privacy,
      joinedCount: joinedCount ?? this.joinedCount,
      maxGuests: clearMaxGuests ? null : maxGuests ?? this.maxGuests,
      hostUserId: hostUserId ?? this.hostUserId,
      hostName: hostName ?? this.hostName,
      area: area ?? this.area,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      ticketSourceKind: ticketSourceKind ?? this.ticketSourceKind,
      ticketSourceId: ticketSourceId ?? this.ticketSourceId,
      ticketPriceFrom: ticketPriceFrom ?? this.ticketPriceFrom,
      ticketProvider: ticketProvider ?? this.ticketProvider,
      ticketVenue: ticketVenue ?? this.ticketVenue,
    );
  }
}

MeetupChatTicketSourceKind? parseMeetupChatTicketSourceKind(String? raw) {
  switch (raw) {
    case 'poster':
      return MeetupChatTicketSourceKind.poster;
    case 'affiche':
      return MeetupChatTicketSourceKind.affiche;
    default:
      return null;
  }
}

List<MeetupMember> _parseMemberProfiles(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((entry) => MeetupMember.fromJson(Map<String, dynamic>.from(entry)))
      .where((member) => member.name.isNotEmpty)
      .toList(growable: false);
}

String? _optionalString(Object? value) {
  return value is String ? value : null;
}

MeetupPhase parseMeetupPhase(String? value) {
  switch (value) {
    case 'live':
      return MeetupPhase.live;
    case 'soon':
      return MeetupPhase.soon;
    case 'done':
      return MeetupPhase.done;
    case 'upcoming':
    default:
      return MeetupPhase.upcoming;
  }
}

String meetupPhaseToJson(MeetupPhase phase) {
  switch (phase) {
    case MeetupPhase.live:
      return 'live';
    case MeetupPhase.soon:
      return 'soon';
    case MeetupPhase.upcoming:
      return 'upcoming';
    case MeetupPhase.done:
      return 'done';
  }
}

EveningLaunchMode parseEveningLaunchMode(String? value) {
  switch (value) {
    case 'auto':
      return EveningLaunchMode.auto;
    case 'manual':
      return EveningLaunchMode.manual;
    case 'hybrid':
    default:
      return EveningLaunchMode.hybrid;
  }
}

String eveningLaunchModeToJson(EveningLaunchMode mode) {
  switch (mode) {
    case EveningLaunchMode.auto:
      return 'auto';
    case EveningLaunchMode.manual:
      return 'manual';
    case EveningLaunchMode.hybrid:
      return 'hybrid';
  }
}

EveningPrivacy parseEveningPrivacy(String? value) {
  switch (value) {
    case 'request':
      return EveningPrivacy.request;
    case 'invite':
      return EveningPrivacy.invite;
    case 'open':
    default:
      return EveningPrivacy.open;
  }
}

String eveningPrivacyToJson(EveningPrivacy privacy) {
  switch (privacy) {
    case EveningPrivacy.open:
      return 'open';
    case EveningPrivacy.request:
      return 'request';
    case EveningPrivacy.invite:
      return 'invite';
  }
}
