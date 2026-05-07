import 'package:big_break_mobile/features/posters/presentation/widgets/poster_card.dart';
import 'package:big_break_mobile/shared/data/mock_data.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  testWidgets('compact poster ticket shows venue and time', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PosterCard(
          poster: mockPosters.first,
          variant: PosterCardVariant.compact,
        ),
      ),
    );

    expect(find.text('Adrenaline Stadium'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(find.text('апр'), findsOneWidget);
  });

  testWidgets('poster ticket hides raw daily date label', (tester) async {
    final dailyPoster = Poster(
      id: 'daily',
      title: 'Кандинский. Контрапункт',
      category: PosterCategory.exhibition,
      emoji: '🎨',
      startsAt: DateTime(2026, 4, 22, 11),
      dateLabel: 'Каждый день',
      timeLabel: '11:00–22:00',
      venue: 'Третьяковка на Крымском',
      address: 'Крымский Вал 10',
      distance: '3.4 км',
      priceFrom: 800,
      ticketUrl: 'https://tretyakov.ru',
      provider: 'Третьяковка',
      tone: EventTone.sage,
      tags: const ['живопись', 'до 31 мая'],
      description: 'Большая ретроспектива.',
      isFeatured: true,
    );

    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 360,
          child: PosterCard(poster: dailyPoster),
        ),
      ),
    );

    expect(find.textContaining('Каждый день'), findsNothing);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('апр'), findsOneWidget);
  });
}
