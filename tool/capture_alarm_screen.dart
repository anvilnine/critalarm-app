// Captures the real ringing alarm screen off the device, with the mock API,
// so a change near it can be compared before and after.
//
//   fvm flutter test tool/capture_alarm_screen.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
//     --dart-define=OUT=build/alarm_shots/before
//
// For each of 390 by 844, 375 by 667 and 1024 by 768, light and dark, at the
// default text size and 1.3, with motion still, it writes:
//   <name>.png             the screen
//   <name>.semantics.txt   the screen reader tree in the order it is walked
//   <name>.geometry.txt    where the face, the card, every line of text and
//                          every button sit
//   <name>.reader.txt      what the screen sent a running screen reader: the
//                          focus move and the announcement
//
// To compare a later run with an earlier one:
//   --dart-define=AGAINST=build/alarm_shots/before
// prints, per file, whether the text files match and the box that holds
// every pixel that differs. Two runs of the same code never match whole: the
// ringing face picks one of its styles at random, and two lines hold a
// clock. So the face's stage and those two lines are left out of the pixel
// comparison, and the clock is taken out of the text files.
//
// The second stage, the acknowledged screen with "At my desk" on it, is
// captured the same way with
//   --dart-define=STAGE=acked
// The alarm is acknowledged through the cubit and the files are named
// `acked_...`. The moment between the two, while the acknowledge is on its
// way and "I'm up" is off and holds a spinner, is
//   --dart-define=STAGE=acking
// with files named `acking_...`.
//
// To capture another look of the alarm screen:
//   --dart-define=STYLE=minimal
// saves that look as the phone's and holds the plan that unlocks it. With
//   --dart-define=HELD=false
// the look stays saved and the plan is not held, which draws the standard
// look. A look moves the face and the text, so the comparison adds a
// second line that leaves positions and scroll extents out: whether a
// screen reader walks the same things in the same order, and whether every
// button and its label sit where they did.
//
// By default the screen is captured bare, on its own background. The app
// draws it on the canvas of its ambient shell, with the shapes of the
// alarm's ambient profile behind it. To capture it that way:
//   --dart-define=SHELL=true
// A look is best judged like this, since its canvas is part of it.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/alarm_shots');
const _against = String.fromEnvironment('AGAINST');
const _stage = String.fromEnvironment('STAGE', defaultValue: 'ringing');
const _isAcked = _stage == 'acked';
const _isAcking = _stage == 'acking';
const _style = String.fromEnvironment('STYLE');
const _isHeld = bool.fromEnvironment('HELD', defaultValue: true);
const _inShell = bool.fromEnvironment('SHELL');

/// Where the phone's look is saved (`AlarmStyleChoices.defaultKey`).
const _styleKey = 'alarm_style_default';

const _screens = <(String, Size, double, double)>[
  ('390x844', Size(390, 844), 47, 34),
  ('375x667', Size(375, 667), 20, 0),
  ('1024x768', Size(1024, 768), 24, 20),
];

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

/// The tree without the parts that change from run to run: node ids, and
/// the seconds the alarm has rung for.
String _steady(String tree) =>
    tree.replaceAll(RegExp('#[0-9a-f]+'), '#').replaceAll(_clock, 'CLOCK');

/// A time of day, or how long the alarm has rung.
final _clock = RegExp(
  r'\d+:\d\d|\d+ (seconds?|minutes?|min|s\b)( \d+ (seconds?|s\b))?',
);

/// What two runs of the acknowledged stage can be compared on.
///
/// That screen shows two times of day to the second and how long the alarm
/// rang, all read off the wall clock, so they differ from run to run and
/// the centred line they sit in changes width with them. This takes the
/// seconds out, and the left and right edge of any line that holds a
/// clock. Where the line sits from top to bottom, and its height, stay.
/// The ringing stage is compared as it always was.
String _calm(String text) {
  if (!_isAcked) return text;
  final lines = text.replaceAll(RegExp(r'CLOCK:\d\d'), 'CLOCK').split('\n');
  final box = RegExp(r'^(\w+) [\d.]+ ([\d.]+) [\d.]+ ([\d.]+) (.*CLOCK.*)$');
  final rect = RegExp(
    r'Rect\.fromLTRB\([\d.]+, ([\d.]+), [\d.]+, ([\d.]+)\)',
  );
  int? lastRect;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final inList = box.firstMatch(line);
    if (inList != null) {
      lines[i] = '${inList[1]} ~ ${inList[2]} ~ ${inList[3]} ${inList[4]}';
      continue;
    }
    if (rect.hasMatch(line)) lastRect = i;
    if (line.contains('label:') && line.contains('CLOCK') && lastRect != null) {
      lines[lastRect] = lines[lastRect].replaceFirstMapped(
        rect,
        (m) => 'Rect.fromLTRB(~, ${m[1]}, ~, ${m[2]})',
      );
    }
  }
  return lines.join('\n');
}

