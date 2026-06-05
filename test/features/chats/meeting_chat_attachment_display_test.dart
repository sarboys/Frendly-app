import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/chats/presentation/meeting_chat_screen.dart';

void main() {
  test('image-only messages do not show the file name as message text', () {
    final text = chatMessageBubbleText(
      messageText: '',
      nonVoiceAttachmentLabels: const ['image_picker_A1B2.png'],
    );

    expect(text, isEmpty);
  });

  test('image attachments do not render a separate file label pill', () {
    expect(
      chatAttachmentShouldRenderFilePill(isImage: true, isVoice: false),
      isFalse,
    );
    expect(
      chatAttachmentShouldRenderFilePill(isImage: false, isVoice: false),
      isTrue,
    );
  });
}
