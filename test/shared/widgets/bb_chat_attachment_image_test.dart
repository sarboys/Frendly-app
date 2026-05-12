import 'dart:io';

import 'package:big_break_mobile/shared/models/message.dart';
import 'package:big_break_mobile/shared/widgets/bb_chat_attachment_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat attachment image resolves local file before remote url', () {
    final source = File(
      'lib/shared/widgets/bb_chat_attachment_image.dart',
    ).readAsStringSync();

    expect(source, contains('resolveLocalPath'));
    expect(source, contains('resolveRemoteUrl'));
    expect(
      source.indexOf('resolveLocalPath'),
      lessThan(source.indexOf('resolveRemoteUrl')),
    );
  });

  test('chat screens use shared attachment image viewer', () {
    final personalChat = File(
      'lib/features/personal_chat/presentation/personal_chat_screen.dart',
    ).readAsStringSync();
    final meetupChat = File(
      'lib/features/meetup_chat/presentation/meetup_chat_screen.dart',
    ).readAsStringSync();

    for (final source in [personalChat, meetupChat]) {
      expect(source, contains('BbChatAttachmentImage'));
      expect(source, isNot(contains('CachedNetworkImage')));
    }
  });

  testWidgets('network attachment image uses bounded decode and disk cache', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const attachment = MessageAttachment(
      id: 'att-1',
      kind: 'chat_attachment',
      status: 'ready',
      url: ' https://cdn.example.com/att-1.jpg ',
      mimeType: 'image/jpeg',
      byteSize: 1200,
      fileName: 'att-1.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BbChatAttachmentImage(
            attachment: attachment,
            width: 160,
            height: 120,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            placeholderColor: Colors.black12,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://cdn.example.com/att-1.jpg');
    expect(image.cacheKey, 'chat-attachment-att-1');
    expect(image.memCacheWidth, 480);
    expect(image.memCacheHeight, 360);
    expect(image.maxWidthDiskCache, 480);
    expect(image.maxHeightDiskCache, 360);
    expect(image.cacheManager, isA<ImageCacheManager>());
  });

  testWidgets('private backend media is not loaded without signed url', (
    tester,
  ) async {
    const attachment = MessageAttachment(
      id: 'private-image',
      kind: 'chat_attachment',
      status: 'ready',
      url: 'https://api.frendly.tech/media/private-image',
      mimeType: 'image/jpeg',
      byteSize: 1200,
      fileName: 'private.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BbChatAttachmentImage(
            attachment: attachment,
            width: 160,
            height: 120,
            fit: BoxFit.cover,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            placeholderColor: Colors.black12,
            foregroundColor: Colors.white,
            resolveRemoteUrl: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
