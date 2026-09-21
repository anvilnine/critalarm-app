import 'package:flutter/foundation.dart';

/// What a bug report or feedback form carries about the phone, so a report
/// can be matched to a build without asking the user.
@immutable
class DeviceReport {
  const DeviceReport({
    required this.appVersion,
    required this.buildNumber,
    required this.device,
    required this.os,
    required this.server,
    required this.plan,
    required this.locale,
  });

  /// `0.1.0`
  final String appVersion;

  /// `5`
  final String buildNumber;

  /// The model id, `iPhone15,2` or `Google Pixel 8`.
  final String device;

  /// `iOS 26.0` or `Android 15`.
  final String os;

  /// `hosted`, `selfhosted` or `none`.
  final String server;

  /// `free` or `pro`.
  final String plan;

  /// `en-PH`
  final String locale;

  /// The lines added to the bottom of a problem report email.
  String get mailFooter =>
      '--\n'
      'App: $appVersion ($buildNumber)\n'
      'Phone: $device · $os\n'
      'Server: $server · Plan: $plan\n'
      'Language: $locale';
}
