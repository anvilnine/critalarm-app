abstract interface class PushTokenProvider {
  Future<String> getToken();

  Stream<String> get tokenRefreshes;
}
