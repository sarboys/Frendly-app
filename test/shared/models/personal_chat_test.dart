import 'package:big_break_mobile/shared/models/personal_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal chat parses peer gender from backend payload', () {
    final chat = PersonalChat.fromJson({
      'id': 'p1',
      'peerUserId': 'user-anya',
      'peerGender': 'female',
      'name': 'Аня',
      'lastMessage': 'Привет',
      'lastTime': 'сейчас',
      'unread': 0,
      'online': true,
    });

    expect(chat.peerGender, 'female');
  });
}
