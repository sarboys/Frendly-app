import 'package:big_break_mobile/features/posters/presentation/posters_screen.dart';
import 'package:big_break_mobile/shared/data/app_providers.dart';
import 'package:big_break_mobile/shared/data/mock_data.dart';
import 'package:big_break_mobile/shared/models/event.dart';
import 'package:big_break_mobile/shared/models/poster.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_overrides.dart';

Widget _wrap({
  required List<String> observedQueries,
  List<Poster>? posters,
}) {
  final feed = posters ?? mockPosters;
  return ProviderScope(
    overrides: [
      ...buildTestOverrides(),
      posterFeedProvider.overrideWith((ref, query) async {
        observedQueries.add(query.query);
        return feed;
      }),
      featuredPostersProvider.overrideWith((ref) async => feed),
    ],
    child: const MaterialApp(
      home: PostersScreen(),
    ),
  );
}

void main() {
  testWidgets('poster grid uses real cover image when backend sends one', (
    tester,
  ) async {
    final observedQueries = <String>[];

    await tester.pumpWidget(
      _wrap(
        observedQueries: observedQueries,
        posters: [
          Poster(
            id: 'poster-cover',
            title: 'Концерт с фото',
            category: PosterCategory.concert,
            emoji: '🎸',
            startsAt: DateTime(2026, 5, 1, 20),
            dateLabel: '1 мая',
            timeLabel: '20:00',
            venue: 'Aglomerat',
            address: 'Костомаровский пер. 3',
            distance: '1.2 км',
            priceFrom: 1200,
            ticketUrl: 'https://example.com/tickets',
            provider: 'Provider',
            tone: EventTone.warm,
            tags: ['рок'],
            description: 'Описание',
            isFeatured: true,
            imageUrl: 'https://cdn.example.com/poster.jpg',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://cdn.example.com/poster.jpg');
  });

  testWidgets('poster search waits for debounce before requesting feed',
      (tester) async {
    final observedQueries = <String>[];

    await tester.pumpWidget(_wrap(observedQueries: observedQueries));
    await tester.pumpAndSettle();
    observedQueries.clear();

    await tester.enterText(find.byType(TextField), 'Кофе');
    await tester.pump(const Duration(milliseconds: 100));

    expect(observedQueries, isEmpty);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(observedQueries, contains('Кофе'));
  });
}
