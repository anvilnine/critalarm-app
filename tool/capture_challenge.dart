// Captures the wake-up challenge off the device, with the mock API and the
// developer plan switches.
//
//   fvm flutter test tool/capture_challenge.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true
//
// For 390 by 844 and 375 by 667, light and dark, at the default text size
// and 1.3, it writes one PNG per state:
//   challenge_keyboard   the real alarm route: acknowledged, At my desk
//                        tapped with a challenge owed, the keyboard up
//   challenge_midhold    the same, four seconds into the hold on the way
//                        out
//   challenge_reader     the same with a screen reader running, where the
//                        way out is a plain button. It also writes
//                        `<name>.semantics.txt`, the tree in the order a
//                        screen reader walks it
//   topic_row_locked     the topic page, nothing held
//   topic_row_open       the topic page, Pro held, a challenge picked
//   strip_locked         Personalize, nothing held
//   strip_trying         Personalize, nothing held, the locked chip tapped
//   strip_open           Personalize, Pro held, the challenge picked
//   try_page             the try on the whole screen
//
// For KIND=scratch_card, `challenge_keyboard` is the card rubbed until it
// is revealed, with the number pad up, and there are three more:
//   challenge_covered    the card as it opens, nothing rubbed, no keyboard
//   challenge_half       one swipe across the card, the code still hidden
//   challenge_button     five seconds of rubbing with nothing revealed: the
//                        button that shows the code
//
// It also walks the step itself on the real alarm route, at 390 by 844, and
// prints one line per walk (`FLOW ...`). These are not pictures:
//   typing the topic name closes the incident
//   holding the way out for ten seconds closes it, and 9.9 seconds does not
//   the cross goes back to the acknowledged screen and closes nothing
//   with a screen reader, one tap on the way out closes it
//   without Pro, or with no challenge set, At my desk closes at once
//
// Optional:
//   --dart-define=OUT=<folder>   where the files go (default
//                                build/challenge_shots)
//   --dart-define=ONLY=<part>,<part>
//                                capture only the files whose name has one
//                                of these parts
//   --dart-define=KIND=<id>     the challenge: type_topic_name (default),
//                                type_alert_title, ops_math or scratch_card
//   --dart-define=STYLE=<id>     the look of the alarm screen the
//                                challenge step is captured in, for
//                                example `minimal`
//
// A capture fails when anything overflows.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_step.dart';
import 'package:critalarm/features/challenges/presentation/challenge_try.dart';
import 'package:critalarm/features/challenges/presentation/hold_to_skip_button.dart';
import 'package:critalarm/features/challenges/presentation/topic_challenge_row.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/personalize/try_bar.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/challenge_shots',
);
const _only = String.fromEnvironment('ONLY');

/// The look of the alarm screen to capture the challenge in, saved as the
/// phone's (`AlarmStyleChoices.defaultKey`). Empty leaves the standard
/// look. A capture that holds the plan for challenges holds it for looks
/// too: both are unlocked by the same one.
const _style = String.fromEnvironment('STYLE');

/// Name, size, top inset, bottom inset, keyboard height.
const _phones = <(String, Size, double, double, double)>[
  ('390x844', Size(390, 844), 47, 34, 336),
  ('375x667', Size(375, 667), 20, 0, 260),
];

const _topic = 'prod-db';

/// The challenge to capture, by id: `type_topic_name` (default),
/// `type_alert_title`, `ops_math` or `scratch_card`.
const _kindId = String.fromEnvironment(
  'KIND',
  defaultValue: 'type_topic_name',
);
final ChallengeKind _kind = ChallengeKind.fromId(_kindId)!;

/// Half an answer for the capture, so the field shows typing.
String get _partial => switch (_kind) {
  ChallengeKind.typeTopicName => 'prod',
  ChallengeKind.typeAlertTitle => 'primary da',
  ChallengeKind.opsMath => '3',
  // Typed from the card itself: see [_shownCode].
  ChallengeKind.scratchCard => '',
  // Nothing is typed: see [_isShake].
  ChallengeKind.shake => '',
};

bool get _isScratch => _kind == ChallengeKind.scratchCard;

/// The keyboard as a challenge opens. A scratch card opens with none: its
/// number pad comes up once the card is revealed, which a screen reader
/// gets from the start.
double _keyboardAtOpen(double keyboard, {bool hasReader = false}) =>
    _isScratch && !hasReader ? 0 : keyboard;

/// The four digits printed on the scratch card.
final Finder _cardCode = find.byWidgetPredicate(
  (widget) =>
      widget is Text && RegExp(r'^[0-9]{4}$').hasMatch(widget.data ?? ''),
);

