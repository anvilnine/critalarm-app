import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<RingingFacePainter> painters(WidgetTester tester) => [
    for (final paint in tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(ShufflingRingingFace),
        matching: find.byType(CustomPaint),
      ),
    ))
      paint.painter! as RingingFacePainter,
  ];

  /// Frames have no equality of their own. These are the parts that
  /// differ from one style, and one moment, to the next.
  void expectSameFrame(RingingFrame got, RingingFrame want) {
    expect(got.tilt, want.tilt);
    expect(got.nudge, want.nudge);
    expect(got.scale, want.scale);
    expect(got.flush, want.flush);
    expect(got.flash, want.flash);
    expect(got.spin, want.spin);
    expect(
      [for (final fx in got.fx) fx.kind],
      [for (final fx in want.fx) fx.kind],
    );
  }

  Widget faces({RingingStyle? pin, bool keepsFill = false}) {
    const row = Row(
      children: [
        ShufflingRingingFace(size: 60, isLive: false),
        ShufflingRingingFace(size: 60, isLive: false),
        ShufflingRingingFace(size: 60, isLive: false),
        ShufflingRingingFace(size: 60, isLive: false),
        ShufflingRingingFace(size: 60, isLive: false),
        ShufflingRingingFace(size: 60, isLive: false),
      ],
    );
    return MaterialApp(
      theme: buildLightTheme(),
      home: RingingFaceFill(
        keepsFill: keepsFill,
        child: pin == null ? row : RingingFacePin(style: pin, child: row),
      ),
    );
  }

  testWidgets('pinned faces all wear the one expression', (tester) async {
    const style = RingingStyle.classic;
    await tester.pumpWidget(faces(pin: style));

    final want = ringingFrameFor(style, style.stillT);
    final drawn = painters(tester);
    expect(drawn, hasLength(6));
    for (final painter in drawn) {
      expectSameFrame(painter.frame, want);
    }
  });

  testWidgets('a pinned face does not shuffle while it is live', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const RingingFacePin(
          style: RingingStyle.classic,
          child: ShufflingRingingFace(size: 60),
        ),
      ),
    );
    // Past two holds and blends of an unpinned face.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    final loops =
        const Duration(seconds: 10).inMicroseconds /
        RingingStyle.classic.period.inMicroseconds;
    expectSameFrame(
      painters(tester).single.frame,
      ringingFrameFor(RingingStyle.classic, loops % 1),
    );
  });

  testWidgets('a face told to keep its fill hands that to its painter', (
    tester,
  ) async {
    await tester.pumpWidget(faces(pin: RingingStyle.rage, keepsFill: true));
    for (final painter in painters(tester)) {
      expect(painter.keepsFill, isTrue);
    }
  });
}
