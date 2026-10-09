import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _flatStrings() {
  final json =
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
  final out = <String, String>{};
  void walk(String prefix, Map<String, dynamic> node) {
    node.forEach((k, v) {
      final key = prefix.isEmpty ? k : '$prefix.$k';
      if (v is Map<String, dynamic>) {
        walk(key, v);
      } else {
        out[key] = '$v';
      }
    });
  }

  walk('', json);
  return out;
}

String _dotted(String localeKey) => localeKey;

void main() {
  final strings = _flatStrings();

  test('the list is in the agreed order', () {
    expect(HostedBenefit.all.map((b) => b.id), [
      HostedBenefitId.topics,
      HostedBenefitId.pushes,
      HostedBenefitId.history,
      HostedBenefitId.appIcons,
      HostedBenefitId.weeklyCheck,
    ]);
  });

  test('every surface has text for every benefit', () {
    for (final surface in HostedSurface.values) {
      for (final benefit in HostedBenefit.all) {
        expect(
          hostedBenefitHasText(benefit, surface, strings),
          isTrue,
          reason: '${benefit.id.name} on ${surface.name}',
        );
      }
    }
  });

  test('every surface that names Hosted also says the own-server line', () {
    // The Hosted reminder is a one-line notification and is the one known
    // exception. A new surface without the line fails here.
    const exempt = {HostedSurface.proLaterReminder};
    for (final surface in HostedSurface.values) {
      if (exempt.contains(surface)) {
        expect(surface.hasOwnServerLine, isFalse, reason: surface.name);
        expect(surface.ownServerLine, isNull, reason: surface.name);
        continue;
      }
      expect(surface.hasOwnServerLine, isTrue, reason: surface.name);
    }
  });

  test('the own-server line is the paywall note and reads as written', () {
    expect(
      strings['paywall.self_hosted_note'],
      'Running your own server? No limits, no charge.',
    );
    for (final surface in HostedSurface.values) {
      if (surface.hasOwnServerLine) {
        expect(surface.ownServerLine, isNotNull);
      }
    }
  });

  test('every key of every benefit resolves to English', () {
    for (final b in HostedBenefit.all) {
      for (final key in [
        b.shortKey,
        b.compareLabelKey,
        b.compareFreeKey,
        b.compareHostedKey,
        b.loseKey,
        b.phraseKey,
      ]) {
        expect(strings[_dotted(key)], isNotNull, reason: key);
      }
    }
  });

  test('the has-text answer is false when the string is missing', () {
    expect(
      hostedBenefitHasText(
        HostedBenefit.all.first,
        HostedSurface.askSheet,
        const {},
      ),
      isFalse,
    );
  });

  test('every placeholder used in a benefit string is one we fill', () {
    final known = HostedBenefit.args.keys.toSet();
    final group = RegExp(r'\{(\w+)\}');
    for (final entry in strings.entries) {
      if (!entry.key.startsWith('hosted_benefits.')) continue;
      for (final m in group.allMatches(entry.value)) {
        expect(known, contains(m.group(1)), reason: entry.key);
      }
    }
  });

  test('free numbers come from AccountCaps and Hosted from the constants', () {
    final args = HostedBenefit.args;
    expect(args['free_critical_topics'], '${AccountCaps.free.criticalTopics}');
    expect(args['free_p4_daily'], '${AccountCaps.free.p4Daily}');
    expect(args['free_history_days'], '${AccountCaps.free.historyDays}');
    expect(args['hosted_p4_daily'], '1,000');
    expect(args['hosted_history_days'], '$hostedHistoryDays');
    final byId = {for (final b in HostedBenefit.all) b.id: b};
    expect(byId[HostedBenefitId.pushes]!.freeValue, AccountCaps.free.p4Daily);
    expect(byId[HostedBenefitId.pushes]!.hostedValue, hostedP4Daily);
    expect(
      byId[HostedBenefitId.history]!.freeValue,
      AccountCaps.free.historyDays,
    );
    expect(
      byId[HostedBenefitId.topics]!.freeValue,
      AccountCaps.free.criticalTopics,
    );
  });

  test('no benefit string hardcodes a Hosted number', () {
    for (final entry in strings.entries) {
      if (!entry.key.startsWith('hosted_benefits.')) continue;
      expect(entry.value, isNot(contains('1,000')), reason: entry.key);
      expect(entry.value, isNot(contains('1000')), reason: entry.key);
      expect(entry.value, isNot(contains('90 ')), reason: entry.key);
    }
  });

  test('no string ties home screen widgets to Hosted', () {
    for (final entry in strings.entries) {
      if (entry.key.startsWith('hosted_benefits.widgets')) {
        fail('${entry.key} is a Hosted widgets string');
      }
    }
    for (final key in [
      'onboarding_welcome.widgets_pro',
      'home_widgets.needs_pro',
      'home_widgets.plans_button',
    ]) {
      expect(strings[key], isNotNull, reason: key);
      expect(strings[key], isNot(contains('Hosted')), reason: key);
      expect(strings[key], contains('Pro'), reason: key);
    }
  });

  group('joinBenefitPhrases', () {
    test('one item stands alone', () {
      expect(joinBenefitPhrases(['a'], and: 'and'), 'a');
    });

    test('two items join with and', () {
      expect(joinBenefitPhrases(['a', 'b'], and: 'and'), 'a and b');
    });

    test('three items have no comma before and', () {
      expect(joinBenefitPhrases(['a', 'b', 'c'], and: 'and'), 'a, b and c');
    });

    test('five items', () {
      expect(
        joinBenefitPhrases(['a', 'b', 'c', 'd', 'e'], and: 'and'),
        'a, b, c, d and e',
      );
    });

    test('the word comes from the strings', () {
      expect(strings['hosted_benefits.and'], 'and');
    });
  });
}
