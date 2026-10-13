// Walks every place that opens a paywall, as the app opens it with no
// settings at all, and saves one PNG per place and product. Off the device,
// made-up buy model (real prices from the price book), no server.
//
//   fvm flutter test tool/capture_paywall_walk.dart --dart-define=OUT=<folder>
//
// The opening comes from a real PaywallDoor with nothing pinned. Its
// location is read back the way the router reads it. The layout is mounted
// with the lead, headline and facts that location carries, rests about a
// second, and is saved. Intros are skipped and nothing is bought.
//
// Developer tool, uncommitted.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead_facts.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/walk');
const _only = String.fromEnvironment('ONLY');
const double _settle = int.fromEnvironment('SETTLE', defaultValue: 12) / 10;

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _normal = _Phone('390x844', Size(390, 844), 47, 34);
const _narrow = _Phone('320x568', Size(320, 568), 20, 0);

class _SilentCues extends PaywallCues {
  const _SilentCues();

  @override
  void play(PaywallCue cue) {}
}

/// One pair to walk. [hosted] is the source that opens Hosted for the
/// place, [pro] the source that opens Pro, null when none does.
class _Pair {
  const _Pair(this.product, this.place, {this.hosted, this.pro, this.extra});

  final PaywallProduct product;
  final PaywallPlace place;
  final PaywallSource? hosted;
  final ProPackSheetSource? pro;

  /// Why the pair is in the walk though the brief did not list it.
  final String? extra;
}

const PaywallProduct _hosted = PaywallProduct.hosted;
const PaywallProduct _pro = PaywallProduct.pro;

const _pairs = <_Pair>[
  _Pair(
    _hosted,
    PaywallPlace.criticalLimit,
    hosted: PaywallSource.createTopicCard,
  ),
  _Pair(_hosted, PaywallPlace.history, hosted: PaywallSource.history),
  _Pair(_hosted, PaywallPlace.appIcons, hosted: PaywallSource.appIcon),
  _Pair(_hosted, PaywallPlace.weeklyCheck, hosted: PaywallSource.reliability),
  _Pair(_hosted, PaywallPlace.plan, hosted: PaywallSource.settingsPlan),
  _Pair(_hosted, PaywallPlace.nudge, hosted: PaywallSource.askSheet),
  _Pair(
    _hosted,
    PaywallPlace.planEnding,
    hosted: PaywallSource.planSheetEnding,
  ),
  _Pair(_hosted, PaywallPlace.planEnded, hosted: PaywallSource.planSheetEnded),
  _Pair(
    _hosted,
    PaywallPlace.widgets,
    hosted: PaywallSource.homeWidgets,
    extra: 'paywallPlaceOf maps homeWidgets to widgets for Hosted',
  ),
  _Pair(
    _hosted,
    PaywallPlace.ownSounds,
    hosted: PaywallSource.personalizeSound,
    extra: 'paywallPlaceOf maps personalizeSound to ownSounds for Hosted',
  ),
  _Pair(_pro, PaywallPlace.widgets, pro: ProPackSheetSource.homeWidgets),
  _Pair(_pro, PaywallPlace.ownSounds, pro: ProPackSheetSource.sounds),
  _Pair(_pro, PaywallPlace.alarmLook, pro: ProPackSheetSource.personalizeLook),
  _Pair(
    _pro,
    PaywallPlace.challenge,
    pro: ProPackSheetSource.personalizeChallenge,
  ),
  _Pair(_pro, PaywallPlace.plan, pro: ProPackSheetSource.settingsPlan),
  _Pair(
    _pro,
    PaywallPlace.criticalLimit,
    pro: ProPackSheetSource.createTopicCard,
    extra: 'paywallPlaceOfPro maps createTopicCard to criticalLimit',
  ),
  _Pair(
    _pro,
    PaywallPlace.history,
    pro: ProPackSheetSource.history,
    extra: 'paywallPlaceOfPro maps history to history',
  ),
  _Pair(
    _pro,
    PaywallPlace.appIcons,
    pro: ProPackSheetSource.appIcon,
    extra: 'paywallPlaceOfPro maps appIcon to appIcons',
  ),
  _Pair(
    _pro,
    PaywallPlace.weeklyCheck,
    pro: ProPackSheetSource.reliability,
    extra: 'paywallPlaceOfPro maps reliability to weeklyCheck',
  ),
];

/// The pairs that also get dark and the narrow phone.
bool _isExtraSized(_Pair p) =>
    (p.product == _pro &&
        (p.place == PaywallPlace.alarmLook || p.place == PaywallPlace.plan)) ||
    (p.product == _hosted &&
        (p.place == PaywallPlace.plan ||
            p.place == PaywallPlace.criticalLimit));

/// Made-up facts for the critical limit card: two on, limit two, a topic.
const _facts = PaywallLeadFacts(used: 2, limit: 2, topicName: 'payments-db');

PaywallDoor _door() => PaywallDoor(
  developer: (_) => null,
  hasSeenFalseAlarm: () => false,
  markFalseAlarmSeen: () async {},
);

