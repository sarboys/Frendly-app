import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/meetings/presentation/meeting_viewer_state.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('meeting detail treats backend joined flag as active participation', () {
    const meeting = BackendCardItem(
      id: 'event-1',
      title: 'Standup',
      raw: {
        'joined': true,
        'chatId': 'chat-1',
      },
    );

    expect(meetingViewerHasJoined(meeting), isTrue);
  });

  test('join request response keeps original meeting card identity', () {
    const original = BackendCardItem(
      id: 'event-1',
      title: 'Coffee',
      imageUrl: 'https://cdn.test/event.jpg',
      raw: {
        'id': 'event-1',
        'title': 'Coffee',
        'imageUrl': 'https://cdn.test/event.jpg',
        'joinMode': 'request',
      },
    );
    const requestResponse = BackendCardItem(
      id: 'req-1',
      title: '',
      raw: {
        'id': 'req-1',
        'eventId': 'event-1',
        'status': 'pending',
      },
    );

    final updated = meetingWithActionResponse(original, requestResponse);

    expect(updated.id, 'event-1');
    expect(updated.title, 'Coffee');
    expect(updated.imageUrl, 'https://cdn.test/event.jpg');
    expect(updated.raw['joinRequestStatus'], 'pending');
  });
}