/// The tree with every position taken out, and how far the list scrolls:
/// what a screen reader meets, and in which order, wherever it sits. A
/// look with a smaller face can fit a list that scrolled before, which
/// changes the scroll extent and nothing a person hears.
String _walk(String tree) => tree
    .replaceAll(
      RegExp(r'Rect\.fromLTRB\([^)]*\)( scaled by [\d.]+x)?'),
      'RECT',
    )
    .split('\n')
    .where(
      (line) =>
          !line.contains('scrollExtent') &&
          !line.contains('scrollPosition') &&
          !RegExp(r'actions: scroll\w+(, scroll\w+)*$').hasMatch(line),
    )
    .join('\n');

/// Every button of a geometry file, with the label drawn in it.
String _buttons(String geometry) {
  final lines = geometry.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].startsWith('AppButton '))
        '${lines[i]} | ${i + 1 < lines.length ? lines[i + 1] : ''}',
  ].join('\n');
}

Future<Uint8List> _rgba(ui.Image image) async =>
    (await image.toByteData())!.buffer.asUint8List();

/// The box around every pixel that differs outside [skip], or null when
/// none does.
Rect? _differs(Uint8List a, Uint8List b, int width, List<Rect> skip) {
  if (a.length != b.length) return Rect.largest;
  int? left;
  int? top;
  var right = 0;
  var bottom = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] == b[i] && a[i + 1] == b[i + 1] && a[i + 2] == b[i + 2]) {
      continue;
    }
    final x = (i ~/ 4) % width;
    final y = (i ~/ 4) ~/ width;
    final at = Offset(x + 0.5, y + 0.5);
    if (skip.any((r) => r.contains(at))) continue;
    left = left == null || x < left ? x : left;
    top ??= y;
    right = x > right ? x : right;
    bottom = y > bottom ? y : bottom;
  }
  if (left == null || top == null) return null;
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await configureDependencies();
    await _loadFonts();
    if (_style.isNotEmpty) {
      // Written to the store the app reads, once the app has set it up.
      await getIt<SharedPreferences>().setString(_styleKey, _style);
      await getIt<ProPackDevSwitch>().setHeld(isHeld: _isHeld);
    }
  });

  for (final (sizeName, size, topInset, bottomInset) in _screens) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, 1.3]) {
        const stage = _isAcked
            ? 'acked'
            : _isAcking
            ? 'acking'
            : 'alarm';
        final name = '${stage}_${sizeName}_${mode.name}_${scale}x';
        testWidgets('capture $name', (tester) async {
          final errors = <String>[];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString());

          const dpr = 2.0;
          tester.view.physicalSize = size * dpr;
          tester.view.devicePixelRatio = dpr;
          tester.view.padding = FakeViewPadding(
            top: topInset * dpr,
            bottom: bottomInset * dpr,
          );
          tester.view.viewPadding = tester.view.padding;
          // A screen reader is running, so the screen moves it to "I'm up"
          // and makes its announcement.
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(
                accessibleNavigation: true,
                disableAnimations: true,
              );
          addTearDown(tester.view.reset);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final sent = <String>[];
          tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<dynamic>(
                SystemChannels.accessibility,
                (message) async {
                  sent.add('$message');
                  return null;
                },
              );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockDecodedMessageHandler<dynamic>(
                  SystemChannels.accessibility,
                  null,
                ),
          );
          final semantics = tester.ensureSemantics();
          final boundaryKey = GlobalKey();
          getIt<MockServer>().loadFixture(FaceState.alarmed);

          debugDisableShadows = false;
          final router = buildRouter(initialLocation: '/alarm');
          try {
            await tester.pumpWidget(
              MultiBlocProvider(
                providers: [
                  BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
                  // The acknowledged screen reads the desk timer from it.
                  BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
                ],
                child: MaterialApp.router(
                  theme: buildLightTheme(),
                  darkTheme: buildDarkTheme(),
                  themeMode: mode,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: _inShell
                          ? AppAmbientShell(
                              router: router,
                              child: child ?? const SizedBox.shrink(),
                            )
                          : child,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));
            // Past the wait before the announcement.
            await tester.pump(const Duration(milliseconds: 1200));
            await tester.pump();
            if (_isAcking) {
              // What the cubit shows from the tap on "I'm up" until the
              // server answers.
              final cubit = CriticalAlarmCubit.current!;
              cubit.emit(cubit.state.copyWith(isAcknowledging: true));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 200));
            }
            if (_isAcked) {
              // "I'm up", through the same call the button makes.
              await tester.runAsync(
                () => CriticalAlarmCubit.current!.acknowledge(),
              );
              for (var i = 0; i < 4; i++) {
                await tester.pump(const Duration(milliseconds: 200));
              }
            }

            final tree = _steady(
              tester
                  .binding
                  .renderViews
                  .first
                  .owner!
                  .semanticsOwner!
                  .rootSemanticsNode!
                  .toStringDeep(),
            );
            final reader = _steady(sent.join('\n'));

            // Where things sit, and what the pixel comparison leaves out.
            final lines = <String>[];
            final skip = <Rect>[];
            String box(Rect r) => [
              r.left,
              r.top,
              r.width,
              r.height,
            ].map((v) => v.toStringAsFixed(1)).join(' ');
            for (final element
                in find
                    .byWidgetPredicate(
                      (w) =>
                          w is ShufflingRingingFace ||
                          w is PulseRingWidget ||
                          w is AppSheet ||
                          w is AppButton ||
                          w is Text,
                      // The wide acknowledged layout fills what is left of
                      // a viewport, and the walk that leaves offstage
                      // children out trips over that sliver.
                      // ignore: avoid_redundant_argument_values, set by STAGE
                      skipOffstage: !_isAcked,
                    )
                    .evaluate()) {
              final widget = element.widget;
              final Rect rect;
              if (_isAcked) {
                // Read off the element, for the same reason.
                final box = element.renderObject! as RenderBox;
                // Kept in the tree and never laid out: not on screen.
                if (!box.hasSize) continue;
                rect = box.localToGlobal(Offset.zero) & box.size;
              } else {
                rect = tester.getRect(find.byWidget(widget));
              }
              final words = widget is Text ? (widget.data ?? '') : '';
              if (widget is ShufflingRingingFace || _clock.hasMatch(words)) {
                // Steam and stars are thrown a little past the face's stage.
                final spill = widget is ShufflingRingingFace
                    ? rect.width * 0.25
                    : 1.0;
                skip.add(
                  Rect.fromLTRB(
                    rect.left * dpr,
                    rect.top * dpr,
                    rect.right * dpr,
                    rect.bottom * dpr,
                  ).inflate(spill * dpr),
                );
              }
              lines.add(
                '${widget.runtimeType} ${box(rect)} '
                        '${_steady(words)}'
                    .trimRight(),
              );
            }
            final geometry = lines.join('\n');

            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: dpr);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory(_out);
              await dir.create(recursive: true);
              await File(
                '$_out/$name.png',
              ).writeAsBytes(png!.buffer.asUint8List());
              await File('$_out/$name.semantics.txt').writeAsString(tree);
              await File('$_out/$name.reader.txt').writeAsString(reader);
              await File('$_out/$name.geometry.txt').writeAsString(geometry);
              print('${errors.isEmpty ? 'FIT ' : 'BAD '} $_out/$name.png');

              if (_against.isEmpty) return;
              final oldTree = File('$_against/$name.semantics.txt');
              final oldReader = File('$_against/$name.reader.txt');
              final oldGeometry = File('$_against/$name.geometry.txt');
              final sameGeometry =
                  oldGeometry.existsSync() &&
                  _calm(oldGeometry.readAsStringSync()) == _calm(geometry);
              final oldPng = File('$_against/$name.png');
              final sameTree =
                  oldTree.existsSync() &&
                  _calm(oldTree.readAsStringSync()) == _calm(tree);
              final sameReader =
                  oldReader.existsSync() &&
                  oldReader.readAsStringSync() == reader;
              final codec = await ui.instantiateImageCodec(
                oldPng.readAsBytesSync(),
              );
              final old = (await codec.getNextFrame()).image;
              final differs = _differs(
                await _rgba(old),
                await _rgba(image),
                image.width,
                skip,
              );
              print(
                '     semantics ${sameTree ? 'same' : 'DIFFERENT'}, '
                'reader ${sameReader ? 'same' : 'DIFFERENT'}, '
                'geometry ${sameGeometry ? 'same' : 'DIFFERENT'}, '
                'pixels outside the face and the clocks '
                '${differs == null ? 'same' : 'DIFFER inside $differs of '
                          '${image.width}x${image.height}'}',
              );
              if (_style.isEmpty) return;
              final sameWalk =
                  oldTree.existsSync() &&
                  _walk(_calm(oldTree.readAsStringSync())) ==
                      _walk(_calm(tree));
              final sameButtons =
                  oldGeometry.existsSync() &&
                  _buttons(_calm(oldGeometry.readAsStringSync())) ==
                      _buttons(_calm(geometry));
              print(
                '     look $_style${_isHeld ? '' : ', plan not held'}: '
                'semantics without positions and scrolling '
                '${sameWalk ? 'same' : 'DIFFERENT'}, '
                'buttons and their labels '
                '${sameButtons ? 'same' : 'DIFFERENT'}',
              );
            });
            if (_isAcked) {
              // Past the wait for the follow-up the acknowledge may open,
              // so no timer outlives the capture.
              await tester.pump(const Duration(seconds: 2));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pump(const Duration(seconds: 1));
            }
            expect(errors, isEmpty, reason: errors.join('\n'));
          } finally {
            semantics.dispose();
            debugDisableShadows = true;
            FlutterError.onError = oldHandler;
          }
        });
      }
    }
  }
}
