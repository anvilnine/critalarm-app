import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/notifications/incident_update_order.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The incident list, as the whole app sees it.
@immutable
class IncidentsState {
  const IncidentsState({
    this.status = AppDataStatus.initial,
    this.incidents = const <Incident>[],
    this.isRefreshing = false,
    this.errorMessage,
  });

  final AppDataStatus status;

  /// The newest answer from the server, plus anything applied since. Kept
  /// through a refresh and through a failed one.
  final List<Incident> incidents;

  /// A fetch is running right now. The list above is still the real one.
  final bool isRefreshing;

  final String? errorMessage;

  bool get isReady => status == AppDataStatus.ready;

  List<Incident> get openIncidents =>
      incidents.where((i) => i.isOpen).toList(growable: false);

  /// The incidents on one topic, newest answer first.
  List<Incident> forTopic(String topic) =>
      incidents.where((i) => i.topic == topic).toList(growable: false);

  IncidentsState copyWith({
    AppDataStatus? status,
    List<Incident>? incidents,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return IncidentsState(
      status: status ?? this.status,
      incidents: incidents ?? this.incidents,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncidentsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          isRefreshing == other.isRefreshing &&
          errorMessage == other.errorMessage &&
          listEquals(incidents, other.incidents);

  @override
  int get hashCode => Object.hash(
    status,
    isRefreshing,
    errorMessage,
    Object.hashAll(incidents),
  );
}

/// The one incident list in the app.
///
/// Screens read it and listen to it. Nothing else fetches incidents, so a
/// screen opening does not repeat a request another screen already made, and
/// acknowledging on one screen is visible on all of them.
class IncidentsCubit extends Cubit<IncidentsState> {
  IncidentsCubit(
    this._getIncidents, {
    this.badge,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const IncidentsState());

  final GetIncidentsUsecase _getIncidents;

  /// The number on the app icon. Optional so a test can build the cubit
  /// without a platform channel behind it.
  final AppBadge? badge;

  final DateTime Function() _now;

  /// When the newest update in the state was asked for. An update asked for
  /// before that one is older than what the app already has, so it is dropped
  /// instead of being allowed to undo it.
  IncidentUpdateOrder _order = IncidentUpdateOrder(
    DateTime.fromMillisecondsSinceEpoch(0),
  );

  Future<void>? _inFlight;

  /// Loads once. A screen that opens after another screen already loaded reads
  /// what is in memory instead of asking the server again.
  Future<void> ensureLoaded() =>
      isClosed || state.isReady ? Future<void>.value() : refresh();

  /// Asks the server again. The list already loaded stays in the state while
  /// the request is in the air, and two refreshes that overlap share one
  /// request.
  Future<void> refresh() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  /// Puts incidents the caller already has fresh into the shared list: the
  /// answer to an acknowledge, and later a push that arrives while the app is
  /// open. Nothing is fetched, because the caller already has the server's
  /// answer.
  void applyIncidents(Iterable<Incident> incidents) {
    if (isClosed || incidents.isEmpty) return;
    final order = IncidentUpdateOrder(_now());
    if (!_order.accepts(order)) return;
    _order = order;

    final merged = [...state.incidents];
    for (final incident in incidents) {
      final at = merged.indexWhere((i) => i.id == incident.id);
      if (at < 0) {
        merged.insert(0, incident);
      } else {
        merged[at] = incident;
      }
    }
    emit(state.copyWith(incidents: merged));
  }

  /// One incident, for a caller that only has one.
  void applyIncident(Incident incident) => applyIncidents([incident]);

  Future<void> _fetch() async {
    final order = IncidentUpdateOrder(_now());
    emit(state.copyWith(isRefreshing: true));

    final result = await _getIncidents();
    if (isClosed) return;

    // An answer asked for before the newest update in the state is older than
    // what is on screen. Keep the newer one and throw this away.
    if (!_order.accepts(order)) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }
    _order = order;

    result.fold(
      (incidents) => emit(
        state.copyWith(
          status: AppDataStatus.ready,
          incidents: incidents,
          isRefreshing: false,
          clearError: true,
        ),
      ),
      (failure) => emit(
        state.copyWith(
          status: AppDataStatus.failure,
          isRefreshing: false,
          errorMessage: failure.message,
        ),
      ),
    );
  }

  /// The badge follows the list. Every path that changes the incidents ends
  /// here, including a queued acknowledge that only reaches the server minutes
  /// later, so there is nothing to remember to call at an acknowledge site.
  @override
  void onChange(Change<IncidentsState> change) {
    super.onChange(change);
    final next = change.nextState.incidents;
    if (identical(next, change.currentState.incidents)) return;
    unawaited(badge?.setCount(next.where((i) => i.isOpen).length));
  }
}
