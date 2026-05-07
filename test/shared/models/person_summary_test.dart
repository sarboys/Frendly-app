import 'package:big_break_mobile/shared/models/person_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('person summary parses bounded social preview', () {
    final person = PersonSummary.fromJson({
      'id': 'user-anna',
      'name': 'Аня',
      'age': 29,
      'area': 'Центр',
      'common': ['кино'],
      'online': true,
      'verified': false,
      'vibe': 'Спокойно',
      'avatarUrl': null,
      'social': {
        'followers': 7,
        'likes': 12,
        'superLikes': 2,
        'iFollow': true,
        'iLike': false,
        'iSuper': true,
      },
    });

    expect(person.social.followers, 7);
    expect(person.social.likes, 12);
    expect(person.social.superLikes, 2);
    expect(person.social.iFollow, isTrue);
    expect(person.social.iLike, isFalse);
    expect(person.social.iSuper, isTrue);
  });
}
