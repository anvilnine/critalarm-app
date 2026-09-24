import 'package:device_info_plus/device_info_plus.dart';

/// What kind of device the app is running on, as far as layout cares.
///
/// Read once at launch. The only question today is whether this is an
/// iPhone, which is how the layout tells an unfolded iPhone Fold from an iPad
/// of the same size.
final class DeviceForm {
  const DeviceForm({this.isIphone = false});

  final bool isIphone;

  /// Asks `device_info_plus`. Anything that goes wrong, including a test run
  /// with no plugin behind it, answers "not an iPhone", which only means the
  /// rail stays on the left.
  static Future<DeviceForm> read([DeviceInfoPlugin? plugin]) async {
    try {
      final info = await (plugin ?? DeviceInfoPlugin()).deviceInfo;
      return DeviceForm(
        isIphone:
            info is IosDeviceInfo &&
            info.model.toLowerCase().startsWith('iphone'),
      );
    } on Object {
      return const DeviceForm();
    }
  }
}
