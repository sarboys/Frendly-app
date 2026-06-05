import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/chats/presentation/chats_screen.dart';
import 'package:mobile2/features/profile/presentation/public_user_screen.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('personal chat rows open the personal chat route', () {
    const summary = BackendChatSummary(
      id: 'direct-1',
      title: 'Nina',
      kind: 'personal',
    );

    expect(chatRouteForSummary(summary), '/chats/direct-1');
  });

  test('meetup chat rows open the chat branch route', () {
    const summary = BackendChatSummary(
      id: 'meetup-1',
      title: 'Coffee',
      kind: 'meetup',
    );

    expect(chatRouteForSummary(summary), '/chats/meetup-1');
  });

  test('direct chat created from profile opens the concrete chat', () {
    expect(
      directChatRouteForResponse({'id': 'direct-1'}),
      '/chats/direct-1',
    );
  });
}
