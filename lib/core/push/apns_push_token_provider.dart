import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';

/// The raw APNs device token, which is what the relay pushes to on iOS.
///
/// Firebase Messaging is not in this path. api.md §5.1 has the relay talking
/// to APNs itself, so the token the relay needs is the one
/// `didRegisterForRemoteNotificationsWithDeviceToken` hands the app.
final class ApnsPushTokenProvider implements PushTokenProvider {
  ApnsPushTokenProvider(this._host);

  final PushHost _host;

  @override
  PushTokenKind get kind => PushTokenKind.apns;

  @override
  Future<String> getToken() async =>
      await _host.apnsToken() ?? (throw StateError('APNs token unavailable'));

  @override
  Stream<String> get tokenRefreshes => _host.tokenRefreshes;
}
