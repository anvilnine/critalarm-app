import 'dart:async';

import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/api/scoped_api_client.dart';
import 'package:critalarm/core/api/stale_account_exception.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';

/// Calls that wait on [gate], then fail or answer.
final class _GatedAcks extends MockApiClient {
  _GatedAcks() : super(MockServer());

  final gate = Completer<void>();
  Exception? failWith;

  @override
  Future<Incident> ackIncident(String id) async {
    await gate.future;
    final error = failWith;
    if (error != null) throw error;
    return super.ackIncident(id);
  }

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
  }) async {
    await gate.future;
    return const <Incident>[];
  }
}

void main() {
  late String account;
  late _GatedAcks inner;
  late ScopedApiClient api;

  setUp(() {
    account = 'acc_a';
    inner = _GatedAcks();
    api = ScopedApiClient(inner, readScope: () async => account);
  });

  test(
    'an error that lands after the account changed reaches the caller as it is',
    () async {
      final timeout = TimeoutException('slow network');
      inner.failWith = timeout;
      final call = api.ackIncident('inc_1');
      account = 'acc_b';
      inner.gate.complete();

      await expectLater(call, throwsA(same(timeout)));
    },
  );

  test('an answer that lands after the account changed is stale', () async {
    final call = api.getIncidents(limit: 10);
    account = 'acc_b';
    inner.gate.complete();

    await expectLater(call, throwsA(isA<StaleAccountException>()));
  });
}
