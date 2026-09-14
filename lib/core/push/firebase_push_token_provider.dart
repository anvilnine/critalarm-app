import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final class FirebasePushTokenProvider implements PushTokenProvider {
  FirebasePushTokenProvider([FirebaseMessaging? messaging])
    : _injected = messaging;

  final FirebaseMessaging? _injected;

  // Resolved on first use, not in the constructor. Creating this provider must
  // not need Firebase to be up, because the dependency graph builds it long
  // before anything asks for a token.
  FirebaseMessaging get _messaging => _injected ?? FirebaseMessaging.instance;

  @override
  PushTokenKind get kind => PushTokenKind.fcm;

  @override
  Future<String> getToken() async =>
      (await _messaging.getToken()) ??
      (throw StateError('FCM token unavailable'));

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;
}
