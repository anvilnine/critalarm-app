import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:flutter/foundation.dart';

/// One field of a tool's own settings form and what to put in it.
@immutable
class ToolSnippetField {
  const ToolSnippetField(this.label, this.value, {this.isCopyable = false});

  /// The field's name as the tool prints it. A product string, so it stays
  /// in English.
  final String label;
  final String value;

  /// True for a value the user pastes. False for one they pick from a list.
  final bool isCopyable;

  /// Never prints the value: it may be the token.
  @override
  String toString() => 'ToolSnippetField($label)';
}

/// What to give a tool so it sends to a topic. Text built on the phone;
/// nothing here is sent anywhere.
///
/// Each tool is described by what it does on the wire. Uptime Kuma and
/// Healthchecks post JSON to the server address with the topic in the body
/// and the token as a bearer token, which is the JSON publish in api.md 1.5.
/// The others run or imitate the curl line (api.md 1.1 to 1.3).
@immutable
sealed class ToolSnippet {
  const ToolSnippet();

  /// The snippet for [template], or null when there is none: no tool was
  /// picked, or the tool is "something else".
  ///
  /// Every snippet sends at the priority that rings a critical topic.
  /// [message] is the sample text for the tools that take one.
  static ToolSnippet? build({
    required ToolTemplate? template,
    required String serverUrl,
    required String topic,
    required String token,
    required String message,
  }) {
    final base = CurlLine.baseUrl(serverUrl);
    switch (template) {
      case null || ToolTemplate.other:
        return null;
      case ToolTemplate.cron:
        final curl = CurlLine.build(
          serverUrl: base,
          topic: topic,
          token: token,
          message: message,
          priority: CurlLine.urgent,
        );
        return ToolSnippetCode('0 3 * * * /usr/local/bin/backup.sh || $curl');
      case ToolTemplate.ci:
        const secret = 'CRITALARM_TOKEN';
        final curl = CurlLine.build(
          serverUrl: base,
          topic: topic,
          token: '\${{ secrets.$secret }}',
          message: message,
          priority: CurlLine.urgent,
        );
        return ToolSnippetCode(
          '- name: Ring my phone\n'
          '  if: failure()\n'
          '  run: |\n'
          '    $curl',
          secretName: secret,
        );
      case ToolTemplate.homeAssistant:
        return ToolSnippetCode(
          'rest_command:\n'
          '  critalarm:\n'
          '    url: "$base/$topic"\n'
          '    method: post\n'
          '    headers:\n'
          '      Authorization: "Bearer $token"\n'
          '      Priority: "urgent"\n'
          '    payload: "{{ message }}"',
        );
      case ToolTemplate.uptimeKuma:
        return ToolSnippetFields([
          ToolSnippetField('ntfy Topic', topic, isCopyable: true),
          ToolSnippetField('Server URL', base, isCopyable: true),
          // This one covers every event, "up" included. At 5 a recovery
          // would ring too.
          const ToolSnippetField('Priority', '3'),
          const ToolSnippetField('Priority for DOWN-events', '5'),
          const ToolSnippetField('Authentication Method', 'Access Token'),
          ToolSnippetField('Access Token', token, isCopyable: true),
        ]);
      case ToolTemplate.healthchecks:
        return ToolSnippetFields([
          ToolSnippetField('Topic', topic, isCopyable: true),
          ToolSnippetField('Server URL', base, isCopyable: true),
          ToolSnippetField('Access Token', token, isCopyable: true),
          const ToolSnippetField('Priority for "down" events', 'Max priority'),
          const ToolSnippetField(
            'Priority for "up" events',
            'Default priority',
          ),
        ]);
    }
  }
}

/// Text to paste into a file: a crontab line, a workflow step, YAML.
final class ToolSnippetCode extends ToolSnippet {
  const ToolSnippetCode(this.code, {this.secretName});

  final String code;

  /// The name of the secret the code reads the token from, when it does
  /// not hold the token itself. The user saves the token under this name.
  final String? secretName;

  /// Never prints the code: it may hold the token.
  @override
  String toString() => 'ToolSnippetCode(${code.length} characters)';
}

/// Values to type into the tool's own settings form, field by field.
final class ToolSnippetFields extends ToolSnippet {
  const ToolSnippetFields(this.fields);

  final List<ToolSnippetField> fields;

  @override
  String toString() => 'ToolSnippetFields(${fields.length} fields)';
}
