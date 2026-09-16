import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/notifications/incident_update_order.dart';
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
    this.errorMessage,
  });

  final AppDataStatus status;

  /// The newest answer from the server, plus anything applied since. Kept
  /// through a refresh and through a failed one.
  final List<Topic> topics;

  /// A fetch is running right now. The list above is still the real one.
  final bool isRefreshing;

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
    String? errorMessage,
    bool clearError = false,
  }) {
    return TopicsState(
      status: status ?? this.status,
      topics: topics ?? this.topics,
      isRefreshing: isRefreshing ?? this.isRefreshing,
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
          errorMessage == other.errorMessage &&
          listEquals(topics, other.topics);

  @override
  int get hashCode =>
      Object.hash(status, isRefreshing, errorMessage, Object.hashAll(topics));
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
class TopicsCubit extends Cubit<TopicsState> {
  TopicsCubit(
    this._getTopics, {
    this._deleteTopic,
    this._incidents,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const TopicsState());

  final GetTopicsUsecase _getTopics;

  /// Optional so a test that never deletes can build the cubit without a
  /// repository behind it.
  final DeleteTopicUsecase? _deleteTopic;

  /// Deleting a topic on the server takes its incidents with it, so the shared
  /// incident list drops them here too rather than waiting for a fetch to
  /// notice. Optional for the same reason as above.
  final IncidentsCubit? _incidents;

  final DateTime Function() _now;

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
  Future<void> ensureLoaded() =>
      isClosed || state.isReady ? Future<void>.value() : refresh();

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
    if (isClosed) return null;

    return result.fold(
      (_) {
        // The server dropped this topic's incidents with it. Drop the copies
        // the app is holding, so History and the badge do not keep counting
        // alarms for a topic that is gone.
        _incidents?.dropTopic(name);
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
      (topics) => emit(
        state.copyWith(
          status: AppDataStatus.ready,
          topics: topics,
          isRefreshing: false,
          clearError: true,
        ),
      ),
      (failure) => emit(
        state.copyWith(
          status: AppDataStatus.failure,
          isRefreshing: false,
          errorMessage: failureMessage(failure),
        ),
      ),
    );
  }
}
