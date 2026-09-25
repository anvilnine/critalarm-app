import 'package:device_info_plus/device_info_plus.dart';

/// What kind of device the app is running on, as far as layout cares.
///
/// Read once at launch. It answers two questions: whether this is an iPhone,
/// which is how the layout tells an unfolded iPhone Fold from an iPad of the
/// same size, and whether Android calls this a low-RAM phone, which turns the
/// list edge effects off.
final class DeviceForm {
  const DeviceForm({this.isIphone = false, this.isLowRamDevice = false});

  final bool isIphone;
  final bool isLowRamDevice;

  /// Asks `device_info_plus`. Anything that goes wrong, including a test run
  /// with no plugin behind it, answers "not an iPhone" and "not low on
  /// RAM", which only means the rail stays on the left.
  static Future<DeviceForm> read([DeviceInfoPlugin? plugin]) async {
    try {
      final info = await (plugin ?? DeviceInfoPlugin()).deviceInfo;
      return DeviceForm(
        isIphone: info is IosDeviceInfo && isIphoneModel(info.model),
        isLowRamDevice: info is AndroidDeviceInfo && info.isLowRamDevice,
      );
    } on Object {
      return const DeviceForm();
    }
  }
}

/// True when `UIDevice.model` names an iPhone. iOS answers "iPhone", "iPad"
/// or "iPod touch", and the simulator answers the same as the device.
bool isIphoneModel(String model) => model.toLowerCase().startsWith('iphone');
