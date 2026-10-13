import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/receipt/leaving/leaving_receipt_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// The numbers of the 320 by 568 phone at the default text size: the words
// above the slip are 41 points (the top gap, a 27 point headline and its
// gap), the three lines under it 86, the line under the headline 26.
LeavingReceiptFit _fit({
  required double height,
  double textScale = 1,
  double top = 41,
  double sub = 26,
  double after = 86,
}) => leavingReceiptFitFor(
  height: height,
  top: top,
  sublineBlock: sub,
  afterHeight: after,
  stageGap: 8,
  bottomGap: 12,
  rows: 4,
  textScale: textScale,
);

void main() {
  final slip = ReceiptPlan.minHeight(4, hasTotal: false);
  final slipWithFace = leavingReceiptMinHeight(4, textScale: 2);

  group('what gives way when room runs out', () {
    test('with room, nothing gives way', () {
      final fit = _fit(height: 600);
      expect(fit.showsFace, isTrue);
      expect(fit.showsSubline, isTrue);
      expect(fit.scrolls, isFalse);
    });

    test('at a large text size the face goes first, the line stays', () {
      // The words, the line under the headline and the slip with its face
      // need 41 + 26 + 320 + 8 + 86 + 12 = 493. Short of that, no face.
      expect(_fit(height: 493, textScale: 2).showsFace, isTrue);
      final fit = _fit(height: 492, textScale: 2);
      expect(fit.showsFace, isFalse);
      expect(fit.showsSubline, isTrue);
      expect(fit.scrolls, isFalse);
      expect(fit.stage, greaterThanOrEqualTo(slip));
    });

    test('then the line under the headline goes', () {
      // With no face: 41 + 26 + 244 + 8 + 86 + 12 = 417. Short of that,
      // no line.
      expect(_fit(height: 417, textScale: 2).showsSubline, isTrue);
      final fit = _fit(height: 416, textScale: 2);
      expect(fit.showsFace, isFalse);
      expect(fit.showsSubline, isFalse);
      expect(fit.scrolls, isFalse);
    });

    test(
      'then the slip tightens to its smallest row, and only then scrolls',
      () {
        // 41 + 244 + 8 + 86 + 12 = 391 holds the slip at its tightest rows.
        final tight = _fit(height: 391, textScale: 2);
        expect(tight.scrolls, isFalse);
        expect(tight.stage, slip);
        final short = _fit(height: 390, textScale: 2);
        expect(short.scrolls, isTrue);
        expect(short.showsFace, isFalse);
        expect(short.showsSubline, isFalse);
        expect(short.stage, slip);
      },
    );

    test('at the default size the face takes no height, so it stays', () {
      for (final height in [300.0, 366.0, 420.0, 600.0]) {
        expect(_fit(height: height).showsFace, isTrue, reason: '$height');
      }
      expect(_fit(height: 366).scrolls, isTrue);
    });

    test('a stage is never shorter than its smallest slip', () {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (var height = 250.0; height <= 700; height += 7) {
          final fit = _fit(height: height, textScale: scale);
          expect(
            fit.stage,
            greaterThanOrEqualTo(
              fit.showsFace
                  ? leavingReceiptMinHeight(4, textScale: scale)
                  : slip,
            ),
            reason: '$height at $scale',
          );
        }
      }
    });

    test('the buy button is never part of the room: only the box above it', () {
      // The fit is made inside the height above the buy block, so a stage
      // plus the words that fit never exceed it.
      for (final scale in [1.0, 2.0]) {
        for (var height = 400.0; height <= 700; height += 9) {
          final fit = _fit(height: height, textScale: scale);
          if (fit.scrolls) continue;
          final used =
              41 + (fit.showsSubline ? 26 : 0) + fit.stage + 8 + 86 + 12;
          expect(used, lessThanOrEqualTo(height + 0.001));
        }
      }
    });
  });

  group('the layout without the face', () {
    test('a stacked slip with no face keeps nothing below it', () {
      final layout = leavingReceiptLayoutFor(
        const Size(320, 244),
        rows: 4,
        textScale: 2,
        showsFace: false,
      );
      expect(layout.showsFace, isFalse);
      expect(layout.mascot, Rect.zero);
      expect(layout.plan.row, ReceiptPlan.rowMin);
    });

    test('with the face the stacked slip reserves its room', () {
      final layout = leavingReceiptLayoutFor(
        Size(320, slipWithFace),
        rows: 4,
        textScale: 2,
      );
      expect(layout.showsFace, isTrue);
      expect(layout.mascot.height, ReceiptPlan.mascotMin);
    });

    test('side by side the face is always there', () {
      final layout = leavingReceiptLayoutFor(
        const Size(320, 244),
        rows: 4,
        textScale: 1,
        showsFace: false,
      );
      expect(layout.showsFace, isTrue);
    });
  });

  group('the shipped receipt is unchanged', () {
    test('its plan on a regular phone holds the same numbers', () {
      final plan = ReceiptPlan.of(const Size(390, 380), count: 4);
      expect(plan.row, ReceiptPlan.rowMax);
      expect(plan.paper.width, closeTo(218.4, 1e-9));
      expect(plan.paper.left, ReceiptPlan.side);
      expect(ReceiptPlan.minHeight(4), 16 + 11 + 155 + 104);
      expect(ReceiptPlan.maxHeight(4), 16 + 11 + 155 + 176);
    });
  });
}
