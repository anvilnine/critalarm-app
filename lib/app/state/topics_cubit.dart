import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/notifications/incident_update_order.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The topic list, as the whole app sees it.
@immutable
class TopicsState {
  const TopicsState({
    this.status = AppDataStatus.initial,
    this.topics = const <Topic>[],
    this.isRefreshing = false,
    this.isKept = false,
    this.errorMessage,
  });

  final AppDataStatus status;

  /// The newest answer from the server, plus anything applied since. Kept
  /// through a refresh and through a failed one. Right after launch it is the
  /// copy the phone kept from the last answer, until the server gives a new
  /// one ([isKept]).
  final List<Topic> topics;

  /// A fetch is running right now. The list above is still the real one.
  final bool isRefreshing;

  /// The list is the copy kept on the phone and the server has not answered
  /// in this run yet. It is real data and [isReady] is true, so screens draw
  /// it as they draw any list. A screen that would ask the server for
  /// something per topic waits for the answer instead, so it does not ask
  /// twice. Cleared by the first answer, and by nothing else.
  final bool isKept;

  final String? errorMessage;

  bool get isReady => status == AppDataStatus.ready;

  /// The topic with this name, or null when the list does not have one.
  Topic? named(String name) {
    for (final topic in topics) {
      if (topic.name == name) return topic;
    }
    return null;
  }

