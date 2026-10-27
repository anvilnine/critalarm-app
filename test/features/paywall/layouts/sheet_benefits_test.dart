import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_composition.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_lines.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/capture_fonts.dart';
import '../../../helpers/load_translations.dart';

class _SilentCues extends PaywallCues {
  @override
  void play(PaywallCue cue) {}
}

/// A phone: its size and the status bar and home indicator it keeps.
class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phones = [
  _Phone('390x844', Size(390, 844), 47, 34),
  _Phone('320x568', Size(320, 568), 20, 0),
];

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  setUp(() => getIt.registerSingleton<PaywallCues>(_SilentCues()));
  tearDown(() async => getIt.reset());

  /// Opens the Sheet and lets its entrance finish.
  Future<void> open(
    WidgetTester tester, {
    required PaywallProduct product,
    required PaywallLead? lead,
    required _Phone phone,
    required double textScale,
  }) async {
    const dpr = 2.0;
    tester.view.physicalSize = phone.size * dpr;
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = FakeViewPadding(
      top: phone.top * dpr,
      bottom: phone.bottom * dpr,
    );
    tester.view.viewPadding = tester.view.padding;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: BlocProvider<PaywallBuyCubit>(
            create: (_) {
              final cubit = DemoPaywallBuyCubit(product);
              unawaited(cubit.load());
              return cubit;
            },
            child: PaywallRouteInfo(
              layout: PaywallLayoutId.sheet,
              source: PaywallSource.direct,
              lead: lead,
              child: PaywallLayoutView(
                layout: PaywallLayoutId.sheet,
                product: product,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const leads = <String, PaywallLead?>{
    'no lead': null,
    'the critical limit': PaywallLead(
      benefit: PaywallBenefitId.topics,
      usedCount: 2,
      limitCount: 2,
      topicName: 'payments-db',
    ),
  };

  for (final product in PaywallProduct.values) {
    for (final MapEntry(key: leadName, value: lead) in leads.entries) {
      for (final phone in _phones) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'the ${product.key} sheet lists every benefit whole: $leadName, '
            '${phone.name}, text $scale',
            (tester) async {
              await open(
                tester,
                product: product,
                lead: lead,
                phone: phone,
                textScale: scale,
              );
              final offer = PaywallOffer.from(product: product, lead: lead);
              // With a lead, the headline and the picture say the first
              // benefit and the list under "Also included" has the others.
              final listed = offer.lead == null
                  ? offer.benefits
                  : offer.benefits.skip(1).toList();
              expect(listed, isNotEmpty);

              // No fade drawn over the words.
              final words = find.byType(HeroComposition);
              expect(
                find.descendant(of: words, matching: find.byType(ShaderMask)),
                findsNothing,
              );

              final scroll = find.descendant(
                of: words,
                matching: find.byType(SingleChildScrollView),
              );
              final viewport = tester.getRect(scroll);
              bool isWhole(Rect rect) =>
                  rect.top >= viewport.top - 0.5 &&
                  rect.bottom <= viewport.bottom + 0.5;

              // The buy button stays on screen, under the words.
              final buy = tester.getRect(find.byType(PaywallBuyBlock));
              expect(buy.bottom, lessThanOrEqualTo(phone.size.height));
              expect(viewport.bottom, lessThanOrEqualTo(buy.top + 0.5));

              final lines = {
                for (final b in listed)
                  b.id: find.descendant(
                    of: words,
                    matching: find.text(heroLineFor(b)),
                  ),
              };
              for (final MapEntry(:key, value: line) in lines.entries) {
                expect(line, findsOneWidget, reason: '$key is listed');
                // Whole means fully drawn: no Opacity above it under 1.
                for (final opacity in tester.widgetList<Opacity>(
                  find.ancestor(of: line, matching: find.byType(Opacity)),
                )) {
                  expect(opacity.opacity, 1, reason: '$key is not faded');
                }
              }

              // Each line is whole on screen at some point of the scroll,
              // from the top of the words to their foot.
              final position = tester
                  .state<ScrollableState>(
                    find.descendant(
                      of: scroll,
                      matching: find.byType(Scrollable),
                    ),
                  )
                  .position;
              final seen = <PaywallBenefitId>{};
              final extent = position.maxScrollExtent;
              for (var at = 0.0; ; at += 12) {
                position.jumpTo(at.clamp(0, extent));
                await tester.pump();
                for (final MapEntry(:key, value: line) in lines.entries) {
                  if (isWhole(tester.getRect(line))) seen.add(key);
                }
                if (at >= extent) break;
              }
              expect(
                seen,
                lines.keys.toSet(),
                reason: 'every line reachable, scroll extent $extent',
              );
              // At the foot the last line ends clear of the buy block.
              expect(
                isWhole(tester.getRect(lines[listed.last.id]!)),
                isTrue,
                reason: 'the last line is whole at the foot',
              );
            },
          );
        }
      }
    }
  }
}
