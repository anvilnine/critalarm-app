import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Reads the version from `UIDevice.systemVersion` on iOS and from
/// `Build.VERSION.RELEASE` on Android, falling back to the API level when the
/// release string is not a number. The web has no phone to ask.
class PlatformOsVersionReader implements OsVersionReader {
  PlatformOsVersionReader(
    this._deviceInfo, {
    required this._platform,
    required this._isWeb,
  });

  final DeviceInfoPlugin _deviceInfo;
  final TargetPlatform _platform;
  final bool _isWeb;

  @override
  Future<int?> major() async {
    if (_isWeb) return null;
    try {
      if (_platform == TargetPlatform.iOS) {
        return majorOf((await _deviceInfo.iosInfo).systemVersion);
      }
      if (_platform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        return majorOf(info.version.release) ?? info.version.sdkInt;
      }
      return null;
    } on Object {
      return null;
    }
  }

  /// The leading number of a version string, or null: `18.2.1` is 18.
  @visibleForTesting
  static int? majorOf(String version) =>
      int.tryParse(RegExp(r'^\s*(\d+)').firstMatch(version)?.group(1) ?? '');
}
