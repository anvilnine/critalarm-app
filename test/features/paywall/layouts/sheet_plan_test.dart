import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two phones every layout must fit, with their insets.
const _phones = <({double height, double top, double bottom, bool compact})>[
  (height: 844, top: 47, bottom: 22, compact: false),
  (height: 667, top: 20, bottom: 0, compact: true),
];

SheetPlan _plan(
  ({double height, double top, double bottom, bool compact}) phone, {
  required bool isHosted,
  required bool isSwitch,
  required int benefitCount,
  double textScale = 1,
}) => sheetPlanFor(
  screenHeight: phone.height,
  topInset: phone.top,
  bottomInset: phone.bottom,
  isCompact: phone.compact,
  isHosted: isHosted,
  isSwitch: isSwitch,
  benefitCount: benefitCount,
  textScale: textScale,
);

void main() {
  test('the lit row is always above the sheet, with room for the face', () {
    for (final phone in _phones) {
      for (final isHosted in [true, false]) {
        for (final isSwitch in [true, false]) {
          for (var count = 0; count <= 7; count++) {
            final plan = _plan(
              phone,
              isHosted: isHosted,
              isSwitch: isSwitch,
              benefitCount: count,
            );
            expect(plan.litTop, greaterThan(phone.top));
            expect(plan.sheetTop, greaterThan(plan.litBottom));
            expect(
              plan.sheetTop - plan.litBottom,
              greaterThanOrEqualTo(plan.faceSize / 2),
            );
            expect(plan.rowsAbove, inInclusiveRange(0, SheetPlan.maxRowsAbove));
          }
        }
      }
    }
  });

  test('the sheet keeps more than half the screen', () {
    for (final phone in _phones) {
      for (final isHosted in [true, false]) {
        for (var count = 1; count <= 7; count++) {
          final plan = _plan(
            phone,
            isHosted: isHosted,
            isSwitch: isHosted,
            benefitCount: count,
          );
          expect(phone.height - plan.sheetTop, greaterThan(phone.height / 2));
        }
      }
    }
  });

  test('a quiet row is kept only while the sheet has the height it wants', () {
    for (final phone in _phones) {
      for (final isHosted in [true, false]) {
        for (var count = 1; count <= 7; count++) {
          final plan = _plan(
            phone,
            isHosted: isHosted,
            isSwitch: isHosted,
            benefitCount: count,
          );
          if (plan.rowsAbove == 0) continue;
          expect(
            phone.height - plan.sheetTop,
            greaterThanOrEqualTo(
              sheetWantedHeight(
                isCompact: phone.compact,
                isHosted: isHosted,
                benefitCount: count,
                bottomInset: phone.bottom,
              ),
            ),
          );
        }
      }
    }
  });

  test('a short sheet shows more of the screen behind than a long one', () {
    final tall = _phones.first;
    final one = _plan(tall, isHosted: false, isSwitch: false, benefitCount: 1);
    final five = _plan(tall, isHosted: true, isSwitch: true, benefitCount: 5);

    expect(one.rowsAbove, greaterThan(five.rowsAbove));
    expect(one.sheetTop, greaterThan(five.sheetTop));
  });

  test('more benefits never show more of the screen behind', () {
    for (final phone in _phones) {
      var last = SheetPlan.maxRowsAbove;
      for (var count = 1; count <= 7; count++) {
        final rows = _plan(
          phone,
          isHosted: false,
          isSwitch: false,
          benefitCount: count,
        ).rowsAbove;
        expect(rows, lessThanOrEqualTo(last));
        last = rows;
      }
    }
  });

  test('past the default text size no quiet row is kept', () {
    for (final phone in _phones) {
      final plan = _plan(
        phone,
        isHosted: false,
        isSwitch: false,
        benefitCount: 1,
        textScale: 1.3,
      );
      expect(plan.rowsAbove, 0);
    }
  });

  test('the switch row is taller than a locked row', () {
    for (final isCompact in [true, false]) {
      expect(
        sheetLitHeight(isCompact: isCompact, isSwitch: true),
        greaterThan(sheetLitHeight(isCompact: isCompact, isSwitch: false)),
      );
    }
  });
}
