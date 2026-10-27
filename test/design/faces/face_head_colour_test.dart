import 'dart:typed_data';

import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The face is brand yellow with a dark outline and dark features in every
/// theme and on every canvas. Only the page around it changes colour.
const Color _yellow = Color(0xFFFFC93C);
const Color _ink = Color(0xFF1A140F);

/// The head colours the crowd used to cycle through.
const List<Color> _oldCrowdHeads = [
  Color(0xFF4EAAD8),
  Color(0xFFE2673D),
  Color(0xFF3FA652),
  Color(0xFFF2A7C3),
];

ThemeData _theme(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return ThemeData.dark().copyWith(extensions: const [AppColors.dark]);
  }
  return ThemeData.light().copyWith(extensions: const [AppColors.light]);
}

FacePainter _painterOf(WidgetTester tester, Finder face) =>
    tester
            .widget<CustomPaint>(
              find.descendant(of: face, matching: find.byType(CustomPaint)),
            )
            .painter!
        as FacePainter;

/// The colour of every pixel the boundary draws, as `0xAARRGGBB` counts.
Future<Map<int, int>> _pixelCounts(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  final counts = <int, int>{};
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final data = (await image.toByteData())!;
    final bytes = Uint8List.view(data.buffer);
    for (var i = 0; i < bytes.length; i += 4) {
      final colour =
          (bytes[i + 3] << 24) |
          (bytes[i] << 16) |
          (bytes[i + 1] << 8) |
          bytes[i + 2];
      counts[colour] = (counts[colour] ?? 0) + 1;
    }
  });
  return counts;
}

int _argb(Color c) => c.toARGB32();

void main() {
  group('the face tokens', () {
    test('are the same yellow, outline and ink in both themes', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        expect(colors.faceFill, _yellow);
        expect(colors.faceStroke, _ink);
        expect(colors.faceInk, _ink);
      }
    });

    test('are not retinted by a severity canvas', () {
      for (final base in [AppColors.light, AppColors.dark]) {
        for (final mode in SeverityMode.values) {
          final colors = base.withSeverity(mode);
          expect(colors.faceFill, _yellow, reason: '$mode');
          expect(colors.faceStroke, _ink, reason: '$mode');
          expect(colors.faceInk, _ink, reason: '$mode');
        }
      }
    });
  });

  group('FaceWidget', () {
    testWidgets('draws a yellow head in the light and dark theme, whatever '
        'the severity canvas', (tester) async {
      for (final brightness in Brightness.values) {
        for (final mode in SeverityMode.values) {
          for (final state in FaceState.values) {
            await tester.pumpWidget(
              MaterialApp(
                theme: _theme(brightness),
                home: SeverityScope(
                  mode: mode,
                  child: Scaffold(body: FaceWidget(state: state)),
                ),
              ),
            );
            final painter = _painterOf(tester, find.byType(FaceWidget));
            final reason = '$brightness $mode $state';
            expect(painter.fillColor, _yellow, reason: reason);
            expect(painter.strokeColor, _ink, reason: reason);
            expect(painter.inkColor, _ink, reason: reason);
          }
        }
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets('paints yellow pixels on the cheek in the '
          '${brightness.name} theme', (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(brightness),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: const FaceWidget(state: FaceState.calm, size: 200),
                ),
              ),
            ),
          ),
        );
        final counts = await _pixelCounts(tester, key);
        // The head is a 176 unit rounded square, so most of the picture is
        // head. Anything but yellow and ink is only edge smoothing.
        expect(counts[_argb(_yellow)] ?? 0, greaterThan(20000));
        // The old dark head and its gold rim.
        for (final old in const [Color(0xFF241D18), Color(0xFFB08A22)]) {
          expect(counts[_argb(old)] ?? 0, 0);
        }
      });
    }
  });

  group('FaceRipple', () {
    test('tells its heads apart by size, tilt and a ring', () {
      final looks = [
        for (var cell = 0; cell < 20; cell++) rippleCellLook(cell),
      ];
      expect({for (final look in looks) look.scale}.length, greaterThan(3));
      expect({for (final look in looks) look.tilt}.length, greaterThan(3));
      expect(looks.where((look) => look.ringed), isNotEmpty);
      expect(looks.where((look) => !look.ringed), isNotEmpty);
      for (final look in looks) {
        expect(look.scale, inInclusiveRange(0.5, 1.0));
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets('has only yellow heads in the ${brightness.name} theme, '
          'wave after wave', (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(brightness),
            home: Scaffold(
              backgroundColor: const Color(0xFF2A3BD8),
              body: RepaintBoundary(
                key: key,
                child: const FaceRipple(
                  faces: happyRippleFaces,
                  restFace: FaceState.content,
                  restFaces: celebrationRestFaces,
                  randomFaces: true,
                ),
              ),
            ),
          ),
        );
        // The first wave lands at 1.2 s, the second at about 4.4 s.
        for (final seconds in [0.5, 1.5, 2.5, 4.8, 6.0]) {
          await tester.pump(Duration(milliseconds: (seconds * 1000).round()));
          final faces = find.byType(FaceWidget);
          expect(faces, findsAtLeastNWidgets(8));
          for (final face in faces.evaluate()) {
            final painter = _painterOf(tester, find.byWidget(face.widget));
            expect(painter.fillColor, _yellow, reason: '$seconds s');
            expect(painter.strokeColor, _ink, reason: '$seconds s');
          }
          final counts = await _pixelCounts(tester, key);
          expect(counts[_argb(_yellow)] ?? 0, greaterThan(5000));
          for (final old in _oldCrowdHeads) {
            expect(counts[_argb(old)] ?? 0, 0, reason: '$old at $seconds s');
          }
        }
      });
    }
  });
}
