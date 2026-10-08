import 'package:critalarm/features/reliability/domain/attention_order.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:flutter_test/flutter_test.dart';

ReliabilityCheck _check(
  String id, [
  ReliabilityState state = ReliabilityState.fine,
  ReliabilityFix? fix,
]) => ReliabilityCheck(id: ReliabilityCheckId(id), state: state, fix: fix);

List<String> _ids(Iterable<ReliabilityCheck> checks) => [
  for (final check in checks) check.id.value,
];

void main() {
  group('orderByAttention', () {
    test('puts broken first, then needs a look, then fine', () {
      final ordered = orderByAttention([
        _check('a'),
        _check('b', ReliabilityState.needsLook),
        _check('c', ReliabilityState.broken),
        _check('d'),
      ]);
      expect(_ids(ordered), ['c', 'b', 'a', 'd']);
    });

    test('keeps the source order inside one state', () {
      final ordered = orderByAttention([
        _check('a', ReliabilityState.needsLook),
        _check('b', ReliabilityState.needsLook),
        _check('c', ReliabilityState.needsLook),
      ]);
      expect(_ids(ordered), ['a', 'b', 'c']);
    });

    test('drops a check that is not on this phone', () {
      final ordered = orderByAttention([
        _check('a'),
        _check('b', ReliabilityState.notOnThisPhone),
      ]);
      expect(_ids(ordered), ['a']);
    });
  });

  group('worstCheck', () {
    test('is the first broken check, else the first needing a look', () {
      final checks = [
        _check('a'),
        _check('b', ReliabilityState.needsLook),
        _check('c'),
        _check('d', ReliabilityState.broken),
      ];
      expect(worstCheck(checks)?.id.value, 'd');
      expect(worstCheck(checks.take(3))?.id.value, 'b');
    });

    test('is null when every check is fine', () {
      expect(worstCheck([_check('a'), _check('b')]), isNull);
      expect(worstCheck(const []), isNull);
    });
  });

  group('checkToFix', () {
    const fix = OpenRouteFix('somewhere');

    test('skips a broken check that has nothing to do', () {
      final checks = [
        _check('a', ReliabilityState.broken),
        _check('b', ReliabilityState.needsLook, fix),
      ];
      expect(checkToFix(checks)?.fix, fix);
    });

    test('a broken check with a fix goes before a look check with one', () {
      const brokenFix = OpenRouteFix('broken');
      final checks = [
        _check('a', ReliabilityState.needsLook, fix),
        _check('b', ReliabilityState.broken, brokenFix),
      ];
      expect(checkToFix(checks)?.fix, brokenFix);
    });

    test('a fine check with a fix is not offered', () {
      expect(checkToFix([_check('a', ReliabilityState.fine, fix)]), isNull);
    });

    test('is null when nothing that needs attention has a fix', () {
      expect(checkToFix([_check('a', ReliabilityState.broken)]), isNull);
    });
  });

  test('the Reliability screen and the Home card pick the same fix', () {
    const lookFix = OpenRouteFix('look');
    const brokenFix = OpenRouteFix('broken');
    final checks = [
      _check('a'),
      _check('b', ReliabilityState.needsLook, lookFix),
      _check('c', ReliabilityState.broken),
      _check('d', ReliabilityState.broken, brokenFix),
      _check('e', ReliabilityState.notOnThisPhone),
    ];
    final ordered = orderReliabilityChecks(checks);
    final primary = reliabilityPrimaryRow(ordered);
    expect(primary, isNotNull);
    expect(ordered[primary!].id, checkToFix(checks)?.id);
    expect(_ids(ordered), _ids(orderByAttention(checks)));
  });
}
