import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/held_archive.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_glances.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_message_rows.dart';
import 'package:flutter/foundation.dart';

/// What the plan lets History and the message lists show, read once at launch.
@immutable
class HeldPlan {
  const HeldPlan({required this.hasLongHistory, required this.historyDays});

  /// Hosted, or a server of the user's own: everything held is shown.
  final bool hasLongHistory;

  /// The cap the registration sent, in days.
  final int historyDays;

  int get shownDays => HistoryWindow.shownDays(
    hasLongHistory: hasLongHistory,
    historyDays: historyDays,
  );
}

/// The alarms and messages the phone held at launch, read for the screens
/// that open before the server has answered.
///
/// It is a copy of the phone's own archive for the account the phone is on,
/// taken once, in memory. It is not the shared incident list: nothing that
/// rings, notifies, badges or hands over to the alarm screen reads it. Home,
/// History and the Topic screen read it for their first frame, and the
/// server's answer replaces what they drew.
///
/// It is good only until the server has answered. The first incident answer
/// and any change of account drop it, so a screen opened after that reads the
/// phone itself.
@immutable
class HeldSnapshot {
  const HeldSnapshot({
    required this.incidents,
    required this.messages,
    required this.plan,
    required this.bound,
    required this.olderCount,
  });

  /// The newest incidents held, newest first. Open only when the phone's last
  /// stored answer for the incident said open.
  final List<Incident> incidents;

  /// The newest messages held for each topic the phone knows, newest first.
  final Map<String, List<Message>> messages;

  final HeldPlan plan;

  /// The oldest alarm or message the plan shows, or null for all of them.
  final DateTime? bound;

  /// How many held incidents sit before [bound].
  final int olderCount;
}

/// Reads the [HeldSnapshot] before the first frame.
class HeldRows {
  HeldRows(
    this._archive,
    this._topics,
    this._incidents, {
    required this.glances,
    required this.readPlan,
    DateTime Function()? now,
    AccountIdentityChanges? identityChanges,
    this.planTimeout = const Duration(milliseconds: 500),
  }) : _now = now ?? DateTime.now,
       _identityChanges = identityChanges ?? appAccountIdentityChanges {
    _identityChanges.addListener(_drop);
    _incidentsSub = _incidents.stream.listen((state) {
      if (state.isReady) _drop();
    });
  }

  final HeldArchive _archive;
  final TopicsCubit _topics;
  final IncidentsCubit _incidents;

  /// Topic screens read the messages noted here for their first frame, so the
  /// snapshot notes each topic's rows before any screen opens.
  final TopicGlances glances;

  /// The plan, or null when it cannot be read. A snapshot is never taken
  /// without it, because the window decides which rows are shown.
  final Future<HeldPlan?> Function() readPlan;

  /// How long the plan may take to read.
  final Duration planTimeout;

  final DateTime Function() _now;
  final AccountIdentityChanges _identityChanges;
  StreamSubscription<IncidentsState>? _incidentsSub;

  HeldSnapshot? _snapshot;

  /// Bumped by every drop. A read that started before one is thrown away.
  int _generation = 0;

  /// The snapshot, or null when none was taken or the server has answered.
  HeldSnapshot? get snapshot => _snapshot;

  void _drop() {
    _generation++;
    _snapshot = null;
  }

  /// Reads the archive of the account the phone is on, for the topics the
  /// phone kept. Needs the held topic list: with none, there is nothing to
  /// draw rows for. Never throws, and leaves no snapshot when anything about
  /// it is uncertain.
  Future<void> load() async {
    try {
      await _load();
    } on Object catch (error) {
      debugPrint('held_rows_read_failed error=${error.runtimeType}');
    }
  }

  /// [readPlan], as a future that may hold null whatever the caller built.
  Future<HeldPlan?> _plan() async => readPlan();

  Future<void> _load() async {
    final topicsState = _topics.state;
    if (!topicsState.isReady || !topicsState.isKept) return;
    if (_incidents.state.isReady) return;
    final started = _generation;
    final topics = topicsState.topics;

    final plan = await _plan().timeout(planTimeout, onTimeout: () => null);
    if (plan == null || started != _generation) return;

    final now = _now();
    final bound = HistoryWindow.lowerBound(
      hasLongHistory: plan.hasLongHistory,
      historyDays: plan.historyDays,
      now: now,
    );
    final results = await Future.wait([
      _archive.heldIncidents(limit: IncidentsCubit.listLimit),
      _archive.heldIncidentsBefore(bound),
      for (final topic in topics)
        _archive.heldMessages(topic.name, limit: IncidentsCubit.listLimit),
    ]);
    // The server answered, or the account changed, while the phone was read.
    if (started != _generation ||
        _incidents.state.isReady ||
        !_topics.state.isKept) {
      return;
    }

    final messages = <String, List<Message>>{};
    for (var i = 0; i < topics.length; i++) {
      messages[topics[i].name] = results[2 + i] as List<Message>;
    }
    for (final topic in topics) {
      // A glance a screen already noted is newer than the phone's copy.
      if (glances.of(topic.name, createdAt: topic.createdAt) != null) continue;
      glances.remember(
        topic.name,
        topicGlanceOf(topic, messages[topic.name]!, bound, now: now),
      );
    }
    _snapshot = HeldSnapshot(
      incidents: results[0] as List<Incident>,
      messages: messages,
      plan: plan,
      bound: bound,
      olderCount: results[1] as int,
    );
  }

  Future<void> dispose() async {
    _identityChanges.removeListener(_drop);
    await _incidentsSub?.cancel();
  }
}
