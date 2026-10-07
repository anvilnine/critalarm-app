import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/overall_state.dart';
import 'package:flutter_test/flutter_test.dart';

ReliabilityCheck _check(String id, ReliabilityState state) =>
    ReliabilityCheck(id: ReliabilityCheckId(id), state: state);

void main() {
  test('no checks is fine', () {
    expect(overallReliabilityState(const []), ReliabilityState.fine);
  });

  test('all fine is fine', () {
    expect(
      overallReliabilityState([
        _check('a', ReliabilityState.fine),
        _check('b', ReliabilityState.fine),
      ]),
      ReliabilityState.fine,
    );
  });

  test('one needs a look and the rest are fine needs a look', () {
    expect(
      overallReliabilityState([
        _check('a', ReliabilityState.fine),
        _check('b', ReliabilityState.needsLook),
      ]),
      ReliabilityState.needsLook,
    );
  });

  test('one broken wins over needs a look, whatever the order', () {
    final checks = [
      _check('a', ReliabilityState.broken),
      _check('b', ReliabilityState.needsLook),
      _check('c', ReliabilityState.fine),
    ];
    expect(overallReliabilityState(checks), ReliabilityState.broken);
    expect(
      overallReliabilityState(checks.reversed),
      ReliabilityState.broken,
    );
  });

  test('a check that is not on this phone is left out', () {
    expect(
      overallReliabilityState([
        _check('a', ReliabilityState.fine),
        _check('b', ReliabilityState.notOnThisPhone),
      ]),
      ReliabilityState.fine,
    );
    expect(
      overallReliabilityState([
        _check('a', ReliabilityState.notOnThisPhone),
        _check('b', ReliabilityState.notOnThisPhone),
      ]),
      ReliabilityState.fine,
    );
  });
}
