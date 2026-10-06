import 'package:critalarm/features/topics/domain/count_card_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Upper bound on the card's inner width: the phone width less generous
  // page margins and the card's own padding.
  double inner(double phone) => phone - 32 - 28 - 32;

  test('the 375 phone at 1x stacks', () {
    expect(countCardStacks(innerWidth: inner(375), textScale: 1), isTrue);
  });

  test('the 430 phone at 1x stacks too', () {
    expect(countCardStacks(innerWidth: inner(430), textScale: 1), isTrue);
  });

  test('large text stacks', () {
    expect(countCardStacks(innerWidth: inner(430), textScale: 2), isTrue);
  });

  test('a wide card keeps the row', () {
    expect(countCardStacks(innerWidth: 600, textScale: 1), isFalse);
  });

  test('a wide card stacks once the text scale takes its room', () {
    expect(countCardStacks(innerWidth: 600, textScale: 1.5), isTrue);
  });

  test('a scale under 1 counts as 1', () {
    expect(
      countCardStacks(innerWidth: 600, textScale: 0.5),
      countCardStacks(innerWidth: 600, textScale: 1),
    );
  });
}