  TopicsState copyWith({
    AppDataStatus? status,
    List<Topic>? topics,
    bool? isRefreshing,
    bool? isKept,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TopicsState(
      status: status ?? this.status,
      topics: topics ?? this.topics,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isKept: isKept ?? this.isKept,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          isRefreshing == other.isRefreshing &&
          isKept == other.isKept &&
          errorMessage == other.errorMessage &&
          listEquals(topics, other.topics);

  @override
  int get hashCode => Object.hash(
    status,
    isRefreshing,
    isKept,
    errorMessage,
    Object.hashAll(topics),
  );
}

/// A topic taken out of the shared list before the server agreed to it.
@immutable
final class RemovedTopic {
  const RemovedTopic({required this.topic, required this.at});

  /// What was taken out.
  final Topic topic;

  /// Where it sat, so putting it back does not move it to the end of the list.
  final int at;
}

/// The one topic list in the app.
///
/// Screens read it and listen to it. Nothing else fetches topics, so a screen
/// opening does not repeat a request another screen already made.
///
/// With a [TopicStore] the list also lives on the phone. [loadHeld] starts the
/// state from the copy kept at the last answer, so a screen opens with the
/// topics the phone knows, and the first server answer replaces it. Every
/// change to the list is written back. The copy is for one server and one
/// account: [_heldScope] names them, and a copy read or written for any other
/// scope is ignored.
class TopicsCubit extends Cubit<TopicsState> {
  TopicsCubit(
    this._getTopics, {
    this._deleteTopic,
    this._incidents,
    this._onDeleted,
    this._held,
    this._heldScope,
    DateTime Function()? now,
    AccountIdentityChanges? identityChanges,
  }) : _now = now ?? DateTime.now,
       _identityChanges = identityChanges ?? appAccountIdentityChanges,
       super(const TopicsState()) {
    _identityChanges.addListener(_onIdentityChanged);
  }

  /// The copy on the phone, or null where there is none to keep: the web
  /// build, a store that would not open, a test that does not care.
  final TopicStore? _held;

  /// Names the server and account the phone is on now (`heldScopeFor`), or
  /// null when it is on none.
  final Future<String?> Function()? _heldScope;

  final GetTopicsUsecase _getTopics;

  /// Optional so a test that never deletes can build the cubit without a
  /// repository behind it.
  final DeleteTopicUsecase? _deleteTopic;

  /// Called with the name once the server has deleted a topic, so what
  /// this phone keeps for that topic alone can go with it (its wake-up
  /// challenge). A failure in it never turns a delete into an error.
  final Future<void> Function(String name)? _onDeleted;

  /// Deleting a topic on the server takes its incidents with it, so the shared
  /// incident list drops them here too rather than waiting for a fetch to
  /// notice. Optional for the same reason as above.
  final IncidentsCubit? _incidents;

  final DateTime Function() _now;

  final AccountIdentityChanges _identityChanges;

  /// Somebody signed in, signed out, linked another provider or deleted the
  /// account. Topics belong to the account, so the list in memory is somebody
  /// else's now. [ensureLoaded] would not notice: it answers "already ready"
  /// even when what it is holding is an empty list from the account that was
  /// just left, which is how signing in used to show "No topics yet" until the
  /// app was killed.
  void _onIdentityChanged() {
    if (isClosed) return;
    // An answer asked for before this belongs to the account that was just
    // left. It may still be drawn when it lands, as before, but it is not
    // written to the phone.
    _generation++;
    unawaited(refresh());
  }

  /// Counts identity changes. A fetch remembers the number it started under
  /// and writes to the phone only while it is still the same.
  int _generation = 0;

  /// The writes to the phone, one after another so an older list never lands
  /// on top of a newer one.
  Future<void> _writes = Future<void>.value();

  /// Completes when every write started so far has finished. For tests.
  @visibleForTesting
  Future<void> get writesDone => _writes;

  Future<String?> _askScope() async {
    try {
      return await _heldScope?.call();
    } on Object catch (_) {
      return null;
    }
  }

  /// Starts the state from the list the phone kept, when nothing else has
  /// filled it yet.
  ///
  /// The state is ready and [TopicsState.isKept], so screens draw the topics
  /// at once and a refresh still goes to the server ([ensureLoaded]). A phone
  /// that holds nothing for the account and server it is on, a store that
  /// cannot be read and a list that came from the server first all leave the
  /// state as it was. Never throws.
  Future<void> loadHeld() async {
    final store = _held;
    if (store == null || isClosed) return;
    try {
      final scope = await _askScope();
      if (scope == null) return;
      final topics = await store.read(scope);
      if (topics == null || topics.isEmpty || isClosed) return;
      // The server answered while the phone was being read.
      if (state.status != AppDataStatus.initial) return;
      emit(
        state.copyWith(
          status: AppDataStatus.ready,
          topics: topics,
          isKept: true,
        ),
      );
    } on Object catch (error) {
      // A copy that will not read is no copy. The list loads from the server
      // as it always did.
      debugPrint('topics_held_read_failed error=${error.runtimeType}');
    }
  }

  /// Writes [topics] to the phone for the account and server it is on now.
  ///
  /// [asked] is the scope read when the request behind [topics] went out and
  /// [generation] the identity count then. The write goes ahead only when the
  /// phone is still on that scope, so an answer for an account that was left
  /// while the request was in the air is never kept under the next one.
  void _remember(
    List<Topic> topics, {
    Future<String?>? asked,
    int? generation,
  }) {
    final store = _held;
    if (store == null) return;
    final startedAs = asked ?? _askScope();
    final startedAt = generation ?? _generation;
    final snapshot = [...topics];
    _writes = _writes.then((_) async {
      try {
        final scope = await startedAs;
        if (scope == null || startedAt != _generation) return;
        if (scope != await _askScope()) return;
        await store.replaceAll(scope, snapshot);
      } on Object catch (error) {
        debugPrint('topics_held_write_failed error=${error.runtimeType}');
      }
    });
  }

  /// Keeps a topic this phone just made in the copy on the phone, ahead of the
  /// next answer from the server. The list in memory is left alone: the new
  /// topic reaches it with the next refresh, which setup and Home both ask
  /// for. Nothing is written until a list is loaded, because the copy would
  /// otherwise hold this one topic as if it were all of them.
  void noteCreated(Topic topic) {
    if (isClosed || state.status == AppDataStatus.initial) return;
    _remember([
      for (final t in state.topics)
        if (t.name != topic.name) t,
      _withoutSecrets(topic),
    ]);
  }

  /// [topic] as the list route returns it. A token, its id and its name come
  /// only with a created topic, and none of them is kept.
  Topic _withoutSecrets(Topic topic) =>
      topic.copyWith(token: null, tokenId: null, tokenName: null);

  /// When the newest update in the state was asked for. Same guard the
  /// incidents use, and for the same reason: a list read that went out before
  /// the user switched critical delivery on must not come back and show it
  /// off again. [IncidentUpdateOrder] is about ordering rather than about
  /// incidents, so it is reused rather than copied.
  IncidentUpdateOrder _order = IncidentUpdateOrder(
    DateTime.fromMillisecondsSinceEpoch(0),
  );

  Future<void>? _inFlight;

  /// Loads once. A screen that opens after another screen already loaded reads
  /// what is in memory instead of asking the server again.
  ///
  /// A list the phone kept ([TopicsState.isKept]) is not a load: the server is
  /// still asked once.
  Future<void> ensureLoaded() => isClosed || (state.isReady && !state.isKept)
      ? Future<void>.value()
      : refresh();

  /// Asks the server again. The list already loaded stays in the state while
  /// the request is in the air, and two refreshes that overlap share one
  /// request.
  Future<void> refresh() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  /// Puts a topic the caller already has fresh into the shared list, such as
  /// the answer to switching critical delivery on. Nothing is fetched.
  void applyTopic(Topic topic) {
    if (isClosed) return;
    final order = IncidentUpdateOrder(_now());
    if (!_order.accepts(order)) return;
    _order = order;

    final merged = [...state.topics];
    final at = merged.indexWhere((t) => t.name == topic.name);
    if (at < 0) {
      merged.add(topic);
    } else {
      merged[at] = topic;
    }
    emit(state.copyWith(topics: merged));
    if (state.status != AppDataStatus.initial) _remember(merged);
  }

  /// Deletes a topic, taking it out of the shared list before asking.
  ///
  /// Returns null when the server took it, or the reason when it refused. A
  /// refusal puts the topic back where it was.
  ///
  /// This lives here rather than on the topic screen's own cubit because the
  /// screen pops as soon as it is called, and a closed cubit cannot finish the
  /// request or do anything with the answer.
  Future<String?> deleteTopic(String name) async {
    final usecase = _deleteTopic;
    if (usecase == null) return null;

    final removed = _removeNow(name);
    final result = await usecase(name);
    if (result.isSuccess()) {
      try {
        await _onDeleted?.call(name);
      } on Object catch (_) {
        // The topic is gone on the server. What is left on the phone for
        // it asks for nothing without a topic to ring.
      }
    }
    if (isClosed) return null;

    return result.fold(
      (_) {
        // The server dropped this topic's incidents with it. Drop the copies
        // the app is holding, so History and the badge do not keep counting
        // alarms for a topic that is gone.
        _incidents?.dropTopic(name);
        // The server took it, so the copy on the phone loses it now. Before
        // that the topic was only out of the list on screen.
        if (state.status != AppDataStatus.initial) _remember(state.topics);
        return null;
      },
      (failure) {
        final message = failureMessage(failure);
        if (removed != null) _restore(removed);
        emit(state.copyWith(errorMessage: message));
        return message;
      },
    );
  }

  /// Takes [name] out of the shared list now, so the screen behind the one
  /// popping is already right. Null when the list never held it.
  RemovedTopic? _removeNow(String name) {
    if (isClosed) return null;
    final at = state.topics.indexWhere((t) => t.name == name);
    if (at < 0) return null;

    final order = IncidentUpdateOrder(_now());
    if (!_order.accepts(order)) return null;
    _order = order;

    final removed = RemovedTopic(topic: state.topics[at], at: at);
    emit(
      state.copyWith(topics: [...state.topics]..removeAt(at), clearError: true),
    );
    return removed;
  }

  /// Puts back what a refused delete took out.
  ///
  /// Dropped when the list holds that name again already: a fetch that landed
  /// while the delete was in the air is the newer truth.
  void _restore(RemovedTopic removed) {
    if (isClosed || state.named(removed.topic.name) != null) return;

    final order = IncidentUpdateOrder(_now());
    if (!_order.accepts(order)) return;
    _order = order;

    final merged = [...state.topics]
      ..insert(removed.at.clamp(0, state.topics.length), removed.topic);
    emit(state.copyWith(topics: merged));
  }

  Future<void> _fetch() async {
    final order = IncidentUpdateOrder(_now());
    // Asked now, beside the request, so the answer is kept for the account the
    // request went out as.
    final asked = _askScope();
    final generation = _generation;
    emit(state.copyWith(isRefreshing: true));

    final result = await _getTopics(const NoParams());
    if (isClosed) return;

    // An answer asked for before the newest update in the state is older than
    // what is on screen. Keep the newer one and throw this away.
    if (!_order.accepts(order)) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }
    _order = order;

    result.fold(
      (topics) {
        // The server's list replaces the one the phone kept, topic for topic:
        // one deleted elsewhere is gone from both.
        emit(
          state.copyWith(
            status: AppDataStatus.ready,
            topics: topics,
            isRefreshing: false,
            isKept: false,
            clearError: true,
          ),
        );
        _remember(topics, asked: asked, generation: generation);
      },
      // A failed answer keeps the list, held or not, and says so as it did.
      (failure) => emit(
        state.copyWith(
          status: AppDataStatus.failure,
          isRefreshing: false,
          errorMessage: failureMessage(failure),
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _identityChanges.removeListener(_onIdentityChanged);
    return super.close();
  }
}
