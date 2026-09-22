import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/api_client.dart' show maxIncidentLimit;
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

/// A guess written into the shared list before the server answered, and what
/// has to go back if the server says no.
@immutable
final class OptimisticAck {
  const OptimisticAck({required this.guess, required this.before});

  /// What was written into the list.
  final Incident guess;

  /// What the list held for that id before the guess.
  final Incident before;
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
    AccountIdentityChanges? identityChanges,
  }) : _now = now ?? DateTime.now,
       _identityChanges = identityChanges ?? appAccountIdentityChanges,
       super(const IncidentsState()) {
    _identityChanges.addListener(_onIdentityChanged);
  }

  /// How many incidents the shared list asks for.
  ///
  /// One list now serves Home, the topics list, topic detail, History and
  /// search, so it asks for the widest window any of them used to ask for.
  /// api.md §3.2 caps one call at [maxIncidentLimit]. History reaches past
  /// that by paging the phone's own copy instead of the wire.
  static const int listLimit = maxIncidentLimit;

  final GetIncidentsUsecase _getIncidents;

  /// The number on the app icon. Optional so a test can build the cubit
  /// without a platform channel behind it.
  final AppBadge? badge;

  final DateTime Function() _now;

  final AccountIdentityChanges _identityChanges;

  /// Same reason as the topic list: incidents belong to the account, so the
  /// history in memory is somebody else's once the identity changes, and
  /// [ensureLoaded] answers "already ready" rather than going back for it.
  void _onIdentityChanged() {
    if (isClosed) return;
    unawaited(refresh());
  }

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
  ///
  /// [full] reads the server's whole window instead of only what the phone
  /// has not seen (api.md §3.2). Pull to refresh uses it; a push landing and
  /// a screen opening do not need to.
  Future<void> refresh({bool full = false}) =>
      _inFlight ??= _fetch(full: full).whenComplete(() => _inFlight = null);

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

  /// Forgets every incident on [topic], because the topic itself is gone.
  ///
  /// The server deletes a topic's incidents along with it, so this is the app
  /// catching up rather than guessing. History stops listing alarms for a
  /// topic that no longer exists, and the badge drops the open ones.
  void dropTopic(String topic) {
    if (isClosed) return;
    final kept = state.incidents.where((i) => i.topic != topic).toList();
    if (kept.length == state.incidents.length) return;

    final order = IncidentUpdateOrder(_now());
    if (!_order.accepts(order)) return;
    _order = order;

    emit(state.copyWith(incidents: kept));
  }

  /// One incident, for a caller that only has one.
  void applyIncident(Incident incident) => applyIncidents([incident]);

  /// Marks [incident] acknowledged in the shared list now, before the request
  /// goes out, so every screen moves on the tap instead of on the answer.
  ///
  /// Hand the token back to [revert] if the server refuses it. A 409 is not a
  /// refusal: it means the incident was acknowledged somewhere else, so the
  /// guess was right and there is nothing to put back.
  OptimisticAck acknowledgeNow(Incident incident) {
    final held = state.incidents.where((i) => i.id == incident.id).firstOrNull;
    final before = held ?? incident;
    final guess = before.copyWith(
      state: IncidentStates.acked,
      ackedAt: before.ackedAt ?? _now(),
    );
    applyIncident(guess);
    return OptimisticAck(guess: guess, before: before);
  }

  /// Puts back what [ack] replaced.
  ///
  /// A rollback carries an old value, so the stale-write guard cannot be the
  /// thing that decides it: the guard compares when an update was asked for,
  /// and this one is being asked for now. It is decided by what the list still
  /// holds instead. The list only holds [OptimisticAck.guess] while nothing
  /// else has touched that incident, so a push or a list read that landed
  /// while the request was in the air wins and the rollback is dropped.
  void revert(OptimisticAck ack) {
    if (isClosed) return;
    final at = state.incidents.indexWhere((i) => i.id == ack.guess.id);
    if (at < 0 || !identical(state.incidents[at], ack.guess)) return;

    // Newer than anything asked for before the server refused, so an answer
    // still in the air cannot undo it.
    final order = IncidentUpdateOrder(_now());
    if (!_order.accepts(order)) return;
    _order = order;

    final merged = [...state.incidents]..[at] = ack.before;
    emit(state.copyWith(incidents: merged));
  }

  Future<void> _fetch({bool full = false}) async {
    final order = IncidentUpdateOrder(_now());
    emit(state.copyWith(isRefreshing: true));

    final result = await _getIncidents(
      // Repeats the default on purpose. The number that goes on the wire
      // belongs at the place that decides it, not only in a default.
      // ignore: avoid_redundant_argument_values
      GetIncidentsParams(limit: listLimit, fullRefresh: full),
    );
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

  @override
  Future<void> close() {
    _identityChanges.removeListener(_onIdentityChanged);
    return super.close();
  }
}
