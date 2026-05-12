import 'package:big_break_mobile/shared/widgets/bb_brand_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand icon uses compact asset and bounded decode',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: BbBrandIcon(size: 64),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resizeImage = image.image as ResizeImage;
    final provider = resizeImage.imageProvider as AssetImage;

    expect(provider.assetName, BbBrandIcon.assetPath);
    expect(resizeImage.width, 192);
    expect(resizeImage.height, 192);
  });
}
