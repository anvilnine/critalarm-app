import 'dart:convert';
import 'dart:io';

import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
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

void main() {
  final strings = _flatStrings();

  test('a benefit not in this build never reaches a layout', () {
    for (final product in PaywallProduct.values) {
      final listed = paywallBenefitsFor(product);
      expect(listed, isNotEmpty, reason: product.key);
      expect(listed.every((b) => b.inThisBuild), isTrue, reason: product.key);
      expect(listed.every((b) => b.product == product), isTrue);
    }
    final hidden = allPaywallBenefits.where((b) => !b.inThisBuild);
    expect(hidden, isNotEmpty);
    final shown = {
      for (final product in PaywallProduct.values)
        ...paywallBenefitsFor(product).map((b) => b.id),
    };
    for (final benefit in hidden) {
      expect(shown, isNot(contains(benefit.id)), reason: benefit.id.key);
    }
  });

  test('the listed benefits keep the display order of the full list', () {
    for (final product in PaywallProduct.values) {
      expect(
        paywallBenefitsFor(product).map((b) => b.id),
        allPaywallBenefits
            .where((b) => b.product == product && b.inThisBuild)
            .map((b) => b.id),
      );
    }
  });

  test('every benefit has a title and a line that exist in en.json', () {
    for (final benefit in allPaywallBenefits) {
      for (final key in [benefit.titleKey, benefit.lineKey]) {
        expect(key, isNotEmpty, reason: benefit.id.key);
        expect(strings[key]?.trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('Hosted lists the benefits of HostedBenefit.all that have a line '
      'and a preview for a layout, in its order', () {
    final hosted = allPaywallBenefits
        .where((b) => b.product == PaywallProduct.hosted)
        .toList();
    expect(hosted.map((b) => b.id), [
      PaywallBenefitId.topics,
      PaywallBenefitId.pushes,
      PaywallBenefitId.history,
      PaywallBenefitId.appIcons,
    ]);
    // The weekly delivery check is a Hosted benefit with no line and
    // preview for a layout yet. Every other one is listed, in order.
    expect(HostedBenefit.all.last.id, HostedBenefitId.weeklyCheck);
    expect(
      hosted.map((b) => b.id.name),
      HostedBenefit.all
          .where((b) => b.id != HostedBenefitId.weeklyCheck)
          .map((b) => b.id.name),
    );
    expect(hosted.every((b) => b.inThisBuild), isTrue);
    expect(paywallBenefitsFor(PaywallProduct.hosted), hasLength(4));
  });

  test('Hosted lines read their numbers from the one place', () {
    final lines = paywallBenefitsFor(
      PaywallProduct.hosted,
    ).map((b) => b.line).join('\n');
    expect(lines, contains(HostedBenefit.args['hosted_p4_daily']));
    expect(lines, contains('$hostedHistoryDays'));
    expect(lines, isNot(contains('{')));
    // No Hosted number is written into a paywall kit string.
    for (final entry in strings.entries) {
      if (!entry.key.startsWith('paywall_kit.')) continue;
      expect(entry.value, isNot(contains('$hostedP4Daily')), reason: entry.key);
      expect(
        entry.value,
        isNot(contains('$hostedHistoryDays')),
        reason: entry.key,
      );
    }
  });

  test('Pro lists four benefits, in the order they are sold', () {
    final pro = allPaywallBenefits
        .where((b) => b.product == PaywallProduct.pro)
        .toList();
    expect(pro.map((b) => b.id), [
      PaywallBenefitId.wakeUpChallenges,
      PaywallBenefitId.widgets,
      // The weekly check left this list when Hosted began to unlock it.
      PaywallBenefitId.customSounds,
      PaywallBenefitId.customAlarmScreens,
    ]);
  });

  test('a store build lists only the two Pro benefits the app has '
      'today', () {
    expect(paywallBenefitsFor(PaywallProduct.pro).map((b) => b.id), [
      PaywallBenefitId.widgets,
      // Four fixed looks and the person's own photo are in the app.
      PaywallBenefitId.customAlarmScreens,
    ]);
    final waiting = allPaywallBenefits
        .where((b) => !b.inThisBuild)
        .map((b) => b.id);
    expect(waiting, [
      PaywallBenefitId.wakeUpChallenges,
      PaywallBenefitId.customSounds,
    ]);
  });

  test('no benefit is listed under both products', () {
    final ids = allPaywallBenefits.map((b) => b.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    // The weekly check has no entry on either layout list today: Pro does
    // not unlock it, and Hosted has no line and preview for it yet.
    expect(
      ids.toSet(),
      {...PaywallBenefitId.values}..remove(PaywallBenefitId.reliabilityChecks),
    );
  });

  test('widgets are drawn with the widgets preview', () {
    expect(
      allPaywallBenefits
          .firstWhere((b) => b.id == PaywallBenefitId.widgets)
          .previewId,
      PaywallPreviewId.widgets,
    );
  });

  test('every benefit has its own id and its own preview', () {
    final all = allPaywallBenefits;
    expect(all.map((b) => b.id).toSet(), hasLength(all.length));
    expect(all.map((b) => b.previewId).toSet(), hasLength(all.length));
    // Every preview but the weekly check one is drawn by some benefit.
    expect(
      all.map((b) => b.previewId).toSet(),
      {...PaywallPreviewId.values}..remove(PaywallPreviewId.weeklyCheck),
    );
  });

  test('no Pro string says how Pro is paid', () {
    final banned = RegExp(
      'lifetime|one-time|one time|per month|subscription|a month|a year',
      caseSensitive: false,
    );
    for (final benefit in allPaywallBenefits) {
      if (benefit.product != PaywallProduct.pro) continue;
      for (final key in [benefit.titleKey, benefit.lineKey]) {
        expect(banned.hasMatch(strings[key]!), isFalse, reason: key);
      }
    }
    for (final key in [
      'paywall_kit.legal_pro',
      'paywall_kit.done_pro',
      'paywall_kit.name_pro',
      'paywall_kit.button_get',
      'paywall_kit.button_get_price',
      'paywall_kit.not_on_sale',
      'paywall_hero.headline_pro',
    ]) {
      expect(banned.hasMatch(strings[key]!), isFalse, reason: key);
    }
  });

  test('a product is read from its key, and an unknown one is Hosted', () {
    expect(PaywallProduct.parse('pro'), PaywallProduct.pro);
    expect(PaywallProduct.parse('hosted'), PaywallProduct.hosted);
    expect(PaywallProduct.parse(null), PaywallProduct.hosted);
    expect(PaywallProduct.parse('gold'), PaywallProduct.hosted);
  });
}
