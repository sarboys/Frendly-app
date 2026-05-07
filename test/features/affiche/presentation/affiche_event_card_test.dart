import 'package:big_break_mobile/app/theme/app_theme.dart';
import 'package:big_break_mobile/features/affiche/presentation/affiche_event_card.dart';
import 'package:big_break_mobile/shared/models/affiche_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact affiche card keeps long event text inside the card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: AfficheEventCard(
              compact: true,
              event: _event(
                title: 'Стендап-экскурсия по Санкт-Петербургу',
                provider: 'Ticketland / MTS Live',
                venue: 'Парадная камера Пушкина',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

AfficheEvent _event({
  required String title,
  required String provider,
  required String venue,
}) {
  return AfficheEvent(
    id: 'affiche-overflow',
    title: title,
    description: null,
    city: 'Санкт-Петербург',
    venue: venue,
    address: 'Набережная реки Фонтанки, 20',
    latitude: null,
    longitude: null,
    startsAt: DateTime(2026, 5, 5, 19),
    endsAt: null,
    dateLabel: '5 мая',
    timeLabel: '19:00',
    category: 'culture',
    priceFrom: 1200,
    priceMode: AffichePriceMode.paid,
    currency: 'RUB',
    imageUrl: null,
    provider: provider,
    sourceCode: 'ticketland',
    actionUrl: 'https://tickets.example.com',
    actionKind: 'affiliate_ticket',
    isAffiliate: true,
    tags: const [],
  );
}
