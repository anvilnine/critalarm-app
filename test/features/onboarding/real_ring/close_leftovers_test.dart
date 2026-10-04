import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_setup_test_ring.dart';

class _MockAck extends Mock implements AcknowledgeIncidentUsecase {}

class _MockClose extends Mock implements CloseIncidentUsecase {}

void main() {
  late FakeSetupTestRing ring;
  late _MockAck ack;
  late _MockClose close;
  var holds = <String, bool?>{};

  EndSetupTestUsecase build() =>
      EndSetupTestUsecase(ring, ack, close, (id) async => holds[id]);

  setUp(() async {
    ring = FakeSetupTestRing();
    ack = _MockAck();
    close = _MockClose();
    holds = {};
    when(() => ack(any())).thenAnswer(
      (_) async => const Incident(id: 'x', topic: 'nightly').toSuccess(),
    );
    when(() => close(any())).thenAnswer(
      (_) async => const Incident(id: 'x', topic: 'nightly').toSuccess(),
    );
    // A test whose close failed earlier.
    await ring.hold('inc_test');
    await ring.markUnclosed('inc_test');
  });

  test('a leftover that is only a test is closed', () async {
    holds['inc_test'] = false;

    await build().closeLeftovers();

    verify(() => close('inc_test')).called(1);
    expect(ring.unclosedIds, isEmpty);
  });

  test(
    'a leftover that now holds a message of the user is left to them',
    () async {
      holds['inc_test'] = true;

      await build().closeLeftovers();

      verifyNever(() => ack(any()));
      verifyNever(() => close(any()));
      // Dropped from the list, so it is not asked about again.
      expect(ring.unclosedIds, isEmpty);
    },
  );

  test('a leftover that cannot be read waits for the next open', () async {
    holds['inc_test'] = null;

    await build().closeLeftovers();

    verifyNever(() => close(any()));
    expect(ring.unclosedIds, {'inc_test'});
  });

  test('a read that throws is treated the same', () async {
    final usecase = EndSetupTestUsecase(
      ring,
      ack,
      close,
      (id) async => throw Exception('offline'),
    );

    await usecase.closeLeftovers();

    verifyNever(() => close(any()));
    expect(ring.unclosedIds, {'inc_test'});
  });

  test('with no way to read, every leftover is closed as before', () async {
    await EndSetupTestUsecase(ring, ack, close).closeLeftovers();

    verify(() => close('inc_test')).called(1);
  });
}
