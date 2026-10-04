import 'package:critalarm/features/topics/domain/tool_snippet.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url = 'https://api.critalarm.app';
  const topic = 'nightly';
  const token = 'tk_8Qm2';

  ToolSnippet? build(ToolTemplate? template, {String serverUrl = url}) =>
      ToolSnippet.build(
        template: template,
        serverUrl: serverUrl,
        topic: topic,
        token: token,
        message: 'backup failed',
      );

  String textOf(ToolSnippet snippet) => switch (snippet) {
    ToolSnippetCode(:final code) => code,
    ToolSnippetFields(:final fields) =>
      fields.map((field) => '${field.label}: ${field.value}').join('\n'),
  };

  test('other and no template have no snippet', () {
    expect(build(ToolTemplate.other), isNull);
    expect(build(null), isNull);
  });

  test('every tool with a snippet names the server and the topic', () {
    for (final template in ToolTemplate.values) {
      if (template == ToolTemplate.other) continue;
      final text = textOf(build(template)!);
      expect(text, contains(url), reason: template.id);
      expect(text, contains(topic), reason: template.id);
    }
  });

  test('the server address loses its trailing slash', () {
    for (final template in ToolTemplate.values) {
      if (template == ToolTemplate.other) continue;
      final text = textOf(build(template, serverUrl: '$url/ ')!);
      expect(text.contains('$url//'), isFalse, reason: template.id);
      expect(text.contains('$url/ '), isFalse, reason: template.id);
    }
  });

  test('cron runs the ringing curl line when the job fails', () {
    final snippet = build(ToolTemplate.cron)! as ToolSnippetCode;
    expect(
      snippet.code,
      '0 3 * * * /usr/local/bin/backup.sh || '
      'curl -H "Authorization: Bearer tk_8Qm2" -H "Priority: urgent" '
      "-d 'backup failed' 'https://api.critalarm.app/nightly'",
    );
  });

  test('CI reads the token from a secret and never prints it', () {
    final snippet = build(ToolTemplate.ci)! as ToolSnippetCode;
    expect(snippet.code.contains(token), isFalse);
    expect(snippet.code, contains(r'${{ secrets.CRITALARM_TOKEN }}'));
    expect(snippet.code, contains('if: failure()'));
    expect(snippet.code, contains('Priority: urgent'));
    expect(snippet.secretName, 'CRITALARM_TOKEN');
  });

  test('Home Assistant posts to the topic with the token and rings', () {
    final snippet = build(ToolTemplate.homeAssistant)! as ToolSnippetCode;
    expect(snippet.code, contains('rest_command:'));
    expect(snippet.code, contains('url: "$url/$topic"'));
    expect(snippet.code, contains('method: post'));
    expect(snippet.code, contains('Authorization: "Bearer $token"'));
    expect(snippet.code, contains('Priority: "urgent"'));
    expect(snippet.code, contains('payload: "{{ message }}"'));
  });

  test('Uptime Kuma gets its own field names, and rings on down only', () {
    final snippet = build(ToolTemplate.uptimeKuma)! as ToolSnippetFields;
    expect(
      {for (final field in snippet.fields) field.label: field.value},
      {
        'ntfy Topic': topic,
        'Server URL': url,
        'Priority': '3',
        'Priority for DOWN-events': '5',
        'Authentication Method': 'Access Token',
        'Access Token': token,
      },
    );
  });

  test('Healthchecks gets its own field names, and rings on down only', () {
    final snippet = build(ToolTemplate.healthchecks)! as ToolSnippetFields;
    expect(
      {for (final field in snippet.fields) field.label: field.value},
      {
        'Topic': topic,
        'Server URL': url,
        'Access Token': token,
        'Priority for "down" events': 'Max priority',
        'Priority for "up" events': 'Default priority',
      },
    );
  });

  test('only the values a user types are offered for copying', () {
    final snippet = build(ToolTemplate.uptimeKuma)! as ToolSnippetFields;
    expect(
      [
        for (final field in snippet.fields)
          if (field.isCopyable) field.label,
      ],
      ['ntfy Topic', 'Server URL', 'Access Token'],
    );
  });

  test('toString never prints the token', () {
    for (final template in ToolTemplate.values) {
      final snippet = build(template);
      if (snippet == null) continue;
      expect('$snippet'.contains(token), isFalse, reason: template.id);
      if (snippet is ToolSnippetFields) {
        for (final field in snippet.fields) {
          expect('$field'.contains(token), isFalse);
        }
      }
    }
  });
}
