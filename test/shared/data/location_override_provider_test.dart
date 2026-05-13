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

  test('manual location rejects legacy saved label without coordinates',
      () async {
    SharedPreferences.setMockInitialValues({
      'location.manual.v1': '{"label":"Москва","city":"Москва"}',
    });
    final preferences = await SharedPreferences.getInstance();

    final restored = ManualLocationController(preferences).state;

    expect(restored, isNull);
  });

  test('manual location rejects empty zero coordinate', () {
    expect(
      isSupportedManualLocation(
        const ManualLocation(
          label: 'Москва',
          latitude: 0,
          longitude: 0,
          city: 'Москва',
        ),
      ),
      isFalse,
    );
  });

  test('manual location controller clears invalid saved point', () async {
    SharedPreferences.setMockInitialValues({
      'location.manual.v1':
          '{"label":"Москва","latitude":55.7558,"longitude":37.6173}',
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = ManualLocationController(preferences);

    controller.setLocation(
      const ManualLocation(
        label: 'Москва',
        latitude: 0,
        longitude: 0,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state, isNull);
    expect(preferences.getString('location.manual.v1'), isNull);
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
