import 'dart:convert';
import 'dart:io';

import 'package:critalarm/features/onboarding/domain/hook_up_waiting_line.dart';
import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_state.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// The string at a dotted key of en.json, or null.
String? _lookup(String key) {
  Object? node = jsonDecode(
    File('assets/translations/en.json').readAsStringSync(),
  );
  for (final part in key.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[part];
  }
  return node is String ? node : null;
}

void main() {
  group('hookUpWaitingLineKey', () {
    test('maps every waiting line to a key that has words', () {
      final keys = {
        for (final line in SetupWaitingLine.values)
          line: hookUpWaitingLineKey(line),
      };
      expect(keys.length, SetupWaitingLine.values.length);
      expect(keys.values.toSet(), hasLength(SetupWaitingLine.values.length));
      for (final MapEntry(:key, :value) in keys.entries) {
        expect(_lookup(value), isNotNull, reason: '${key.name} -> $value');
        expect(_lookup(value), isNotEmpty, reason: key.name);
      }
    });

    test('says the line the table names', () {
      String text(SetupWaitingLine line) =>
          _lookup(hookUpWaitingLineKey(line))!;
      expect(text(SetupWaitingLine.sendFirstLine), 'send the first line');
      expect(
        text(SetupWaitingLine.fromYourServer),
        'send the first line from your server',
      );
      expect(text(SetupWaitingLine.runTheJob), 'run the job once');
      expect(text(SetupWaitingLine.uptimeKuma), 'press Test in Uptime Kuma');
      expect(
        text(SetupWaitingLine.homeAssistant),
        'run the action in Home Assistant',
      );
      expect(
        text(SetupWaitingLine.healthchecks),
        'press Test in Healthchecks',
      );
    });

    test('the line a saved tool with steps reaches the screen with', () {
      String line(SetupUse? use, ToolTemplate tool) => _lookup(
        hookUpWaitingLineKey(waitingLineFor(use: use, savedTool: tool)),
      )!;
      // The saved tool wins over the answer.
      expect(
        line(SetupUse.servers, ToolTemplate.uptimeKuma),
        'press Test in Uptime Kuma',
      );
      expect(
        line(SetupUse.jobs, ToolTemplate.healthchecks),
        'press Test in Healthchecks',
      );
      expect(
        line(null, ToolTemplate.homeAssistant),
        'run the action in Home Assistant',
      );
    });
  });

  group('hookUpStacksChips', () {
    test('keeps one row at the default size and a little above', () {
      expect(hookUpStacksChips(0.85), isFalse);
      expect(hookUpStacksChips(1), isFalse);
      expect(hookUpStacksChips(1.1), isFalse);
    });

    test('stacks from 1.3 up', () {
      expect(hookUpStacksChips(1.3), isTrue);
      expect(hookUpStacksChips(2), isTrue);
    });
  });

  group('HookUpState', () {
    test('toString leaves the token and the address out', () {
      const token = 'tk_da393e7d43be4687a1c9f00b27c4e1a1c9';
      const state = HookUpState(
        phase: HookUpPhase.ready,
        topicName: 'prod-db',
        serverUrl: 'https://api.example.test',
        token: token,
        template: ToolTemplate.uptimeKuma,
      );
      final text = state.toString();
      expect(text, isNot(contains(token)));
      expect(text, isNot(contains('da393e7d')));
      expect(text, isNot(contains('api.example.test')));
      expect(text, isNot(contains('prod-db')));
      expect(text, contains('hasToken: true'));
    });
  });
}
