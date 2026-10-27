import 'dart:async';

import 'package:critalarm/features/onboarding/presentation/offer_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the offer layer transition', () {
    late AnimationController controller;

    Widget host(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 150),
      );
      addTearDown(controller.dispose);
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 800,
          child: buildOfferLayerTransition(
            animation: controller,
            child: const ColoredBox(
              key: Key('layer'),
              color: Color(0xFF123456),
            ),
          ),
        ),
      );
    }

    Rect layerRect(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('layer')));

    double layerOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byKey(const Key('layer')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('starts below the screen, so the first frame is the step', (
      tester,
    ) async {
      await tester.pumpWidget(host(tester));
      expect(layerRect(tester).top, 800);
    });

    testWidgets('rises opaque the whole way: nothing is half faded', (
      tester,
    ) async {
      await tester.pumpWidget(host(tester));
      final tops = <double>[];
      unawaited(controller.forward());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(layerOpacity(tester), 1, reason: 'frame $i');
        tops.add(layerRect(tester).top);
      }
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], lessThanOrEqualTo(tops[i - 1]), reason: 'frame $i');
      }
      // The ticker's first frame is value 0: the step, as it was. The next
      // frame already shows the rising layer, so nothing blank is drawn.
      expect(tops.first, 800);
      expect(tops[1], lessThan(800), reason: 'it moves from the next frame');
      expect(tops.last, 0, reason: 'at rest it covers the screen');
    });

    testWidgets('leaves with a slide and a fade, on the same widgets', (
      tester,
    ) async {
      await tester.pumpWidget(host(tester));
      controller.value = 1;
      await tester.pump();
      final element = tester.element(find.byKey(const Key('layer')));
      expect(layerOpacity(tester), 1);
      expect(layerRect(tester).left, 0);

      unawaited(controller.reverse());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(layerOpacity(tester), lessThan(1));
      expect(layerOpacity(tester), greaterThan(0));
      expect(layerRect(tester).left, greaterThan(0));
      expect(layerRect(tester).top, 0, reason: 'it does not drop');
      expect(
        tester.element(find.byKey(const Key('layer'))),
        same(element),
        reason: 'the reel keeps its state when the direction turns',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(layerRect(tester).top, 800, reason: 'at rest again, below');
    });
  });
}
