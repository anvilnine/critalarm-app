// Captures the setup test's acknowledged screen ("It works") and the first
// tool alarm's, off the device, with a made-up alarm, a faked offer gate and
// no server.
//
//   fvm flutter test tool/capture_works_screen.dart
//
// It draws the real AcknowledgedScreen, answers the offer gate the way the
// scene says, steps the clock, and writes a PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced].png. The path of every file is
// printed. Last, it lays the files of each scene side by side in
// sheet_<scene>.png, so a run can be read at a glance.
//
// Scenes:
//   works_offer_ahead   the gate said the offer follows and the store said it
//                       is on sale: no confetti, 2.5 s in
//   works_no_offer      the gate said nothing follows (or the store said
//                       nothing is on sale): confetti 1 s into the throw
//   works_store_unsure  the offer is to come and the store had not answered:
//                       confetti 1 s into the throw
//   works_no_offer_start  the first frames after a late answer: the confetti
//                       has just started
//   works_first_frame   the first frame after the screen appears, the gate
//                       has not answered
//   first_tool_acked    the first tool alarm's screen: confetti as it was
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows.
//
// Developer tool.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
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

/// A gate that answers when the scene says. `null` never answers.
class _FakeGate implements OnboardingOfferGate {
  _FakeGate(this.answer);

  final Completer<OfferOutlook> answer;

  @override
  Future<OfferOutlook> outlook() => answer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Scene {
  const _Scene(
    this.name, {
    required this.answer,
    required this.isFirstTool,
    required this.steps,
  });

  final String name;

  /// What the gate answers, or null when it does not answer at all.
  final OfferOutlook? answer;
  final bool isFirstTool;

  /// How the clock is stepped before the shot. The gate answers after the
  /// first entry, so the rest is time since the answer.
  final List<Duration> steps;
}

const _ms = Duration(milliseconds: 1);

final _scenes = <_Scene>[
  _Scene(
    'works_offer_ahead',
    answer: OfferOutlook.coming,
    isFirstTool: false,
    steps: [_ms * 16, _ms * 2500],
  ),
  _Scene(
    'works_no_offer',
    answer: OfferOutlook.none,
    isFirstTool: false,
    steps: [_ms * 16, _ms * 1000],
  ),
  _Scene(
    'works_store_unsure',
    answer: OfferOutlook.unsure,
    isFirstTool: false,
    steps: [_ms * 16, _ms * 1000],
  ),
  _Scene(
    'works_no_offer_start',
    answer: OfferOutlook.none,
    isFirstTool: false,
    steps: [_ms * 16, _ms * 48],
  ),
  const _Scene(
    'works_first_frame',
    answer: null,
    isFirstTool: false,
    steps: [Duration.zero],
  ),
  _Scene(
    'first_tool_acked',
    answer: null,
    isFirstTool: true,
    steps: [_ms * 16, _ms * 1000],
  ),
];

CriticalAlarmState _stateFor({required bool isFirstTool}) {
  final now = DateTime(2026, 10, 13, 9, 41, 7);
  return CriticalAlarmState(
    status: CriticalAlarmStatus.acknowledged,
    meta: '09:38 / critical, my-first-topic',
    incident: Incident(
      id: 'inc_made_up',
      topic: 'my-first-topic',
      openedAt: now.subtract(const Duration(seconds: 7)),
      ackedAt: now,
    ),
    topic: 'my-first-topic',
    isAcknowledged: true,
    setupFlowHasRealRing: true,
    setupTestIncidentIds: isFirstTool ? const {} : const {'inc_made_up'},
    firstToolIncidentId: isFirstTool ? 'inc_made_up' : null,
  );
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

final _written = <String, List<String>>{};

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

      final answer = Completer<OfferOutlook>();
      if (getIt.isRegistered<OnboardingOfferGate>()) {
        getIt.unregister<OnboardingOfferGate>();
      }
      getIt.registerSingleton<OnboardingOfferGate>(_FakeGate(answer));

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
            home: AlarmStyleStage(
              style: standardAlarmStyle,
              stage: AlarmStage.acknowledged,
              severity: SeverityMode.crit,
              child: Builder(
                builder: (context) => AcknowledgedScreen(
                  state: _stateFor(isFirstTool: scene.isFirstTool),
                  colors: context.appColors,
                ),
              ),
            ),
          ),
        );
        // The first frame after the screen appears.
        await tester.pump(scene.steps.first);
        if (scene.answer != null) {
          answer.complete(scene.answer);
          await tester.pump();
        }
        // The confetti moves a step per frame, so the clock is stepped the
        // way a phone's is, in 16 ms frames.
        for (final step in scene.steps.skip(1)) {
          for (var t = Duration.zero; t < step; t += _ms * 16) {
            await tester.pump(_ms * 16);
          }
        }

        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          (_written[scene.name] ??= []).add(file.path);
          print('SAVED ${file.path}');
        });
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        if (!answer.isCompleted) answer.complete(OfferOutlook.none);
        // Takes the screen down so no timer is left running.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
        getIt.unregister<OnboardingOfferGate>();
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
      }
    });
  }

  for (final scene in _scenes) {
    for (final phone in [_phone, _narrow]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          capture(scene, phone: phone, mode: mode, scale: scale);
        }
        // Reduced motion: the settled frame, no ticker.
        capture(scene, phone: phone, mode: mode, isReduced: true);
      }
    }
  }

  // Each scene's files side by side, so a run can be read at a glance.
  testWidgets('contact sheets', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory(_out);
      if (!dir.existsSync()) return;
      for (final scene in _scenes) {
        final files =
            dir
                .listSync()
                .whereType<File>()
                .where(
                  (f) =>
                      RegExp(
                        '^${scene.name}_(390|320)_',
                      ).hasMatch(f.uri.pathSegments.last) &&
                      f.uri.pathSegments.last.endsWith('.png'),
                )
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));
        if (files.isEmpty) continue;
        for (final group in ['390', '320']) {
          final part = files
              .where((f) => f.uri.pathSegments.last.contains('_${group}_'))
              .toList();
          if (part.isEmpty) continue;
          final images = <ui.Image>[];
          for (final f in part) {
            final codec = await ui.instantiateImageCodec(
              await f.readAsBytes(),
            );
            images.add((await codec.getNextFrame()).image);
          }
          // Eight per sheet, in a row of four.
          const cell = 0.5;
          const perRow = 4;
          final w = images.first.width * cell;
          final h = images.first.height * cell;
          final rows = (images.length / perRow).ceil();
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder)
            ..drawRect(
              Rect.fromLTWH(0, 0, w * perRow, h * rows),
              ui.Paint()..color = const Color(0xFF808080),
            );
          for (var i = 0; i < images.length; i++) {
            final dx = (i % perRow) * w;
            final dy = (i ~/ perRow) * h;
            canvas.drawImageRect(
              images[i],
              Rect.fromLTWH(
                0,
                0,
                images[i].width.toDouble(),
                images[i].height.toDouble(),
              ),
              Rect.fromLTWH(dx + 2, dy + 2, w - 4, h - 4),
              ui.Paint()..filterQuality = FilterQuality.medium,
            );
          }
          final sheet = await recorder.endRecording().toImage(
            (w * perRow).round(),
            (h * rows).round(),
          );
          final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
          final out = File('$_out/sheet_${scene.name}_$group.png');
          await out.writeAsBytes(bytes!.buffer.asUint8List());
          print('SHEET ${out.path}');
          for (var i = 0; i < part.length; i++) {
            print('  $i ${part[i].uri.pathSegments.last}');
          }
        }
      }
    });
  });
}
