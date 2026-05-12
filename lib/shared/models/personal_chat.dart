class PersonalChat {
  const PersonalChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
    required this.online,
    this.lastMessageId,
    this.peerUserId,
    this.fromMeetup,
    this.isPinned = false,
  });

  final String id;
  final String? peerUserId;
  final String name;
  final String? lastMessageId;
  final String lastMessage;
  final String lastTime;
  final int unread;
  final bool online;
  final String? fromMeetup;
  final bool isPinned;

  factory PersonalChat.fromJson(Map<String, dynamic> json) {
    return PersonalChat(
      id: json['id'] as String,
      peerUserId: json['peerUserId'] as String?,
      name: json['name'] as String? ?? '',
      lastMessageId: json['lastMessageId'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastTime: json['lastTime'] as String? ?? '',
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      online: (json['online'] as bool?) ?? false,
      fromMeetup: json['fromMeetup'] as String?,
      isPinned: (json['isPinned'] as bool?) ?? false,
    );
  }

  PersonalChat copyWith({
    String? id,
    String? peerUserId,
    String? name,
    String? lastMessageId,
    String? lastMessage,
    String? lastTime,
    int? unread,
    bool? online,
    String? fromMeetup,
    bool? isPinned,
  }) {
    return PersonalChat(
      id: id ?? this.id,
      peerUserId: peerUserId ?? this.peerUserId,
      name: name ?? this.name,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      unread: unread ?? this.unread,
      online: online ?? this.online,
      fromMeetup: fromMeetup ?? this.fromMeetup,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
