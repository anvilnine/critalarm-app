import 'package:critalarm/app/shell/search_edge_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 400.0;

  late AnimationController reveal;
  late int started;
  late int closed;

  Future<void> pump(WidgetTester tester) async {
    started = 0;
    closed = 0;
    tester.view.physicalSize = const Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    reveal = AnimationController(
      vsync: tester,
      value: 1,
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(reveal.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: SearchEdgeSwipe.edgeWidth,
              child: SearchEdgeSwipe(
                reveal: reveal,
                screenWidth: width,
                onStart: () => started++,
                onClose: () => closed++,
                onSettled: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('a drag from the left edge past a third closes search', (
    tester,
  ) async {
    await pump(tester);
    final g = await tester.startGesture(const Offset(5, 300));
    await g.moveBy(const Offset(60, 0));
    await g.moveBy(const Offset(100, 0));
    // The panel follows the finger.
    expect(reveal.value, lessThan(0.7));
    await g.up();
    expect(started, 1);
    expect(closed, 1);
  });

  testWidgets('a short slow drag springs back and does not close', (
    tester,
  ) async {
    await pump(tester);
    final g = await tester.startGesture(const Offset(5, 300));
    await g.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await tester.pumpAndSettle();
    expect(closed, 0);
    expect(reveal.value, 1);
  });

  testWidgets('a drag in the middle of the screen does not start', (
    tester,
  ) async {
    await pump(tester);
    final g = await tester.startGesture(const Offset(200, 300));
    await g.moveBy(const Offset(150, 0));
    await g.up();
    expect(started, 0);
    expect(closed, 0);
    expect(reveal.value, 1);
  });
}
