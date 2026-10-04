import 'package:critalarm/core/device/device_maker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Reads the maker from Android's `Build.MANUFACTURER` and `Build.BRAND`, and
/// the API level from `Build.VERSION.SDK_INT`.
///
/// Only Android is asked. An iPhone has one maker and the web has none, so
/// both answer [DeviceMaker.unknown] without touching the plugin.
class PlatformDeviceMakerReader implements DeviceMakerReader, AndroidSdkReader {
  PlatformDeviceMakerReader(
    this._deviceInfo, {
    required TargetPlatform platform,
    required bool isWeb,
  }) : _isAndroid = !isWeb && platform == TargetPlatform.android;

  final DeviceInfoPlugin _deviceInfo;
  final bool _isAndroid;

  DeviceMaker? _cached;
  int? _sdk;

  @override
  Future<DeviceMaker> read() async {
    if (!_isAndroid) return DeviceMaker.unknown;
    await _load();
    return _cached ?? DeviceMaker.unknown;
  }

  @override
  Future<int?> sdkInt() async {
    if (!_isAndroid) return null;
    await _load();
    return _sdk;
  }

  Future<void> _load() async {
    if (_cached != null) return;
    try {
      final info = await _deviceInfo.androidInfo;
      _sdk = info.version.sdkInt;
      _cached = DeviceMaker(manufacturer: info.manufacturer, brand: info.brand);
    } on Object {
      // Not cached, so the next read tries again.
    }
  }
}
