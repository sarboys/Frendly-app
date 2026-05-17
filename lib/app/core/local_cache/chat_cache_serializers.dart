import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/models/personal_chat.dart';

Map<String, dynamic> meetupChatToCacheJson(MeetupChat chat) {
  return {
    'id': chat.id,
    'eventId': chat.eventId,
    'title': chat.title,
    'emoji': chat.emoji,
    'time': chat.time,
    'lastMessageId': chat.lastMessageId,
    'lastMessage': chat.lastMessage,
    'lastAuthor': chat.lastAuthor,
    'lastTime': chat.lastTime,
    'lastMessageAt': chat.lastMessageAt?.toUtc().toIso8601String(),
    'unread': chat.unread,
    'members': chat.members,
    'status': chat.status,
    'isPinned': chat.isPinned,
    'typing': chat.typing,
    'phase': meetupPhaseToJson(chat.phase),
    'currentStep': chat.currentStep,
    'totalSteps': chat.totalSteps,
    'currentPlace': chat.currentPlace,
    'endTime': chat.endTime,
    'startsInLabel': chat.startsInLabel,
    'routeId': chat.routeId,
    'routeTemplateId': chat.routeTemplateId,
    'isCurated': chat.isCurated,
    'badgeLabel': chat.badgeLabel,
    'sessionId': chat.sessionId,
    'mode': eveningLaunchModeToJson(chat.mode),
    'privacy': eveningPrivacyToJson(chat.privacy),
    'joinedCount': chat.joinedCount,
    'maxGuests': chat.maxGuests,
    'hostUserId': chat.hostUserId,
    'hostName': chat.hostName,
    'area': chat.area,
    'ticketUrl': chat.ticketUrl,
    'ticketSourceKind': _ticketSourceKindToJson(chat.ticketSourceKind),
    'ticketSourceId': chat.ticketSourceId,
    'ticketPriceFrom': chat.ticketPriceFrom,
    'ticketProvider': chat.ticketProvider,
    'ticketVenue': chat.ticketVenue,
  };
}

Map<String, dynamic> personalChatToCacheJson(PersonalChat chat) {
  return {
    'id': chat.id,
    'peerUserId': chat.peerUserId,
    'peerGender': chat.peerGender,
    'name': chat.name,
    'lastMessageId': chat.lastMessageId,
    'lastMessage': chat.lastMessage,
    'lastTime': chat.lastTime,
    'lastMessageAt': chat.lastMessageAt?.toUtc().toIso8601String(),
    'unread': chat.unread,
    'online': chat.online,
    'fromMeetup': chat.fromMeetup,
    'isPinned': chat.isPinned,
  };
}

Map<String, dynamic> messageToCacheJson(Message message) {
  final createdAt = message.createdAt ?? DateTime.now();
  return {
    'id': message.id,
    'chatId': message.chatId,
    'clientMessageId': message.clientMessageId,
    'senderId': message.authorId,
    'senderName': message.author,
    'senderAvatarUrl': message.authorAvatarUrl,
    'text': message.text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'kind': message.isSystem ? 'system' : 'user',
    'attachments': message.attachments.map(_attachmentToCacheJson).toList(),
    if (message.replyTo != null) 'replyTo': _replyToCacheJson(message.replyTo!),
    'isPending': message.isPending,
  };
}

Message messageFromCacheJson(
  Map<String, dynamic> json, {
  required String currentUserId,
}) {
  final message = Message.fromJson(json, currentUserId: currentUserId);
  return message.copyWith(isPending: json['isPending'] == true);
}

Map<String, dynamic> _attachmentToCacheJson(MessageAttachment attachment) {
  return {
    'id': attachment.id,
    'kind': attachment.kind,
    'status': attachment.status,
    'url': attachment.url,
    'downloadUrlPath': attachment.downloadUrlPath,
    'mimeType': attachment.mimeType,
    'byteSize': attachment.byteSize,
    'fileName': attachment.fileName,
    'title': attachment.title,
    'subtitle': attachment.subtitle,
    'latitude': attachment.latitude,
    'longitude': attachment.longitude,
    'expiresAt': attachment.expiresAt?.toUtc().toIso8601String(),
    'durationMs': attachment.durationMs,
    'waveform': attachment.waveform,
  };
}

Map<String, dynamic> _replyToCacheJson(MessageReplyPreview replyTo) {
  return {
    'id': replyTo.id,
    'authorId': replyTo.authorId,
    'author': replyTo.author,
    'text': replyTo.text,
    'isVoice': replyTo.isVoice,
    'mine': replyTo.mine,
  };
}

String? _ticketSourceKindToJson(MeetupChatTicketSourceKind? kind) {
  return switch (kind) {
    MeetupChatTicketSourceKind.affiche => 'affiche',
    null => null,
  };
}
