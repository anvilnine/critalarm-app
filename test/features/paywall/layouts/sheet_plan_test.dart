import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two phones every layout must fit, with their insets.
const _phones = <({double height, double top, double bottom, bool compact})>[
  (height: 844, top: 47, bottom: 22, compact: false),
  (height: 667, top: 20, bottom: 0, compact: true),
];

/// Buy block heights to plan with: a tall one with a plan picker and a
/// short one without.
double _buyBlock({required bool isHosted}) => isHosted ? 262 : 180;

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
  buyBlockHeight: _buyBlock(isHosted: isHosted),
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
                buyBlockHeight: _buyBlock(isHosted: isHosted),
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

  test('a plan made before the buy block has a height is never drawn', () {
    for (final phone in _phones) {
      final plan = sheetPlanFor(
        screenHeight: phone.height,
        topInset: phone.top,
        bottomInset: phone.bottom,
        isCompact: phone.compact,
        buyBlockHeight: null,
        isSwitch: false,
        benefitCount: 1,
      );
      expect(plan.rowsAbove, 0);
      expect(plan.isMeasured, isFalse);
    }
  });

  test('the first plan drawn has the rows the settled plan has', () {
    for (final phone in _phones) {
      for (final isHosted in [true, false]) {
        for (var count = 1; count <= 7; count++) {
          // What the layout plans with as its frames go by: nothing on the
          // first, then the height the kit measured.
          final height = _buyBlock(isHosted: isHosted);
          final frames = [
            for (final measured in <double?>[null, height, height])
              sheetPlanFor(
                screenHeight: phone.height,
                topInset: phone.top,
                bottomInset: phone.bottom,
                isCompact: phone.compact,
                buyBlockHeight: measured,
                isSwitch: isHosted,
                benefitCount: count,
              ),
          ];
          final drawn = frames.where((plan) => plan.isMeasured).toList();
          expect(drawn, hasLength(2));
          expect(drawn.first.rowsAbove, frames.last.rowsAbove);
          expect(drawn.first.sheetTop, frames.last.sheetTop);
        }
      }
    }
  });

  test('a guess would have moved: Pro on the tall phone keeps a quiet row '
      'once measured', () {
    final plan = _plan(
      _phones.first,
      isHosted: false,
      isSwitch: false,
      benefitCount: 1,
    );
    expect(plan.isMeasured, isTrue);
    expect(plan.rowsAbove, greaterThan(0));
  });

  test('past the default text size the plan needs no height, so the first '
      'frame is drawn', () {
    for (final phone in _phones) {
      final plan = sheetPlanFor(
        screenHeight: phone.height,
        topInset: phone.top,
        bottomInset: phone.bottom,
        isCompact: phone.compact,
        buyBlockHeight: null,
        isSwitch: false,
        benefitCount: 1,
        textScale: 1.3,
      );
      expect(plan.isMeasured, isTrue);
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
