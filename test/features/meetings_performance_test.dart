import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/meetings/presentation/meetings_screen.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('meetings prewarm uses only the first six meeting card variants', () {
    final meetings = List.generate(
      8,
      (index) => BackendCardItem.fromJson({
        'id': 'meeting-$index',
        'title': 'Meeting $index',
        'imageUrl': 'https://cdn.test/meeting-$index.jpg',
        'imageVariants': {
          'card': {
            'url': 'https://cdn.test/meeting-$index-card.webp',
          },
        },
      }),
    );

    expect(meetingPrewarmImageUrls(meetings).toList(growable: false), [
      'https://cdn.test/meeting-0-card.webp',
      'https://cdn.test/meeting-1-card.webp',
      'https://cdn.test/meeting-2-card.webp',
      'https://cdn.test/meeting-3-card.webp',
      'https://cdn.test/meeting-4-card.webp',
      'https://cdn.test/meeting-5-card.webp',
    ]);
  });
}
