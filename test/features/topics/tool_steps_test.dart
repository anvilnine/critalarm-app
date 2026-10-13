import 'dart:convert';
import 'dart:io';

import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/topics/domain/tool_steps.dart';
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
  const documented = [
    ToolTemplate.uptimeKuma,
    ToolTemplate.healthchecks,
    ToolTemplate.homeAssistant,
  ];

  group('toolStepsFor', () {
    test('the three documented tools return three steps', () {
      for (final template in documented) {
        final steps = toolStepsFor(template);
        expect(steps, isNotNull, reason: template.id);
        expect(steps!.keys, hasLength(3), reason: template.id);
        expect(steps.keys.toSet(), hasLength(3), reason: template.id);
      }
    });

    test('every other tool, and no tool, returns null', () {
      for (final template in ToolTemplate.values) {
        if (documented.contains(template)) continue;
        expect(toolStepsFor(template), isNull, reason: template.id);
      }
      expect(toolStepsFor(null), isNull);
    });

    test('the answer never decides it: only the saved tool does', () {
      // toolStepsFor takes a tool and nothing else, so a servers user on
      // Uptime Kuma gets steps and a homelab user on cron does not.
      for (final use in SetupUse.values) {
        expect(toolStepsFor(ToolTemplate.cron), isNull, reason: use.wire);
        expect(toolStepsFor(ToolTemplate.curl), isNull, reason: use.wire);
        expect(toolStepsFor(ToolTemplate.other), isNull, reason: use.wire);
        expect(
          toolStepsFor(ToolTemplate.uptimeKuma),
          isNotNull,
          reason: use.wire,
        );
      }
    });

    test('the block sits inside the steps', () {
      for (final template in documented) {
        final steps = toolStepsFor(template)!;
        expect(steps.blockAfter, inInclusiveRange(1, steps.keys.length - 1));
      }
    });

    test('Uptime Kuma and Healthchecks open and close the way the docs do', () {
      for (final template in [
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
      ]) {
        final keys = toolStepsFor(template)!.keys;
        expect(keys.last, 'onboarding_hook_up_steps.step_test');
        // The middle step is the sentence the fields already had.
        expect(keys[1], 'onboarding_hook_up.tool_${template.id}');
      }
    });

    test('every step key has words, with no dash and no banned word', () {
      for (final template in documented) {
        for (final key in toolStepsFor(template)!.keys) {
          final text = _lookup(key);
          expect(text, isNotNull, reason: key);
          expect(text, isNotEmpty, reason: key);
          expect(text, isNot(contains('—')), reason: key);
          expect(text, isNot(contains('–')), reason: key);
          // The two sentences that name the tool's own provider are older
          // than this block, and use its label.
          if (key.startsWith('onboarding_hook_up_steps.')) {
            expect(text!.toLowerCase(), isNot(contains('ntfy')), reason: key);
          }
        }
      }
    });
  });

  group('maskToken', () {
    test('keeps tk_, four characters, then the last four', () {
      expect(
        maskToken('tk_da393e7d43be4687a1c9f00b27c4e1a1c9'),
        'tk_da39...a1c9',
      );
      expect(maskToken('tk_0123456789abcdef'), 'tk_0123...cdef');
    });

    test('masks a token exactly as long as the shortest it can hide', () {
      expect(maskToken('tk_012345678901'), 'tk_0123...8901');
    });

    test('a short token masks to tk_...', () {
      expect(maskToken('tk_abc'), 'tk_...');
      expect(maskToken('tk_'), 'tk_...');
      expect(maskToken('tk_01234567890'), 'tk_...');
    });

    test('an empty token masks to nothing', () {
      expect(maskToken(''), '');
    });

    test('a token without the tk_ prefix masks to tk_...', () {
      expect(maskToken('da393e7d43be4687a1c9f00b27c4e1a1c9'), 'tk_...');
      expect(maskToken('TK_da393e7d43be4687a1c9f00b27c4e1a1c9'), 'tk_...');
    });

    test('never leaves the middle of the token in the result', () {
      const token = 'tk_AAAA-secret-middle-ZZZZ';
      final masked = maskToken(token);
      expect(masked, 'tk_AAAA...ZZZZ');
      expect(masked, isNot(contains('secret')));
    });
  });
}
