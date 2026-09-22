/// The one-line publish command for a topic (api.md 1.1 and 1.2), ready to
/// paste into a script.
abstract final class CurlLine {
  static String build({
    required String serverUrl,
    required String topic,
    required String token,
    required String message,
  }) {
    final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return 'curl -H "Authorization: Bearer $token" -d "$message" $base/$topic';
  }
}
