/// The one-line publish command for a topic (api.md 1.1 and 1.2), ready to
/// paste into a script.
abstract final class CurlLine {
  /// The priority name that rings a critical topic (api.md 1.3 and 1.7).
  static const urgent = 'urgent';

  /// [priority] adds a `Priority` header (api.md 1.3). Leave it out and the
  /// line posts at the default priority, which is stored and never pushed.
  static String build({
    required String serverUrl,
    required String topic,
    required String token,
    required String message,
    String? priority,
  }) {
    final base = baseUrl(serverUrl);
    final level = priority?.trim() ?? '';
    final priorityHeader = level.isEmpty ? '' : ' -H "Priority: $level"';
    return 'curl -H "Authorization: Bearer $token"$priorityHeader '
        '-d "$message" $base/$topic';
  }

  /// [serverUrl] with no space around it and no slash at the end.
  static String baseUrl(String serverUrl) =>
      serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
}