String _shownCode(WidgetTester tester) => tester.widget<Text>(_cardCode).data!;

/// One swipe across the scratch card, [dy] points under its middle.
Future<void> _swipeCard(WidgetTester tester, double dy) async {
  final middle = tester.getCenter(_cardCode);
  final gesture = await tester.startGesture(middle + Offset(-130, dy));
  for (var i = 0; i < 13; i++) {
    await gesture.moveBy(const Offset(20, 0));
  }
  await gesture.up();
  await tester.pump();
}

/// Rubs the scratch card until it is revealed, then brings the number pad
/// up.
Future<void> _revealCard(WidgetTester tester, double keyboard) async {
  await _swipeCard(tester, -16);
  expect(find.byType(TextField), findsNothing);
  await _swipeCard(tester, 16);
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(TextField), findsOneWidget);
  _raiseKeyboard(tester, keyboard);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The keyboard stand-in of the challenge that is open.
ValueNotifier<double>? _keyboardShown;

void _raiseKeyboard(WidgetTester tester, double keyboard) {
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  _keyboardShown?.value = keyboard;
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(
        File('assets/fonts/$file').readAsBytes().then(
          (bytes) => ByteData.view(bytes.buffer),
        ),
      );
    }
    await loader.load();
  }

  await family('Bricolage Grotesque', [
    'BricolageGrotesque-Bold.ttf',
    'BricolageGrotesque-ExtraBold.ttf',
  ]);
  await family('Instrument Sans', [
    'InstrumentSans-Regular.ttf',
    'InstrumentSans-Medium.ttf',
    'InstrumentSans-SemiBold.ttf',
    'InstrumentSans-Bold.ttf',
  ]);
  await family('JetBrains Mono', [
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-SemiBold.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
}

Future<void> _hold({required bool isPro}) async {
  await getIt<DevProSwitch>().setPro(isPro: false);
  await getIt<ProPackDevSwitch>().setHeld(isHeld: isPro);
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    // Reads that go through real I/O land between the frames.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Pumps [location] at [size] and hands back the key of what to capture.
Future<GlobalKey> _open(
  WidgetTester tester, {
  required String location,
  required Size size,
  required double topInset,
  required double bottomInset,
  required ThemeMode mode,
  required double scale,
  bool isStill = true,
  ValueNotifier<double>? keyboard,
}) async {
  const dpr = 2.0;
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: topInset * dpr,
    bottom: bottomInset * dpr,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
        BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        routerConfig: buildRouter(initialLocation: location),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: isStill,
          ),
          child: RepaintBoundary(
            key: boundaryKey,
            child: keyboard == null
                ? child
                : Stack(
                    children: [
                      ?child,
                      // Where the keyboard is, so the picture shows what
                      // is left above it.
                      ValueListenableBuilder<double>(
                        valueListenable: keyboard,
                        builder: (context, height, _) => Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: height,
                          child: const ColoredBox(
                            color: Color(0xFFD1D3D9),
                            child: Center(
                              child: Text(
                                'keyboard',
                                style: TextStyle(
                                  color: Color(0xFF6B6E76),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return boundaryKey;
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name, {
  required bool isGood,
  String? semantics,
}) => tester.runAsync(() async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  if (semantics != null) {
    await File('$_out/$name.semantics.txt').writeAsString(semantics);
  }
  print('${isGood ? 'FIT ' : 'BAD '} ${file.path}');
});

/// The alarm route, acknowledged, with At my desk tapped.
Future<GlobalKey> _openChallenge(
  WidgetTester tester, {
  required Size size,
  required double topInset,
  required double bottomInset,
  required double keyboard,
  required ThemeMode mode,
  required double scale,
  bool isPro = true,
  bool hasChoice = true,
  bool expectsChallenge = true,
}) async {
  getIt<MockServer>().loadFixture(FaceState.alarmed);
  await _hold(isPro: isPro);
  await getIt<ChallengeChoices>().setChoice(
    _topic,
    hasChoice ? _kind : null,
  );
  final shown = ValueNotifier<double>(0);
  _keyboardShown = shown;
  addTearDown(() {
    _keyboardShown = null;
    shown.dispose();
  });
  final key = await _open(
    tester,
    location: '/alarm',
    size: size,
    topInset: topInset,
    bottomInset: bottomInset,
    mode: mode,
    scale: scale,
    keyboard: shown,
  );
  // "I'm up", through the same call the button makes. One tap, no
  // challenge in front of it.
  await tester.runAsync(() => CriticalAlarmCubit.current!.acknowledge());
  await _settle(tester, 3);
  expect(find.byType(ChallengeStep), findsNothing);
  // The keyboard, as the screen sees it.
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  shown.value = keyboard;
  await tester.tap(
    find.text(LocaleKeys.critical_alarm_at_my_desk_button.tr()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  if (expectsChallenge) expect(find.byType(ChallengeStep), findsOneWidget);
  return key;
}

/// Lets the close reach the mock server and the screen redraw.
Future<void> _afterClose(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

CriticalAlarmStatus _status() => CriticalAlarmCubit.current!.state.status;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await configureDependencies();
    await _loadFonts();
    if (_style.isNotEmpty) {
      await getIt<SharedPreferences>().setString(
        'alarm_style_default',
        _style,
      );
    }
  });

  void capture(
    String name,
    Future<void> Function(WidgetTester tester, List<String> errors) body,
  ) {
    if (!_wanted(name)) return;
    testWidgets('capture $name', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());
      debugDisableShadows = false;
      try {
        await body(tester, errors);
        // Past the follow-up an acknowledge may open, so no timer
        // outlives the capture.
        await tester.pump(const Duration(seconds: 2));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
        await _hold(isPro: false);
        final choices = getIt<ChallengeChoices>();
        await choices.setChoice(_topic, null);
        await choices.setDefaultForNewTopics(null);
      }
    });
  }

  for (final (sizeName, size, top, bottom, keyboard) in _phones) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, 1.3]) {
        final tail = '${sizeName}_${mode.name}_${scale}x';

        capture('challenge_keyboard_$tail', (tester, errors) async {
          final key = await _openChallenge(
            tester,
            size: size,
            topInset: top,
            bottomInset: bottom,
            keyboard: _keyboardAtOpen(keyboard),
            mode: mode,
            scale: scale,
          );
          if (_isScratch) await _revealCard(tester, keyboard);
          await tester.enterText(
            find.byType(TextField),
            _isScratch ? _shownCode(tester).substring(0, 2) : _partial,
          );
          await tester.pump();
          await _save(
            tester,
            key,
            'challenge_keyboard_$tail',
            isGood: errors.isEmpty,
          );
        });

        if (_isScratch) {
          for (final state in ['covered', 'half', 'button']) {
            capture('challenge_${state}_$tail', (tester, errors) async {
              final key = await _openChallenge(
                tester,
                size: size,
                topInset: top,
                bottomInset: bottom,
                keyboard: 0,
                mode: mode,
                scale: scale,
              );
              expect(find.byType(TextField), findsNothing);
              final reveal = find.text(
                LocaleKeys.challenges_scratch_card_reveal.tr(),
              );
              if (state == 'half') {
                await _swipeCard(tester, -16);
              } else if (state == 'button') {
                // A finger on one spot, which clears next to nothing.
                final gesture = await tester.startGesture(
                  tester.getCenter(_cardCode) + const Offset(-140, -40),
                );
                await tester.pump(const Duration(milliseconds: 4900));
                expect(reveal, findsNothing);
                await tester.pump(const Duration(milliseconds: 200));
                await gesture.up();
                await tester.pump();
                expect(reveal, findsOneWidget);
              }
              // Still covered: nothing to type into yet.
              expect(find.byType(TextField), findsNothing);
              await _save(
                tester,
                key,
                'challenge_${state}_$tail',
                isGood: errors.isEmpty,
              );
            });
          }
        }

        capture('challenge_midhold_$tail', (tester, errors) async {
          final key = await _openChallenge(
            tester,
            size: size,
            topInset: top,
            bottomInset: bottom,
            keyboard: _keyboardAtOpen(keyboard),
            mode: mode,
            scale: scale,
          );
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(HoldToSkipButton)),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 4));
          // Still the challenge: four seconds is not ten.
          expect(find.byType(ChallengeStep), findsOneWidget);
          await _save(
            tester,
            key,
            'challenge_midhold_$tail',
            isGood: errors.isEmpty,
          );
          await gesture.up();
          await tester.pump();
        });

        capture('challenge_reader_$tail', (tester, errors) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(accessibleNavigation: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final semantics = tester.ensureSemantics();
          try {
            final key = await _openChallenge(
              tester,
              size: size,
              topInset: top,
              bottomInset: bottom,
              keyboard: _keyboardAtOpen(keyboard, hasReader: true),
              mode: mode,
              scale: scale,
            );
            final tree = tester
                .binding
                .renderViews
                .first
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!
                .toStringDeep()
                .replaceAll(RegExp('#[0-9a-f]+'), '#');
            await _save(
              tester,
              key,
              'challenge_reader_$tail',
              isGood: errors.isEmpty,
              semantics: tree,
            );
          } finally {
            semantics.dispose();
          }
        });

        for (final isPro in [false, true]) {
          final state = isPro ? 'open' : 'locked';
          capture('topic_row_${state}_$tail', (tester, errors) async {
            getIt<MockServer>().loadFixture(FaceState.calm);
            await _hold(isPro: isPro);
            if (isPro) {
              await getIt<ChallengeChoices>().setChoice(_topic, _kind);
            }
            final key = await _open(
              tester,
              location: '/topics/$_topic',
              size: size,
              topInset: top,
              bottomInset: bottom,
              mode: mode,
              scale: scale,
              // The topic page sizes a block with a zero-length animation
              // under reduce motion, which lays out twice in this harness.
              isStill: false,
            );
            final row = find.byType(TopicChallengeRow);
            await tester.ensureVisible(row);
            await tester.pump(const Duration(milliseconds: 300));
            await _save(
              tester,
              key,
              'topic_row_${state}_$tail',
              isGood: errors.isEmpty,
            );
          });
        }

        for (final state in ['locked', 'trying', 'open', 'try_page']) {
          final name = state == 'try_page' ? 'try_page' : 'strip_$state';
          capture('${name}_$tail', (tester, errors) async {
            final isPro = state == 'open';
            await _hold(isPro: isPro);
            if (isPro) {
              await getIt<ChallengeChoices>().setDefaultForNewTopics(_kind);
            }
            final key = await _open(
              tester,
              location: '/settings/personalize',
              size: size,
              topInset: top,
              bottomInset: bottom,
              mode: mode,
              scale: scale,
            );
            final chip = find.byKey(ValueKey('challenge-${_kind.id}'));
            if (state != 'locked') {
              // What a tap on the chip calls once the plan is read. In
              // this harness the access layer is ready for the first
              // capture only, so the tap is stood in for.
              BlocProvider.of<PersonalizeCubit>(
                tester.element(find.byType(PersonalizeTryBar)),
              ).tryOption(
                PersonalizeTry(
                  AppFeature.wakeUpChallenges,
                  optionId: _kind.id,
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              expect(find.byType(ChallengePicture), findsOneWidget);
            }
            if (state == 'try_page') {
              await tester.tap(find.byType(ChallengePicture));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
              expect(find.byType(ChallengeTryPage), findsOneWidget);
            } else {
              await tester.ensureVisible(chip);
              await tester.pump(const Duration(milliseconds: 300));
            }
            await _save(tester, key, '${name}_$tail', isGood: errors.isEmpty);
          });
        }
      }
    }
  }

  // The step itself, walked on the real alarm route.
  final (_, flowSize, flowTop, flowBottom, flowKeyboard) = _phones.first;
  Future<GlobalKey> flow(
    WidgetTester tester, {
    bool isPro = true,
    bool hasChoice = true,
    bool expectsChallenge = true,
  }) => _openChallenge(
    tester,
    size: flowSize,
    topInset: flowTop,
    bottomInset: flowBottom,
    keyboard: _keyboardAtOpen(flowKeyboard),
    mode: ThemeMode.light,
    scale: 1,
    isPro: isPro,
    hasChoice: hasChoice,
    expectsChallenge: expectsChallenge,
  );

  capture('flow_type_closes', (tester, errors) async {
    if (_kind != ChallengeKind.typeTopicName) return;
    await flow(tester);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    // A wrong try costs nothing and closes nothing.
    await tester.enterText(find.byType(TextField), 'prod-d');
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsOneWidget);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    // Capitals and outer spaces do not matter.
    await tester.enterText(find.byType(TextField), ' Prod-DB ');
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.closed);
    print('FLOW typing the topic name closed the incident');
  });

  capture('flow_title_closes', (tester, errors) async {
    if (_kind != ChallengeKind.typeAlertTitle) return;
    await flow(tester);
    await tester.enterText(find.byType(TextField), 'primary database');
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsOneWidget);
    // Punctuation at the edges, capitals and extra spaces do not matter.
    await tester.enterText(
      find.byType(TextField),
      '  (PRIMARY)  database, down. ',
    );
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.closed);
    print('FLOW typing the first words of the title closed the incident');
  });

  capture('flow_scratch_closes', (tester, errors) async {
    if (!_isScratch) return;
    await flow(tester);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    await _revealCard(tester, flowKeyboard);
    final code = _shownCode(tester);
    // A wrong code costs nothing and closes nothing.
    final wrong = code == '1111' ? '2222' : '1111';
    await tester.enterText(find.byType(TextField), wrong);
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsOneWidget);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    expect(
      find.text(LocaleKeys.challenges_scratch_card_wrong.tr()),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), code);
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.closed);
    print('FLOW rubbing the card and typing its code closed the incident');
  });

  capture('flow_scratch_button', (tester, errors) async {
    if (!_isScratch) return;
    await flow(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(_cardCode) + const Offset(-140, -40),
    );
    await tester.pump(const Duration(milliseconds: 5100));
    await gesture.up();
    await tester.pump();
    await tester.tap(find.text(LocaleKeys.challenges_scratch_card_reveal.tr()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TextField), findsOneWidget);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    print('FLOW after five seconds of rubbing, the button showed the code');
  });

  // A title of many words, to show the first three set apart from the rest.
  // Only for type_alert_title.
  if (_kind == ChallengeKind.typeAlertTitle) {
    for (final (mode, scale) in [
      (ThemeMode.light, 1.0),
      (ThemeMode.dark, 1.3),
    ]) {
      final name = 'challenge_longtitle_375x667_${mode.name}_${scale}x';
      capture(name, (tester, errors) async {
        const size = Size(375, 667);
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        tester.view.padding = const FakeViewPadding(top: 40);
        tester.view.viewPadding = tester.view.padding;
        tester.view.viewInsets = const FakeViewPadding(bottom: 520);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: key, child: child),
            ),
            home: SeverityScope(
              mode: SeverityMode.ack,
              child: Builder(
                builder: (context) => Material(
                  color: context.appColors.canvas,
                  child: AmbientScope(
                    child: ChallengeStep(
                      challenge: challengeOf(ChallengeKind.typeAlertTitle)!,
                      incident: const ChallengeIncident(
                        topic: 'prod-db',
                        alertTitle:
                            'Replication lag above 300 seconds on the '
                            'primary database in eu-west-1 after the '
                            'nightly vacuum job started late',
                      ),
                      wayOut: ChallengeWayOut.hold,
                      onPassed: () {},
                      onSkip: () {},
                      onLeave: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'replication lag');
        await tester.pump();
        await _save(tester, key, name, isGood: errors.isEmpty);
      });
    }
  }

  capture('flow_hold_closes', (tester, errors) async {
    await flow(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToSkipButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 9900));
    expect(find.byType(ChallengeStep), findsOneWidget);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    await tester.pump(const Duration(milliseconds: 200));
    await _afterClose(tester);
    await gesture.up();
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.closed);
    print('FLOW a ten second hold closed the incident, 9.9 seconds did not');
  });

  capture('flow_hold_let_go', (tester, errors) async {
    await flow(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToSkipButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await gesture.up();
    await tester.pump();
    // Letting go starts over: six more seconds is not ten.
    final again = await tester.startGesture(
      tester.getCenter(find.byType(HoldToSkipButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(ChallengeStep), findsOneWidget);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    await again.up();
    await tester.pump();
    print('FLOW letting go of the hold started it over');
  });

  capture('flow_cross_leaves', (tester, errors) async {
    await flow(tester);
    await tester.tap(find.bySemanticsLabel(LocaleKeys.challenges_leave.tr()));
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.acknowledged);
    expect(
      find.text(LocaleKeys.critical_alarm_at_my_desk_button.tr()),
      findsOneWidget,
    );
    print('FLOW the cross went back to the acknowledged screen, still open');
  });

  capture('flow_reader_tap', (tester, errors) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await flow(tester);
    await tester.tap(find.text(LocaleKeys.challenges_skip_tap.tr()));
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.closed);
    print('FLOW with a screen reader, one tap on the way out closed it');
  });

  capture('flow_no_pro', (tester, errors) async {
    await flow(tester, isPro: false, expectsChallenge: false);
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.closed);
    print('FLOW without Pro, At my desk closed at once, challenge set or not');
  });

  capture('flow_no_choice', (tester, errors) async {
    await flow(tester, hasChoice: false, expectsChallenge: false);
    await _afterClose(tester);
    expect(find.byType(ChallengeStep), findsNothing);
    expect(_status(), CriticalAlarmStatus.closed);
    print('FLOW with Pro and no challenge set, At my desk closed at once');
  });

  // The registry is what every surface above reads.
  test('every challenge is captured by name', () {
    expect(challenges.map((c) => c.kind), contains(_kind));
  });
}
