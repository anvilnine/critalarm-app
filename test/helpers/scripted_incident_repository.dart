import 'dart:async';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// An incident server a test can hold still.
///
/// Acknowledges wait on [gate] while it is open, so a test can look at what
/// the app drew before the server answered. [refuse] makes one id fail. An ack
/// that goes through changes the stored incident, so a later list read tells
/// the same story the ack did.
class ScriptedIncidentRepository implements IncidentRepository {
  ScriptedIncidentRepository(List<Incident> incidents)
    : _store = {for (final incident in incidents) incident.id: incident};

  final Map<String, Incident> _store;

  /// What the server answers per incident id. Anything not listed succeeds.
  final Map<String, Failure> refuse = {};

  /// Acknowledges are held until this completes. Null lets them through.
  Completer<void>? gate;

  /// One entry per acknowledge the app sent, in order.
  final sent = <String>[];

  Incident stored(String id) => _store[id]!;

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
  }) async => _store.values
      .where((i) => state == null || i.state == state)
      .where((i) => topic == null || i.topic == topic)
      .toList()
      .toSuccess();

  @override
  Future<AppResult<Incident>> getIncident(String id) async {
    final incident = _store[id];
    return incident == null
        ? const Failure.notFound().toFailure()
        : incident.toSuccess();
  }

  @override
  Future<AppResult<Incident>> ackIncident(String id) async {
    sent.add(id);
    await gate?.future;
    final acked = _store[id]!.copyWith(
      state: IncidentStates.acked,
      ackedAt: DateTime.now(),
    );
    final failure = refuse[id];
    if (failure != null) {
      // A 409 says the incident was acknowledged somewhere else, so a later
      // list read has to tell that story too.
      if (failure is ApiFailure && failure.statusCode == 409) {
        _store[id] = acked;
      }
      return failure.toFailure();
    }
    _store[id] = acked;
    return acked.toSuccess();
  }

  @override
  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async => <Message>[].toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
