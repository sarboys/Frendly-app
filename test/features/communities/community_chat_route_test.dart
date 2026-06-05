import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/communities/presentation/community_chat_screen.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('community chat route opens chat directly when chat id is known', () {
    final community = BackendCardItem.fromJson({
      'id': 'community-1',
      'title': 'Wine club',
      'chatId': 'community-chat-1',
    });

    expect(communityChatRouteFor(community), '/chats/community-chat-1');
  });

  test('community chat route keeps resolver fallback without chat id', () {
    final community = BackendCardItem.fromJson({
      'id': 'community-1',
      'title': 'Wine club',
    });

    expect(
      communityChatRouteFor(community),
      '/communities/community-1/chat',
    );
  });
}
