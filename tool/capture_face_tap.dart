// Captures the hero face tap reactions frame by frame, off the device. The
// real AppHeroScene is drawn alone with a stand-in card, the face is tapped,
// and the clock is stepped 16 ms at a time.
//
//   fvm flutter test tool/capture_face_tap.dart
//
// It writes <reaction>_<ms>.png for each reaction at several moments after
// the tap, plus the same for reduce motion, and prints every path.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go
//                                (default build/captures/face_tap)
//
// Developer tool.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/captures/face_tap',
);

const _frame = Duration(milliseconds: 16);

/// The moments captured after each tap, in milliseconds.
const _moments = [0, 60, 140, 260, 420, 650, 900, 1300, 2000, 2700];

Future<void> _step(WidgetTester tester, Duration by) async {
  var at = Duration.zero;
  while (at < by) {
    final step = by - at < _frame ? by - at : _frame;
    await tester.pump(step);
    at += step;
  }
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) =>
    tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      print(file.path);
    });

Widget _scene(GlobalKey key, {required bool reduce}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildLightTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 300),
      disableAnimations: reduce,
    ),
    child: Builder(
      builder: (context) => ColoredBox(
        color: context.appColors.canvas,
        child: Align(
          alignment: Alignment.topCenter,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: context.appColors.canvas,
              child: SizedBox(
                width: 390,
                height: 230,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: AppHeroScene(
                    face: FaceState.calm,
                    card: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: context.appColors.onCanvas,
                        borderRadius: Radii.lgAll,
                      ),
                    ),
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

/// Taps the face at [at] (a share of the face box) and saves the frames.
Future<void> _play(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  Offset at = const Offset(0.5, 0.5),
  int taps = 1,
}) async {
  final face = find.byType(FaceTapPlay);
  final rect = tester.getRect(face);
  final point = rect.topLeft + Offset(rect.width * at.dx, rect.height * at.dy);
  for (var i = 0; i < taps; i++) {
    await tester.tapAt(point);
    if (i < taps - 1) await _step(tester, const Duration(milliseconds: 150));
  }
  var last = 0;
  for (final ms in _moments) {
    await _step(tester, Duration(milliseconds: ms - last));
    last = ms;
    await _save(tester, key, '${name}_${ms.toString().padLeft(4, '0')}');
  }
  // Long enough for the cycle to carry on but not to start over.
  await _step(tester, const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await loadTestTranslations();
  });

  testWidgets('face tap reactions', (tester) async {
    tester.view.physicalSize = const Size(780, 600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // Taps are counted on the fake clock the frames are stepped on.
    FaceTapSequencer.debugNow = () => tester.binding.clock.now();
    addTearDown(() => FaceTapSequencer.debugNow = DateTime.now);

    final key = GlobalKey();
    await tester.pumpWidget(_scene(key, reduce: false));
    await _step(tester, const Duration(milliseconds: 200));

    await _play(tester, key, 'a_boop');
    await _play(tester, key, 'b_giggle');
    await _play(tester, key, 'c_startle');
    await _play(tester, key, 'd_peek_left', at: const Offset(0.05, 0.3));
    await _play(tester, key, 'e_wink', at: const Offset(0.8, 0.5));
    await _play(tester, key, 'f_love');
    await _step(tester, const Duration(seconds: 7));
    // Four quick taps play the cycle, the fifth is dizzy.
    await _play(tester, key, 'g_dizzy', taps: 5);
    await _step(tester, const Duration(seconds: 7));

    final still = GlobalKey();
    await tester.pumpWidget(_scene(still, reduce: true));
    await _step(tester, const Duration(milliseconds: 200));
    await _play(tester, still, 'h_boop_reduced');

    // Unmount so the hero's clock stops before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
