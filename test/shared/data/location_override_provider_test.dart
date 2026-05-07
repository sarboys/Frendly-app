import 'package:big_break_mobile/shared/data/location_override_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('manual location accepts an arbitrary saved point', () {
    expect(
      isSupportedManualLocation(
        const ManualLocation(
          label: 'Nha Trang - Duong Tran Phu',
          latitude: 12.2388,
          longitude: 109.1967,
          city: 'Nha Trang',
        ),
      ),
      isTrue,
    );
  });

  test('manual location controller restores the latest saved point', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = ManualLocationController(preferences);

    controller.setLocation(
      const ManualLocation(
        label: 'Москва - Покровка',
        latitude: 55.757,
        longitude: 37.648,
        city: 'Москва',
      ),
    );
    controller.setLocation(
      const ManualLocation(
        label: 'Nha Trang - Duong Tran Phu',
        latitude: 12.2388,
        longitude: 109.1967,
        city: 'Nha Trang',
      ),
    );

    await Future<void>.delayed(Duration.zero);

    final restored = ManualLocationController(preferences).state;

    expect(restored?.label, 'Nha Trang - Duong Tran Phu');
    expect(restored?.latitude, 12.2388);
    expect(restored?.longitude, 109.1967);
    expect(restored?.city, 'Nha Trang');
  });
}
