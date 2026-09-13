/// Which push service handed out the token.
///
/// The relay sends iOS through APNs and Android through FCM (api.md §5), so a
/// token that changes kind has to be re-registered even when the string is the
/// same length and shape.
enum PushTokenKind { apns, fcm }

abstract interface class PushTokenProvider {
  PushTokenKind get kind;

  Future<String> getToken();

  Stream<String> get tokenRefreshes;
}
