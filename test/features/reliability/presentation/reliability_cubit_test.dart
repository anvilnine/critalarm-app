import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements ReliabilityCheckSource {
  _Source(this.checks);

  List<ReliabilityCheck> checks;
  int reads = 0;

  @override
  Future<List<ReliabilityCheck>> read() async {
    reads++;
    return checks;
  }
}

class _ThrowingSource implements ReliabilityCheckSource {
  @override
  Future<List<ReliabilityCheck>> read() async => throw StateError('no');
}

ReliabilityCheck _check(String id, ReliabilityState state) =>
    ReliabilityCheck(id: ReliabilityCheckId(id), state: state);

void main() {
  test('starts empty and not loaded', () async {
    final cubit = ReliabilityCubit([]);
    expect(cubit.state, const ReliabilitySnapshot());
    expect(cubit.state.loaded, isFalse);
    await cubit.close();
  });

  test('gathers every source in order and sums them up', () async {
    final cubit = ReliabilityCubit([
      _Source([_check('a', ReliabilityState.fine)]),
      _Source([
        _check('b', ReliabilityState.needsLook),
        _check('c', ReliabilityState.fine),
      ]),
    ]);
    await cubit.refresh();
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.overall, ReliabilityState.needsLook);
    expect(cubit.state.checks.map((c) => c.id.value), ['a', 'b', 'c']);
    await cubit.close();
  });

  test(
    'checks that are not on this phone are left out of list and overall',
    () async {
      final cubit = ReliabilityCubit([
        _Source([
          _check('a', ReliabilityState.notOnThisPhone),
          _check('b', ReliabilityState.fine),
        ]),
      ]);
      await cubit.refresh();
      expect(cubit.state.checks.map((c) => c.id.value), ['b']);
      expect(cubit.state.overall, ReliabilityState.fine);
      await cubit.close();
    },
  );

  test('a broken check makes the overall state broken', () async {
    final cubit = ReliabilityCubit([
      _Source([_check('a', ReliabilityState.needsLook)]),
      _Source([_check('b', ReliabilityState.broken)]),
    ]);
    await cubit.refresh();
    expect(cubit.state.overall, ReliabilityState.broken);
    await cubit.close();
  });

  test('a source that throws loses its checks and nothing else', () async {
    final cubit = ReliabilityCubit([
      _ThrowingSource(),
      _Source([_check('a', ReliabilityState.fine)]),
    ]);
    await cubit.refresh();
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.checks.map((c) => c.id.value), ['a']);
    expect(cubit.state.overall, ReliabilityState.fine);
    await cubit.close();
  });

  test('refresh reads again and picks up a change', () async {
    final source = _Source([_check('a', ReliabilityState.fine)]);
    final cubit = ReliabilityCubit([source]);
    await cubit.refresh();
    source.checks = [_check('a', ReliabilityState.broken)];
    await cubit.refresh();
    expect(source.reads, 2);
    expect(cubit.state.overall, ReliabilityState.broken);
    await cubit.close();
  });

  test(
    'a refresh that finishes after the cubit closed emits nothing',
    () async {
      final cubit = ReliabilityCubit([
        _Source([_check('a', ReliabilityState.fine)]),
      ]);
      final pending = cubit.refresh();
      await cubit.close();
      await pending;
      expect(cubit.state.loaded, isFalse);
    },
  );
}
