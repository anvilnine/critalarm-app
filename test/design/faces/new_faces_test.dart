import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceState new expressions', () {
    test('FaceState includes all 8 new expressive face states', () {
      expect(FaceState.values, contains(FaceState.shocked));
      expect(FaceState.values, contains(FaceState.laughing));
      expect(FaceState.values, contains(FaceState.surprised));
      expect(FaceState.values, contains(FaceState.skeptical));
      expect(FaceState.values, contains(FaceState.dizzy));
      expect(FaceState.values, contains(FaceState.determined));
      expect(FaceState.values, contains(FaceState.confused));
      expect(FaceState.values, contains(FaceState.sad));
      expect(FaceState.values.length, 36);
    });

    test('FaceStatePresentation provides metadata for all states', () {
      for (final state in FaceState.values) {
        expect(state.label.isNotEmpty, isTrue);
        expect(state.description.isNotEmpty, isTrue);
        expect(state.characteristicColor, isA<Color>());
      }
    });

    test('Confused face has natural negative tilt angle', () {
      expect(FaceState.confused.defaultTilt, lessThan(0));
      expect(FaceState.calm.defaultTilt, 0);
      expect(FaceState.shocked.defaultTilt, 0);
    });

    test('Characteristic colors match sample screenshot specifications', () {
      expect(FaceState.laughing.characteristicColor, const Color(0xFF4EAAD8));
      expect(FaceState.surprised.characteristicColor, const Color(0xFFE2673D));
      expect(FaceState.dizzy.characteristicColor, const Color(0xFF3FA652));
      expect(FaceState.shocked.characteristicColor, const Color(0xFFFFC93C));
    });
  });

  group('FacePainter canvas rendering', () {
    test('paints every state cleanly on canvas without error', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(200, 200);

      for (final state in FaceState.values) {
        final painter = FacePainter(
          state: state,
          fillColor: const Color(0xFFFFC93C),
          strokeColor: const Color(0xFF1A140F),
          inkColor: const Color(0xFF1A140F),
          lookDx: -10,
          spiralRotation: 1.5,
          tongueColor: const Color(0xFFFA7970),
        );
        expect(() => painter.paint(canvas, size), returnsNormally);
      }
      recorder.endRecording();
    });
  });

  group('FaceWidget rendering', () {
    testWidgets('renders all face states statically and live', (tester) async {
      for (final state in FaceState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FaceWidget(
                state: state,
                size: 80,
              ),
            ),
          ),
        );
        expect(find.byType(FaceWidget), findsOneWidget);

        // Test live
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FaceWidget(
                state: state,
                size: 80,
                isLive: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(FaceWidget), findsOneWidget);
      }
    });

    testWidgets('supports tiltAngle and color overrides', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FaceWidget(
              state: FaceState.confused,
              size: 100,
              tiltAngle: -0.2,
              overrideFillColor: Color(0xFF4EAAD8),
              overrideStrokeColor: Color(0xFFF5473A),
              overrideTongueColor: Color(0xFFFF6A5E),
            ),
          ),
        ),
      );
      expect(find.byType(FaceWidget), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
    });
  });
}
