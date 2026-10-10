import 'package:critalarm/features/topics/domain/new_token_rules.dart' as rules;

/// The one-line publish command for a topic (api.md 1.1 and 1.2), ready to
/// paste into a script.
abstract final class CurlLine {
  /// The priority name that rings a critical topic (api.md 1.3 and 1.7).
  static const urgent = 'urgent';

  /// [priority] adds a `Priority` header (api.md 1.3). Leave it out and the
  /// line posts at the default priority, which is stored and never pushed.
  ///
  /// The message and the address go in single quotes, so a shell hands them
  /// to curl as they are: no `$`, backtick, `&` or `?` in them is acted on.
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
        '-d ${shellQuote(message)} ${shellQuote('$base/$topic')}';
  }

  /// What stands where a token would be in a line that is only shown. No
  /// token is behind it.
  static const maskedToken = 'tk_\u2026';

  /// The publish command as a terminal would show it, one flag to a line,
  /// for a picture of the command and never for pasting. The address has no
  /// `https://` (see [shownBase]).
  ///
  /// It takes no token and holds none: the header shows [maskedToken]. It
  /// always carries the priority that rings a critical topic.
  static String forTerminal({
    required String serverUrl,
    required String topic,
    required String message,
  }) {
    final base = shownBase(serverUrl);
    return 'curl $base/$topic \\\n'
        '  -H "Authorization: Bearer $maskedToken" \\\n'
        '  -H "Priority: $urgent" \\\n'
        '  -d ${shellQuote(message)}';
  }

  /// The same picture as [forTerminal], with the header holding [token] with
  /// its middle hidden (`tk_da39...a1c9`), for the sheet that shows a token
  /// once. The full value never appears in it, and it is for looking at.
  /// Copying uses [build].
  static String forTerminalShowing({
    required String serverUrl,
    required String topic,
    required String token,
    required String message,
  }) {
    final base = shownBase(serverUrl);
    return 'curl $base/$topic \\\n'
        '  -H "Authorization: Bearer ${rules.maskedToken(token)}" \\\n'
        '  -H "Priority: $urgent" \\\n'
        '  -d ${shellQuote(message)}';
  }

  /// [text] as one single-quoted shell word. A single quote inside it ends
  /// the quoting, adds an escaped quote and starts the quoting again.
  static String shellQuote(String text) {
    const quote = "'";
    const escapedQuote = r"'\''";
    return '$quote${text.replaceAll(quote, escapedQuote)}$quote';
  }

  /// [baseUrl] without a leading `https://`, for a line that is only shown.
  /// A terminal picture reads shorter and fits a phone without the scheme,
  /// and curl takes an address without one. A plain `http://` stays, because
  /// leaving it out would show a safer line than the one that is copied.
  static String shownBase(String serverUrl) => baseUrl(
    serverUrl,
  ).replaceFirst(RegExp('^https://', caseSensitive: false), '');

  /// [serverUrl] with no space around it and no slash at the end.
  static String baseUrl(String serverUrl) =>
      serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
}
