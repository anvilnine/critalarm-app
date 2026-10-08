// Captures the status screen components as the gallery draws them, off the
// device, with made-up data.
//
//   fvm flutter test tool/capture_topics_components.dart
//
// It writes one PNG per section, phone, theme and text size, each the full
// height of its section: 390 by 844 and 375 by 667 phones, light and dark,
// at text scale 1.0 and 1.3, plus 2.0 for the hero scene, the inbox rows and the stat card.
// Every file is named <section>_<phone>_<theme>_<scale>x_<frame>.png and its
// path is printed. A section that overflows fails its capture.
//
// With motion held, every part is on its resting frame: this is what reduce
// motion shows. Optional:
//   --dart-define=OUT=<folder>       where the PNGs go (default
//                                    build/captures)
//   --dart-define=SECTIONS=a,b       only these of status, pips, hero, inbox,
//                                    cream, stat
//   --dart-define=SCALES=1.0,2.0     the text scales (default 1.0,1.3 and,
//                                    for hero, inbox and stat, 2.0)
//   --dart-define=ONLY=<part>,<part> only files whose name has one of these
//                                    parts, such as 390x844_dark
//   --dart-define=T=<seconds>        let motion run and capture that second,
//                                    stepping the clock a frame at a time
//   --dart-define=ALSO=<s>,<s>       with T: go on to these later seconds in
//                                    the same run, one file each
//   --dart-define=SLICE=<points>     also write the page in slices this many
//                                    points tall, as <name>_p1.png and on,
//                                    for a reader that shrinks a tall image
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/gallery/topics_components_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _sectionsArg = String.fromEnvironment('SECTIONS');
const _scalesArg = String.fromEnvironment('SCALES');
const _only = String.fromEnvironment('ONLY');
const _t = String.fromEnvironment('T');
const _also = String.fromEnvironment('ALSO');
const _slice = int.fromEnvironment('SLICE');

const _phones = <(String, Size)>[
  ('390x844', Size(390, 844)),
  ('375x667', Size(375, 667)),
];

const _frame = Duration(milliseconds: 16);

/// Sections that are also captured at the largest text size.
const _largestToo = {'hero', 'inbox', 'stat'};

Widget _section(String name, double scale, double phoneWidth) => switch (name) {
  'status' => const StatusCardsGallery(),
  'pips' => const ReadinessPipsGallery(),
  'hero' => HeroSceneGallery(
    scales: [scale],
    // Each scene at its real width: 320, this phone and a 360 point pane.
    widths: [(320, false), (phoneWidth, false), (360, true)],
  ),
  'inbox' => const InboxRowsGallery(),
  'cream' => const CreamCardGallery(),
  'stat' => const StatCardGallery(),
  _ => throw ArgumentError('No section named $name'),
};

Future<void> _stepTo(WidgetTester tester, double second) async {
  final end = Duration(microseconds: (second * 1e6).round());
  var at = Duration.zero;
  while (at < end) {
    final step = end - at < _frame ? end - at : _frame;
    await tester.pump(step);
    at += step;
  }
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  required bool isGood,
}) => tester.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${isGood ? 'FIT ' : 'BAD '} ${file.path}');
  if (_slice > 0) {
    const step = _slice * 2;
    for (var y = 0, n = 1; y < image.height; y += step, n++) {
      final h = (image.height - y) < step ? image.height - y : step;
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        ui.Rect.fromLTWH(0, y.toDouble(), image.width.toDouble(), h.toDouble()),
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), h.toDouble()),
        ui.Paint(),
      );
      final piece = await recorder.endRecording().toImage(image.width, h);
      final data = await piece.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$_out/${name}_p$n.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    }
  }
});

void main() {
  final sections = _sectionsArg.isEmpty
      ? ['status', 'pips', 'hero', 'inbox', 'cream', 'stat']
      : _sectionsArg.split(',');
  final second = double.tryParse(_t);
  final laterSeconds = [
    for (final s in _also.split(',')) ?double.tryParse(s),
  ];
  final onlyParts = _only.split(',').where((p) => p.isNotEmpty).toList();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final section in sections) {
    final scales = _scalesArg.isEmpty
        ? [1.0, 1.3, if (_largestToo.contains(section)) 2.0]
        : [for (final s in _scalesArg.split(',')) double.parse(s)];
    for (final (phoneName, phone) in _phones) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in scales) {
          final base = '${section}_${phoneName}_${mode.name}_${scale}x';
          if (onlyParts.isNotEmpty && !onlyParts.any(base.contains)) continue;
          final frames = <double?>[
            second,
            ...laterSeconds,
          ];
          testWidgets('capture $base', (tester) async {
            final errors = <String>[];
            final oldHandler = FlutterError.onError;
            FlutterError.onError = (d) => errors.add(d.exceptionAsString());

            tester.view.physicalSize =
                Size(phone.width + 2 * Spacing.s4, 14000) * 2;
            tester.view.devicePixelRatio = 2;
            addTearDown(tester.view.reset);
            final key = GlobalKey();

            try {
              await tester.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildLightTheme(),
                  darkTheme: buildDarkTheme(),
                  themeMode: mode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: second == null,
                    ),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => Scaffold(
                      backgroundColor: context.appColors.canvas,
                      body: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: section == 'hero'
                              ? phone.width + 2 * Spacing.s4
                              : phone.width,
                          child: SingleChildScrollView(
                            child: RepaintBoundary(
                              key: key,
                              child: ColoredBox(
                                color: context.appColors.canvas,
                                child: Padding(
                                  padding: const EdgeInsets.all(Spacing.s4),
                                  child: _section(section, scale, phone.width),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();

              var clock = 0.0;
              for (final frame in frames) {
                if (frame != null) {
                  await _stepTo(tester, frame - clock);
                  clock = frame;
                }
                await _save(
                  tester,
                  key,
                  frame == null ? '${base}_rest' : '${base}_t$frame',
                  isGood: errors.isEmpty,
                );
              }
              expect(errors, isEmpty, reason: errors.join('\n'));
            } finally {
              FlutterError.onError = oldHandler;
            }
          });
        }
      }
    }
  }
}
