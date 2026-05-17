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

  testWidgets('pinned meetup card keeps backend day label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbPinnedMeetupCard(
            chat: MeetupChat(
              id: 'chat-tomorrow',
              eventId: 'event-tomorrow',
              title: 'Прогулка',
              emoji: '🚶',
              time: '15:00',
              status: 'Завтра',
              lastMessage: '',
              lastAuthor: '',
              lastTime: '',
              unread: 0,
              members: ['Ты'],
            ),
            place: 'Маросейка',
          ),
        ),
      ),
    );

    expect(find.text('Завтра · 15:00'), findsOneWidget);
    expect(find.text('Сегодня · 15:00'), findsNothing);
  });

  testWidgets('pinned meetup card renders booking and ticket split grid', (
    tester,
  ) async {
    var bookingTaps = 0;
    var ticketTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BbPinnedMeetupCard(
            chat: const MeetupChat(
              id: 'chat-booking-ticket',
              eventId: 'event-booking-ticket',
              title: 'Концерт',
              emoji: '🎟',
              time: '20:00',
              lastMessage: '',
              lastAuthor: '',
              lastTime: '',
              unread: 0,
              members: ['Ты'],
              ticketUrl: 'https://tickets.example/show',
              ticketPriceFrom: 1200,
            ),
            place: 'Brix Wine',
            capacity: 8,
            bookingTitle: 'Столик на 8',
            onBookingTap: () => bookingTaps += 1,
            onTicketTap: () => ticketTaps += 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('pinned-meetup-booking-grid')), findsOneWidget);
    expect(find.text('бронь'), findsOneWidget);
    expect(find.text('Столик на 8'), findsOneWidget);
    expect(find.text('билет'), findsOneWidget);
    expect(find.text('от 1 200 ₽'), findsOneWidget);

    await tester.tap(find.text('Столик на 8'));
    await tester.tap(find.text('от 1 200 ₽'));

    expect(bookingTaps, 1);
    expect(ticketTaps, 1);
  });
}
