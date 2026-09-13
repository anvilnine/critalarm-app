import 'package:critalarm/core/push/push_host.dart';

/// The number on the app icon.
///
/// iOS only. [PushHost] answers null on Android, so calling this there does
/// nothing.
final class AppBadge {
  const AppBadge(this._host);

  final PushHost _host;

  /// Zero clears the badge.
  Future<void> setCount(int count) => _host.setBadgeCount(count);
}
