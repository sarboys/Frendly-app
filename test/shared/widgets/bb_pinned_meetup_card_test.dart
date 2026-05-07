import 'package:big_break_mobile/shared/models/meetup_chat.dart';
import 'package:big_break_mobile/shared/widgets/bb_pinned_meetup_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pinned meetup card does not duplicate ticket action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbPinnedMeetupCard(
            chat: MeetupChat(
              id: 'chat-poster',
              eventId: 'event-poster',
              title: 'Концерт',
              emoji: '🎟',
              time: '20:00',
              lastMessage: '',
              lastAuthor: '',
              lastTime: '',
              unread: 0,
              members: ['Ты'],
              ticketUrl: 'https://tickets.example/show',
            ),
            place: 'Клуб, Покровка',
          ),
        ),
      ),
    );

    expect(find.text('Купить билет'), findsNothing);
  });
}
