import 'dart:async';

import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/domain/setup_checklist_store.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter/foundation.dart';

/// A timer the test fires by hand.
class FakeTimer implements Timer {
  FakeTimer(this.duration, this.onFire);

  final Duration duration;
  final void Function() onFire;
  bool isCancelled = false;

  @override
  void cancel() => isCancelled = true;

  @override
  bool get isActive => !isCancelled;

  @override
  int get tick => 0;
}

/// The checklist flags in memory. [log] is shared with the cubit's states,
/// so a test can read the order things happened in.
class FakeChecklistStore implements SetupChecklistStore {
  FakeChecklistStore(this.log);

  final List<String> log;

  @override
  bool isSeeded = false;

  @override
  bool isDone = false;

  @override
  bool isWidgetsCardSeen = false;

  @override
  bool wasSetUpHere = true;

  @override
  Future<void> markSetUpHere() async => wasSetUpHere = true;

  @override
  Future<void> markSeeded() async {
    isSeeded = true;
    log.add('seeded');
  }

  @override
  Future<void> markDone() async {
    isDone = true;
    log.add('done');
  }

  @override
  Future<void> markWidgetsCardSeen() async {
    isWidgetsCardSeen = true;
    log.add('widgets_seen');
  }
}

class FakeFirstMessageStore implements FirstMessageStore {
  @override
  bool isReceived = false;

  final Map<String, String> cursors = {};

  @override
  Future<void> markReceived() async => isReceived = true;

  @override
  String? cursorFor(String topic) => cursors[topic];

  @override
  Future<void> saveCursor(String topic, String cursor) async =>
      cursors[topic] = cursor;

  @override
  Future<void> forgetTopic(String topic) async => cursors.remove(topic);
}

/// Answers per topic. A topic with nothing set answers an empty read.
class FakeFirstMessageSource implements FirstMessageSource {
  /// What a read of everything returns, per topic.
  final Map<String, FirstMessagePage> everything = {};

  /// What a read after a cursor returns, per topic.
  final Map<String, FirstMessagePage> later = {};

  /// Every read, as `topic@since`.
  final List<String> reads = [];

  Exception? failure;

  @override
  Future<FirstMessagePage> read(String topic, String since) async {
    reads.add('$topic@$since');
    final failure = this.failure;
    if (failure != null) throw failure;
    final pages = since == FirstMessageSource.everything ? everything : later;
    return pages[topic] ?? const FirstMessagePage.empty();
  }
}

HomeTopicItem topicItem(String name, {bool isCritical = false}) =>
    HomeTopicItem(
      name: name,
      ringsThroughSilent: isCritical,
    );

/// Home with a server and a list that loaded.
HomeState loadedHome([List<HomeTopicItem> topics = const []]) =>
    HomeState(status: HomeStatus.success, topicItems: topics);

/// Everything a `HomeSetupCubit` test needs, with every outside thing
/// faked.
class HomeSetupHarness {
  HomeSetupHarness({
    TargetPlatform platform = TargetPlatform.android,
    bool isWeb = false,
  }) {
    store = FakeChecklistStore(log);
    cubit = HomeSetupCubit(
      store: store,
      firstMessage: firstMessage,
      source: source,
      newWatcher: () => FirstMessageWatcher(
        store: firstMessage,
        source: source,
        timer: _newTimer,
        backsOffWhenQuiet: true,
      ),
      readIncidentIds: () => incidentIds,
      readSetupIncidentIds: () => setupIncidentIds,
      isGuideOfferAnswered: () => isGuideOfferAnswered,
      widgetsPlanChanges: planChanges.stream,
      readWidgetsPlan: () async {
        final failure = planFailure;
        if (failure != null) throw failure;
        return plan;
      },
      platform: platform,
      isWeb: isWeb,
      timer: _newTimer,
      now: () => now,
    );
    _sub = cubit.stream.listen((state) {
      states.add(state);
      log.add('state:${state.phase.name}');
    });
  }

  final List<String> log = [];
  final List<HomeSetupState> states = [];
  final List<FakeTimer> timers = [];
  final firstMessage = FakeFirstMessageStore();
  final source = FakeFirstMessageSource();
  late final FakeChecklistStore store;
  late final HomeSetupCubit cubit;
  late final StreamSubscription<HomeSetupState> _sub;

  /// The clock the cubit reads. A test moves it by hand.
  DateTime now = DateTime.utc(2026, 10, 5, 12);

  List<String> incidentIds = [];
  Set<String> setupIncidentIds = {};
  bool isGuideOfferAnswered = true;
  HomeWidgetsPlan plan = HomeWidgetsPlan.pro;
  Exception? planFailure;

  /// Stands in for `FeatureAccess.changes` for the widgets.
  final planChanges = StreamController<void>.broadcast();

  Timer _newTimer(Duration duration, void Function() onFire) {
    final timer = FakeTimer(duration, onFire);
    timers.add(timer);
    return timer;
  }

  /// Lets every pending microtask and stream event run.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Home is in front with [home] on it.
  Future<void> open(HomeState home, {bool isGuideActive = false}) async {
    await cubit.screenChanged(isInFront: true, isGuideActive: isGuideActive);
    await cubit.homeChanged(home);
    await settle();
  }

  /// Fires the newest timer that is still running and has [duration].
  Future<void> fire(Duration duration) async {
    timers.lastWhere((t) => t.isActive && t.duration == duration)
      ..isCancelled = true
      ..onFire();
    await settle();
  }

  Future<void> dispose() async {
    await cubit.close();
    await _sub.cancel();
  }
}
