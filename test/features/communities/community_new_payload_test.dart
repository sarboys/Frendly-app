import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/features/communities/presentation/community_new_screen.dart';

void main() {
  test('community image is required before create submit', () {
    expect(communityImageRequiredError(null), 'Добавь изображение сообщества');
    expect(communityImageRequiredError(''), 'Добавь изображение сообщества');
    expect(communityImageRequiredError('asset-community'), isNull);
  });

  test('community create payload sends uploaded image asset id', () {
    final payload = communityCreatePayload(
      name: 'Wine Club',
      description: 'Friday tastings',
      imageAssetId: 'asset-community-cover',
      avatar: '🍷',
      privacy: 'public',
      purpose: 'Вино',
      tags: const ['Вино'],
    );

    expect(payload['imageAssetId'], 'asset-community-cover');
    expect(payload['avatar'], '🍷');
    expect(payload['name'], 'Wine Club');
  });
}
