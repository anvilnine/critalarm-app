// Captures the stage faces, sad and calm, off the device. No server and no
// store: the mascot is drawn alone on a plain stage, with a stand-in block
// where the buy block sits, so the face can be checked for room.
//
//   fvm flutter test tool/capture_hero_faces.dart
//
// It writes a PNG named <scene>_<phone>_<theme>_<scale>x[_reduced].png and
// prints the path of every file.
//
// Scenes:
//   face_sad_150 / _120 / _72   the sad face at that many points
//   face_calm_150               the calm face
//   face_blend_half             sad turning to calm, half way (150 points)
//   face_row                    sad at 150, 120 and 72 beside calm at 150
//   enter_first                 the sad face on the first frame of its pop in
//   enter_mid                   the sad face part way through its pop in
//   settle_mid                  a quarter, half and three quarters of sad to
//                               calm in one row
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default: the shots folder
//                                of the plan, beside the planning files)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows. The reduced files draw the settled
// frame with no ticker: the mascot is given its finished values.
//
// Developer tool.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_mascot.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/captures/hero_faces',
);
const _only = String.fromEnvironment('ONLY');

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phone = _Phone('390', Size(390, 844), 47, 34);
const _short = _Phone('375', Size(375, 667), 20, 0);
const _narrow = _Phone('320', Size(320, 568), 20, 0);

/// One mascot on the stage: its size and what it wears this frame.
class _Mark {
  const _Mark(
    this.label,
    this.size, {
    this.face = HeroFace.sad,
    this.fromFace,
    this.faceBlend = 1,
    this.entrance = 1,
  });

  final String label;
  final double size;
  final HeroFace face;
  final HeroFace? fromFace;
  final double faceBlend;
  final double entrance;
}

class _Scene {
  const _Scene(this.name, this.marks);

  final String name;
  final List<_Mark> marks;
}

const _scenes = <_Scene>[
  _Scene('face_sad_150', [_Mark('Sad, 150', 150)]),
  _Scene('face_sad_120', [_Mark('Sad, 120', 120)]),
  _Scene('face_sad_72', [_Mark('Sad, 72', 72)]),
  _Scene('face_calm_150', [_Mark('Calm, 150', 150, face: HeroFace.calm)]),
  _Scene('face_blend_half', [
    _Mark(
      'Sad to calm, half',
      150,
      face: HeroFace.calm,
      fromFace: HeroFace.sad,
      faceBlend: 0.5,
    ),
  ]),
  _Scene('face_row', [
    _Mark('Sad 150', 150),
    _Mark('Sad 120', 120),
    _Mark('Sad 72', 72),
    _Mark('Calm 150', 150, face: HeroFace.calm),
  ]),
  _Scene('enter_first', [_Mark('First frame', 150, entrance: 0.001)]),
  _Scene('enter_mid', [_Mark('Pop in, half', 150, entrance: 0.5)]),
  _Scene('settle_mid', [
    _Mark(
      '25%',
      96,
      face: HeroFace.calm,
      fromFace: HeroFace.sad,
      faceBlend: 0.25,
    ),
    _Mark(
      '50%',
      96,
      face: HeroFace.calm,
      fromFace: HeroFace.sad,
      faceBlend: 0.5,
    ),
    _Mark(
      '75%',
      96,
      face: HeroFace.calm,
      fromFace: HeroFace.sad,
      faceBlend: 0.75,
    ),
  ]),
];

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

/// The stage the faces stand on, with a block pinned under it where the buy
/// block sits, so a face that grows into it shows.
class _Stage extends StatelessWidget {
  const _Stage(this.scene);

  final _Scene scene;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: Spacing.md,
                  runSpacing: Spacing.lg,
                  children: [
                    for (final mark in scene.marks)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HeroMascot(
                            size: mark.size,
                            face: mark.face,
                            fromFace: mark.fromFace,
                            faceBlend: mark.faceBlend,
                            entrance: mark.entrance,
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            mark.label, // l10n-ok: developer capture label
                            style: AppTypography.small(colors.onCanvas),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Container(
              height: 120,
              margin: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              alignment: Alignment.center,
              child: Text(
                'Buy block goes here', // l10n-ok: developer capture label
                style: AppTypography.small(colors.onCanvas),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      const dpr = 3.0;
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
            home: _Stage(scene),
          ),
        );
        await tester.pump();

        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: dpr);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          print('SAVED ${file.path}');
        });
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        FlutterError.onError = oldHandler;
      }
    });
  }

  final byName = {for (final s in _scenes) s.name: s};
  _Scene scene(String name) => byName[name]!;

  // Every scene on the two common phones, light and dark.
  for (final phone in [_phone, _short]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final s in _scenes) {
        capture(s, phone: phone, mode: mode);
      }
    }
  }

  // 320 wide and large text.
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final s in _scenes) {
      capture(s, phone: _narrow, mode: mode);
    }
  }
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final s in _scenes) {
      capture(s, phone: _phone, mode: mode, scale: 2);
      capture(s, phone: _short, mode: mode, scale: 2);
    }
    // The sad face on a 320 wide stage at text scale 2.0.
    capture(scene('face_sad_150'), phone: _narrow, mode: mode, scale: 2);
    capture(scene('face_row'), phone: _narrow, mode: mode, scale: 2);
  }

  // Reduced motion: the settled frame, finished values, no ticker. The pop
  // in is over, so the entrance scenes are left out.
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final name in ['face_sad_120', 'face_calm_150', 'face_row']) {
      capture(scene(name), phone: _phone, mode: mode, isReduced: true);
    }
  }
}
