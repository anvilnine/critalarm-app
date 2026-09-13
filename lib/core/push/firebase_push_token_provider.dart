import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final class FirebasePushTokenProvider implements PushTokenProvider {
  FirebasePushTokenProvider([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  PushTokenKind get kind => PushTokenKind.fcm;

  @override
  Future<String> getToken() async =>
      (await _messaging.getToken()) ??
      (throw StateError('FCM token unavailable'));

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;
}
