import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meetup chat maps affiche ticket url from backend payload', () {
    final chat = MeetupChat.fromJson({
      'id': 'chat-affiche',
      'eventId': 'event-affiche',
      'title': 'Концерт',
      'emoji': '🎟',
      'time': '20:00',
      'lastMessage': '',
      'lastAuthor': '',
      'lastTime': '',
      'unread': 0,
      'members': ['Ты'],
      'ticketUrl': 'https://tickets.example/show',
      'ticketSourceKind': 'affiche',
      'ticketSourceId': 'affiche-1',
      'ticketPriceFrom': 1200,
      'ticketProvider': 'Kassir',
      'ticketVenue': 'Каро',
    });

    expect(chat.ticketUrl, 'https://tickets.example/show');
    expect(chat.ticketSourceKind, MeetupChatTicketSourceKind.affiche);
    expect(chat.ticketSourceId, 'affiche-1');
    expect(chat.ticketPriceFrom, 1200);
    expect(chat.ticketProvider, 'Kassir');
    expect(chat.ticketVenue, 'Каро');
    expect(chat.hasPaidTicket, isTrue);
  });

  test('meetup chat parses member profiles for direct messages', () {
    final chat = MeetupChat.fromJson({
      'id': 'chat-members',
      'eventId': 'event-members',
      'title': 'Пробежка',
      'emoji': '🏃',
      'time': '20:00',
      'lastMessage': '',
      'lastAuthor': '',
      'lastTime': '',
      'unread': 0,
      'members': ['Сергей', 'Соня М'],
      'memberProfiles': [
        {
          'userId': 'user-me',
          'name': 'Сергей',
          'online': true,
          'isCurrentUser': true,
        },
        {
          'userId': 'user-sonya',
          'name': 'Соня М',
          'online': false,
          'social': {
            'followers': 5,
            'likes': 9,
            'superLikes': 1,
            'iFollow': true,
            'iLike': false,
            'iSuper': true,
          },
        },
      ],
    });

    expect(chat.memberProfiles, hasLength(2));
    expect(chat.memberProfiles.first.displayName, 'Ты');
    expect(chat.memberProfiles.first.userId, 'user-me');
    expect(chat.memberProfiles.first.isCurrentUser, isTrue);
    expect(chat.memberProfiles.last.displayName, 'Соня М');
    expect(chat.memberProfiles.last.userId, 'user-sonya');
    expect(chat.memberProfiles.last.social.followers, 5);
    expect(chat.memberProfiles.last.social.likes, 9);
    expect(chat.memberProfiles.last.social.superLikes, 1);
    expect(chat.memberProfiles.last.social.iFollow, isTrue);
  });

  test('meetup chat maps pinned state from backend payload', () {
    final chat = MeetupChat.fromJson({
      'id': 'chat-pinned',
      'eventId': 'event-pinned',
      'title': 'Кофе',
      'emoji': '☕',
      'time': '12:00',
      'lastMessage': '',
      'lastAuthor': '',
      'lastTime': '',
      'unread': 0,
      'members': ['Ты'],
      'isPinned': true,
    });

    expect(chat.isPinned, isTrue);
    expect(chat.copyWith(isPinned: false).isPinned, isFalse);
  });
}
