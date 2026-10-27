// Captures the cancel question sheet off the device, with a recording sink and
// no server.
//
//   fvm flutter test tool/capture_cancel_question.dart
//
// It opens the real sheet over a plain page, drives it with taps and text, and
// writes a PNG named <scene>_<phone>_<theme>_<scale>x[_reduced].png. The path
// of every file is printed.
//
// Scenes (the settled frame of each):
//   question          six reasons, nothing picked
//   explain           "Moving to my own server" picked, field empty, Send off
//   explain_typed     the same with 500 characters typed, Send on
//   explain_keyboard  explain_typed with a 300 point keyboard inset
//   thanks            the thanks title, the happy face and the last line
//   explain_scrolled  explain, scrolled to the end of the sheet (320 wide,
//                     text 2.0 only, where the sheet scrolls)
//   explain_keyboard_top  explain_keyboard, scrolled back to the top (320 wide,
//                     text 2.0 only), to show the cross is still in reach
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows or when the sink did not get what
// the scene did.
//
// Developer tool.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sink.dart';
import 'package:critalarm/features/in_app_notices/presentation/cancel_question/cancel_question_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phone = _Phone('390', Size(390, 844), 47, 34);
const _narrow = _Phone('320', Size(320, 640), 24, 0);

/// Keeps what the sheet sends, so a scene can check it.
class _Sink implements CancelAnswerSink {
  final reasons = <CancelReason>[];
  final texts = <(CancelReason, String)>[];

  @override
  Future<void> sendReason(CancelReason reason) async => reasons.add(reason);

  @override
  Future<void> sendText(CancelReason reason, String text) async =>
      texts.add((reason, text));
}

class _Scene {
  const _Scene(
    this.name,
    this.run, {
    this.keyboard = 0,
    this.afterKeyboard,
    this.check,
    this.onlyWhereItScrolls = false,
  });

  final String name;

  /// Drives the open sheet to the state to capture.
  final Future<void> Function(WidgetTester tester) run;

  /// Height of the keyboard inset in points.
  final double keyboard;

  /// Runs once the keyboard inset is in.
  final Future<void> Function(WidgetTester tester)? afterKeyboard;

  /// True for a scene that only means something where the sheet scrolls.
  final bool onlyWhereItScrolls;

  /// Throws when the sink does not hold what the scene should have sent.
  final void Function(_Sink sink)? check;
}

Future<void> _settle(WidgetTester tester) async {
  // The cursor never stops, so pumpAndSettle would not return.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final String _typed = List.filled(
  8,
  'The alarm screen needs a dark theme and I could not find where to '
  'turn it on. ',
).join().substring(0, 500);

Future<void> _pick(WidgetTester tester) async {
  await _settle(tester);
  await tester.tap(find.text('Moving to my own server'));
  await _settle(tester);
}

Future<void> _type(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), _typed);
  await _settle(tester);
}

void _expect(bool ok, String what) {
  if (!ok) throw StateError(what);
}

Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(
    find.byType(SingleChildScrollView).last,
    Offset(0, dy),
    warnIfMissed: false,
  );
  await _settle(tester);
}

final _scenes = <_Scene>[
  _Scene(
    'question',
    (tester) async => _settle(tester),
    check: (sink) => _expect(sink.reasons.isEmpty, 'sent before a tap'),
  ),
  _Scene(
    'explain',
    _pick,
    check: (sink) => _expect(
      sink.reasons.length == 1 && sink.texts.isEmpty,
      'the tap should send the reason and no text',
    ),
  ),
  _Scene(
    'explain_typed',
    (tester) async {
      await _pick(tester);
      await _type(tester);
    },
    check: (sink) => _expect(sink.texts.isEmpty, 'text sent before Send'),
  ),
  _Scene(
    'explain_keyboard',
    (tester) async {
      await _pick(tester);
      await _type(tester);
    },
    keyboard: 300,
    check: (sink) => _expect(sink.texts.isEmpty, 'text sent before Send'),
  ),
  _Scene(
    'explain_scrolled',
    (tester) async {
      await _pick(tester);
      await _scroll(tester, -3000);
    },
    onlyWhereItScrolls: true,
    check: (sink) => _expect(sink.texts.isEmpty, 'text sent before Send'),
  ),
  _Scene(
    'explain_keyboard_top',
    (tester) async {
      await _pick(tester);
      await _type(tester);
    },
    keyboard: 300,
    afterKeyboard: (tester) => _scroll(tester, 3000),
    onlyWhereItScrolls: true,
    check: (sink) => _expect(sink.texts.isEmpty, 'text sent before Send'),
  ),
  _Scene(
    'thanks',
    (tester) async {
      await _pick(tester);
      await tester.enterText(find.byType(TextField), 'A dark theme, please.');
      await _settle(tester);
      await tester.tap(find.text('Send'));
      await _settle(tester);
    },
    check: (sink) => _expect(
      sink.reasons.length == 1 && sink.texts.length == 1,
      'thanks should follow one reason and one text',
    ),
  ),
];

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    double scale = 1,
    bool isReduced = false,
  }) {
    final name =
        '${scene.name}_${phone.name}_${mode.name}_${scale}x'
        '${isReduced ? '_reduced' : ''}';
    if (!_wanted(name)) return;
    testWidgets('capture $name', (tester) async {
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

      final sink = _Sink();
      final boundaryKey = GlobalKey();
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: isReduced,
                textScaler: TextScaler.linear(scale),
              ),
              child: RepaintBoundary(key: boundaryKey, child: child),
            ),
            home: Builder(
              builder: (context) {
                final colors = context.appColors;
                return Scaffold(
                  backgroundColor: colors.canvas,
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
                      child: Text(
                        'Topics',
                        style: AppTypography.headline(colors.onCanvas),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        unawaited(
          showCancelQuestionSheet(
            tester.element(find.byType(Scaffold)),
            endsAt: DateTime(2026, 11, 9),
            sink: sink,
          ),
        );
        await tester.pump();
        await scene.run(tester);
        if (scene.keyboard > 0) {
          // The keyboard comes up last, as it does when a person taps the
          // field.
          tester.view.viewInsets = FakeViewPadding(
            bottom: scene.keyboard * dpr,
          );
          await _settle(tester);
        }
        await scene.afterKeyboard?.call(tester);
        scene.check?.call(sink);

        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          print('SAVED ${file.path}');
        });
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
      }
    });
  }

  // Every scene on both phones, light and dark, at the phone's own text size
  // and at 2.0.
  for (final phone in [_phone, _narrow]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, 2.0]) {
        for (final s in _scenes) {
          if (s.onlyWhereItScrolls && (phone != _narrow || scale != 2.0)) {
            continue;
          }
          capture(s, phone: phone, mode: mode, scale: scale);
        }
      }
    }
  }

  // A middle text size.
  for (final s in _scenes.where((s) => !s.onlyWhereItScrolls)) {
    capture(s, phone: _phone, mode: ThemeMode.light, scale: 1.3);
  }

  // Reduced motion: the settled frame of the last two states.
  for (final name in ['explain', 'thanks']) {
    capture(
      _scenes.firstWhere((s) => s.name == name),
      phone: _phone,
      mode: ThemeMode.light,
      isReduced: true,
    );
  }
}