/// The location the app opens for [pair], from a door with nothing pinned.
Future<String> _locationFor(_Pair pair) async {
  final door = _door();
  if (pair.product == _pro) return door.proLayoutLocation(pair.pro!);
  if (pair.place == PaywallPlace.planEnding) {
    // The app counts the person's numbers first; nothing is counted here.
    return door.leavingLocation(DateTime(2026, 10, 21));
  }
  return door.hostedLocation(pair.hosted!, facts: _facts);
}

const _frame = Duration(milliseconds: 16);

Future<void> _stepTo(WidgetTester tester, double to) async {
  var at = Duration.zero;
  final end = Duration(microseconds: (to * 1e6).round());
  while (at < end) {
    await tester.pump(_frame);
    at += _frame;
  }
}

Future<void> _save(GlobalKey key, String path, WidgetTester tester) =>
    tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
    if (!getIt.isRegistered<PaywallCues>()) {
      getIt.registerSingleton<PaywallCues>(const _SilentCues());
    }
  });

  for (final pair in _pairs) {
    final sizes = _isExtraSized(pair)
        ? [
            (_normal, ThemeMode.light),
            (_normal, ThemeMode.dark),
            (_narrow, ThemeMode.light),
          ]
        : [(_normal, ThemeMode.light)];
    for (final (phone, mode) in sizes) {
      testWidgets(
        'walk ${pair.product.key} ${pair.place.name} '
        '${phone.name} ${mode.name}',
        (tester) async {
          final location = await tester.runAsync(() => _locationFor(pair));
          final uri = Uri.parse(location!);
          final query = uri.queryParameters;
          final layout =
              PaywallLayoutId.fromKey(uri.pathSegments.last) ??
              paywallFallbackLayout;
          final lead = paywallLeadFromQuery(query);
          final headline = PaywallHeadlineVariant.parse(query['headline']);
          final leaving = PaywallLeaving.fromQuery(query);
          final own = lead?.benefit == PaywallBenefitId.history
              ? HistoryOwn.fromQuery(query)
              : null;
          final source = PaywallSource.parse(query['source']);
          final name =
              '${pair.product.key}__${pair.place.name}__${layout.key}__'
              '${phone.name}_${mode.name}';
          if (_only.isNotEmpty && !_only.split(',').any(name.contains)) return;
          print(
            'WALK $name | source=${query['source']} | lead=${query['lead']} '
            '| headline=${query['headline']} | intro=${query['intro']} '
            '| thanks=${query['thanks']} | outro=${query['outro']} '
            '| leaving=${leaving != null} | extra=${pair.extra}',
          );
          // The opening itself, for the record.
          print('WALKLOC $name $location');

          final errors = <String>[];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString());
          debugDisableShadows = false;
          const dpr = 2.0;
          tester.view.physicalSize = phone.size * dpr;
          tester.view.devicePixelRatio = dpr;
          tester.view.padding = FakeViewPadding(
            top: phone.top * dpr,
            bottom: phone.bottom * dpr,
          );
          tester.view.viewPadding = tester.view.padding;
          addTearDown(tester.view.reset);

          final boundaryKey = GlobalKey();
          try {
            final view = PaywallLayoutView(
              layout: layout,
              product: pair.product,
              thanks:
                  PaywallThanksId.fromKey(query['thanks']) ??
                  PaywallThanksId.none,
              outro:
                  PaywallOutroId.fromKey(query['outro']) ?? PaywallOutroId.none,
            );
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildLightTheme(),
                darkTheme: buildDarkTheme(),
                themeMode: mode,
                builder: (context, child) =>
                    RepaintBoundary(key: boundaryKey, child: child),
                home: Scaffold(
                  body: BlocProvider<PaywallBuyCubit>(
                    create: (_) {
                      final cubit = DemoPaywallBuyCubit(pair.product);
                      cubit.load().ignore();
                      return cubit;
                    },
                    child: PaywallRouteInfo(
                      layout: layout,
                      source: source,
                      lead: lead,
                      headline: headline,
                      historyOwn: own,
                      leaving: leaving,
                      child: leaving?.atRest ?? false
                          ? PaywallStill(child: view)
                          : view,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await _stepTo(tester, _settle);

            final problems = <String>[];
            final screen = Offset.zero & phone.size;
            final cross = find.byType(AppDismissCross);
            if (cross.evaluate().isEmpty ||
                !screen.contains(tester.getRect(cross.first).topLeft) ||
                !screen.contains(tester.getRect(cross.first).bottomRight)) {
              problems.add('The close cross is not on screen.');
            }
            for (final s in tester.stateList<ScrollableState>(
              find.byType(Scrollable),
            )) {
              if (s.position.maxScrollExtent > 0.5) {
                problems.add(
                  'Scrolls by '
                  '${s.position.maxScrollExtent.toStringAsFixed(1)}.',
                );
              }
            }
            await _save(boundaryKey, '$_out/$name.png', tester);
            print('SAVED $_out/$name.png');
            for (final p in [...errors, ...problems]) {
              print('PROBLEM $name: $p');
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 2));
            debugDisableShadows = true;
            FlutterError.onError = oldHandler;
          }
        },
      );
    }
  }
}
