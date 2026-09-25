import 'package:critalarm/core/device/device_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an iPhone model name is an iPhone', () {
    expect(isIphoneModel('iPhone'), isTrue);
  });

  test('an iPad and an iPod touch are not', () {
    expect(isIphoneModel('iPad'), isFalse);
    expect(isIphoneModel('iPod touch'), isFalse);
  });

  test('no plugin behind it answers not an iPhone', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect((await DeviceForm.read()).isIphone, isFalse);
  });
}
