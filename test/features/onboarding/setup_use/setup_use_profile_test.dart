import 'dart:convert';
import 'dart:io';

import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/topic_name_rule.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _en() =>
    jsonDecode(File('assets/translations/en.json').readAsStringSync())
        as Map<String, dynamic>;

/// The string at a dotted key of en.json, or null.
String? _lookup(String key) {
  Object? node = _en();
  for (final part in key.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[part];
  }
  return node is String ? node : null;
}

void main() {
  const named = [
    SetupUse.servers,
    SetupUse.homelab,
    SetupUse.jobs,
    SetupUse.home,
  ];

  group('SetupUse', () {
    test('all five wire ids parse and match the name', () {
      expect(SetupUse.values.map((u) => u.wire), [
        'servers',
        'homelab',
        'jobs',
        'home',
        'other',
      ]);
      for (final use in SetupUse.values) {
        expect(SetupUse.tryParse(use.wire), use);
      }
    });

    test('anything else is null', () {
      expect(SetupUse.tryParse('Servers'), isNull);
      expect(SetupUse.tryParse('HOME'), isNull);
      expect(SetupUse.tryParse(' home'), isNull);
      expect(SetupUse.tryParse(''), isNull);
      expect(SetupUse.tryParse(null), isNull);
      expect(SetupUse.tryParse('skipped'), isNull);
    });
  });

  group('the table', () {
    test('has one profile per answer', () {
      for (final use in SetupUse.values) {
        expect(SetupUseProfile.of(use), isNotNull, reason: use.wire);
      }
      expect(SetupUse.values.length, 5);
    });

    test('names, other names and sample keys match', () {
      Map<String, Object?> column(Object? Function(SetupUseProfile) read) => {
        for (final use in SetupUse.values)
          use.wire: read(SetupUseProfile.of(use)),
      };
      expect(column((p) => p.name), {
        'servers': 'prod-db',
        'homelab': 'uptime-kuma',
        'jobs': 'nightly-backup',
        'home': 'home-assistant',
        'other': null,
      });
      expect(column((p) => p.otherNames), {
        'servers': ['prod-api', 'client-vps', 'deploy-failed'],
        'homelab': ['homelab', 'nas-disk', 'backup-job'],
        'jobs': ['ci', 'deploy', 'cron'],
        'home': ['freezer', 'garage-door', 'washer'],
        'other': <String>[],
      });
      expect(column((p) => p.sampleKey), {
        'servers': 'setup_use.sample.servers',
        'homelab': 'setup_use.sample.homelab',
        'jobs': 'setup_use.sample.jobs',
        'home': 'setup_use.sample.home',
        'other': null,
      });
    });

    test('four answers have a name and three other names, other has none', () {
      for (final use in named) {
        final profile = SetupUseProfile.of(use);
        expect(profile.name, isNotNull, reason: use.wire);
        expect(profile.otherNames.length, 3, reason: use.wire);
      }
      final other = SetupUseProfile.of(SetupUse.other);
      expect(other.name, isNull);
      expect(other.otherNames, isEmpty);
    });

    test(
      'every name passes the topic name rule and is unique in its profile',
      () {
        for (final use in SetupUse.values) {
          final profile = SetupUseProfile.of(use);
          final names = [?profile.name, ...profile.otherNames];
          for (final name in names) {
            expect(isValidTopicName(name), isTrue, reason: '${use.wire} $name');
          }
          expect(names.toSet().length, names.length, reason: use.wire);
        }
      },
    );

    test('every tool order holds each tool except other once', () {
      final expected = ToolTemplate.values
          .where((t) => t != ToolTemplate.other)
          .toSet();
      for (final use in SetupUse.values) {
        final order = SetupUseProfile.of(use).toolOrder;
        expect(order.length, expected.length, reason: use.wire);
        expect(order.toSet(), expected, reason: use.wire);
        expect(order, isNot(contains(ToolTemplate.other)), reason: use.wire);
      }
    });

    test('the tool orders are the ones in the table', () {
      List<ToolTemplate> order(SetupUse use) => toolOrderFor(use);
      const kuma = ToolTemplate.uptimeKuma;
      const checks = ToolTemplate.healthchecks;
      const ha = ToolTemplate.homeAssistant;
      const cron = ToolTemplate.cron;
      const ci = ToolTemplate.ci;
      const curl = ToolTemplate.curl;
      expect(order(SetupUse.servers), [curl, cron, ci, kuma, checks, ha]);
      expect(order(SetupUse.homelab), [kuma, checks, ha, cron, ci, curl]);
      expect(order(SetupUse.jobs), [ci, cron, checks, curl, kuma, ha]);
      expect(order(SetupUse.home), [ha, curl, cron, kuma, checks, ci]);
      expect(order(SetupUse.other), [kuma, checks, ha, cron, ci, curl]);
    });

    test('the selected tool is the first of the order, none for other', () {
      for (final use in named) {
        final profile = SetupUseProfile.of(use);
        expect(profile.selectedTool, profile.toolOrder.first, reason: use.wire);
      }
      expect(SetupUseProfile.of(SetupUse.other).selectedTool, isNull);
    });

    test('the leads and waiting lines are the ones in the table', () {
      expect(
        {
          for (final use in SetupUse.values)
            use.wire: (
              SetupUseProfile.of(use).hookUpLead,
              SetupUseProfile.of(use).offerLead,
              SetupUseProfile.of(use).waitingLine,
            ),
        },
        {
          'servers': (
            HookUpLead.curl,
            OfferLead.topics,
            SetupWaitingLine.fromYourServer,
          ),
          'homelab': (
            HookUpLead.toolSteps,
            OfferLead.weeklyCheck,
            SetupWaitingLine.uptimeKuma,
          ),
          'jobs': (
            HookUpLead.curl,
            OfferLead.weeklyCheck,
            SetupWaitingLine.runTheJob,
          ),
          'home': (
            HookUpLead.toolSteps,
            OfferLead.widgets,
            SetupWaitingLine.homeAssistant,
          ),
          'other': (
            HookUpLead.curl,
            OfferLead.today,
            SetupWaitingLine.sendFirstLine,
          ),
        },
      );
    });

    test('the sample key of each of the four exists in en.json', () {
      for (final use in named) {
        final key = SetupUseProfile.of(use).sampleKey;
        expect(key, isNotNull, reason: use.wire);
        expect(_lookup(key!), isNotEmpty, reason: key);
      }
    });

    test('the strings are the ones in the table', () {
      expect(_lookup('setup_use.sample.servers'), 'Replication lag 14 min');
      expect(_lookup('setup_use.sample.homelab'), 'Nextcloud is down');
      expect(
        _lookup('setup_use.sample.jobs'),
        'Nightly backup missed its check-in',
      );
      expect(_lookup('setup_use.sample.home'), 'Freezer is above -10 C');
      expect(
        _lookup('setup_use.sample_body'),
        'This is what a real one looks like.',
      );
      expect(
        _lookup('setup_use.waiting.from_your_server'),
        'send the first line from your server',
      );
      expect(_lookup('setup_use.waiting.run_the_job'), 'run the job once');
      expect(
        _lookup('setup_use.waiting.uptime_kuma'),
        'press Test in Uptime Kuma',
      );
      expect(
        _lookup('setup_use.waiting.home_assistant'),
        'run the action in Home Assistant',
      );
      expect(
        _lookup('setup_use.waiting.healthchecks'),
        'press Test in Healthchecks',
      );
      expect(_lookup('home_card.foot_send_the_line'), 'send the first line');
    });
  });

  group('effectiveUse and toolOrderFor', () {
    test('a missing answer reads as other', () {
      expect(effectiveUse(null), SetupUse.other);
      for (final use in SetupUse.values) {
        expect(effectiveUse(use), use);
      }
      expect(toolOrderFor(null), toolOrderFor(SetupUse.other));
    });
  });

  group('waitingLineFor', () {
    test('each answer with no saved tool gives its own line', () {
      expect(
        {
          for (final use in SetupUse.values) use.wire: waitingLineFor(use: use),
        },
        {
          'servers': SetupWaitingLine.fromYourServer,
          'homelab': SetupWaitingLine.uptimeKuma,
          'jobs': SetupWaitingLine.runTheJob,
          'home': SetupWaitingLine.homeAssistant,
          'other': SetupWaitingLine.sendFirstLine,
        },
      );
    });

    test('a saved tool with documented steps wins over every answer', () {
      const wins = {
        ToolTemplate.uptimeKuma: SetupWaitingLine.uptimeKuma,
        ToolTemplate.homeAssistant: SetupWaitingLine.homeAssistant,
        ToolTemplate.healthchecks: SetupWaitingLine.healthchecks,
      };
      for (final use in [...SetupUse.values, null]) {
        wins.forEach((tool, line) {
          expect(
            waitingLineFor(use: use, savedTool: tool),
            line,
            reason: '${use?.wire} ${tool.id}',
          );
        });
      }
    });

    test('a saved cron, CI, curl or other leaves the answer line', () {
      for (final tool in [
        ToolTemplate.cron,
        ToolTemplate.ci,
        ToolTemplate.curl,
        ToolTemplate.other,
      ]) {
        for (final use in SetupUse.values) {
          expect(
            waitingLineFor(use: use, savedTool: tool),
            waitingLineFor(use: use),
            reason: '${use.wire} ${tool.id}',
          );
        }
        expect(
          waitingLineFor(savedTool: tool),
          SetupWaitingLine.sendFirstLine,
          reason: tool.id,
        );
      }
    });

    test('no answer and no tool reads as other', () {
      expect(waitingLineFor(), SetupWaitingLine.sendFirstLine);
      expect(
        waitingLineFor(use: SetupUse.other),
        SetupWaitingLine.sendFirstLine,
      );
    });
  });
}
