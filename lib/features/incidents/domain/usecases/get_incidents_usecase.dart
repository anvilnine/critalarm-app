import 'package:critalarm/core/api/api_client.dart' show maxIncidentLimit;
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// Parameters for querying incidents from the server.
///
/// [limit] is not nullable and defaults to [maxIncidentLimit], so a caller
/// that only wants to narrow by state or topic still sends a limit. Leaving
/// it off used to mean 20 rows from the server (api.md §3.2), which is how
/// paid History ended up showing 20 alarms.
class GetIncidentsParams {
  const GetIncidentsParams({
    this.limit = maxIncidentLimit,
    this.state,
    this.topic,
    this.since,
    this.fullRefresh = false,
  }) : assert(
         limit >= 1 && limit <= maxIncidentLimit,
         'limit must be between 1 and $maxIncidentLimit (api.md §3.2)',
       );

  final int limit;
  final String? state;
  final String? topic;

  /// Exclusive lower bound on `opened_at` (api.md §3.2). Null reads
  /// everything the window allows.
  final DateTime? since;

  /// Read the server's whole window instead of only what is new. Pull to
  /// refresh and a first launch with an empty store use this.
  final bool fullRefresh;
}

/// Usecase to fetch incidents from the repository.
class GetIncidentsUsecase
    implements UseCase<GetIncidentsParams, List<Incident>> {
  const GetIncidentsUsecase(this._repository);

  final IncidentRepository _repository;

  @override
  Future<AppResult<List<Incident>>> call([
    GetIncidentsParams params = const GetIncidentsParams(),
  ]) => _repository.getIncidents(
    limit: params.limit,
    state: params.state,
    topic: params.topic,
    since: params.since,
    fullRefresh: params.fullRefresh,
  );
}
