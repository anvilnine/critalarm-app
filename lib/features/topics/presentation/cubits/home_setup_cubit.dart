import 'dart:async';

import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/domain/setup_checklist_store.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The setup content at the top of Home's list sheet: the checklist, its
/// one celebration, and afterwards the widgets card, once.
///
/// It is Home content. It does not go through the notice slot, it is not an
/// ask, and it opens nothing on its own. It only reads: no path from here
/// changes a topic, so Critical delivery stays the user's own switch.
///
/// Home tells it two things. [homeChanged] hands over the list Home drew.
/// [screenChanged] says whether the user is looking at Home right now,
/// which decides three things:
///
/// - A row that turns true while Home is covered is held back until Home
///   is in front again, so its tick plays where it can be seen.
/// - The celebration plays only for a user who watched the last row turn.
///   A phone where all three are already true the first time Home looks
///   (a user who finished setup) retires the checklist without one.
/// - The first-message poll runs only while Home is in front and the
///   first-message row is still open.
class HomeSetupCubit extends Cubit<HomeSetupState> {
  HomeSetupCubit({
    required this._store,
    required this._firstMessage,
    required this._source,
    required this._newWatcher,
    required this._readIncidentIds,
    required this._readSetupIncidentIds,
    required this._isGuideOfferAnswered,
    required this._readWidgetsPlan,
    required this.platform,
    required bool isWeb,
    Stream<Object?>? widgetsPlanChanges,
    FirstMessageTimerFactory? timer,
    DateTime Function()? now,
    this.sweepEvery = const Duration(seconds: 30),
    this.tickHold = const Duration(milliseconds: 900),
    this.celebrationHold = const Duration(milliseconds: 3600),
  }) : _timer = timer ?? Timer.new,
       _now = now ?? DateTime.now,
       _widgetsExist = homeScreenWidgetsExist(
         platform: platform,
         isWeb: isWeb,
       ),
       super(const HomeSetupState()) {
    _planSub = widgetsPlanChanges?.listen(
      (_) => unawaited(_refreshWidgetsPlan()),
    );
  }

  final SetupChecklistStore _store;
  final FirstMessageStore _firstMessage;

  /// Reads a topic's messages for the one-time first look.
  final FirstMessageSource _source;

  /// A fresh watcher. One per watched topic, made only while one is needed.
  final FirstMessageWatcher Function() _newWatcher;

  /// The ids of every incident the phone knows of, for the first look.
  final Iterable<String> Function() _readIncidentIds;
  final Set<String> Function() _readSetupIncidentIds;

  /// True once the Feature Guides offer was taken or declined.
  final bool Function() _isGuideOfferAnswered;

  final Future<HomeWidgetsPlan> Function() _readWidgetsPlan;

  /// `FeatureAccess.changes` for the widgets in the app. The card keeps
  /// the plan it read when it appeared, so it reads again on this: a card
  /// that still said "locked" after the lock went would open nothing.
  StreamSubscription<Object?>? _planSub;

  Future<void> _refreshWidgetsPlan() async {
    if (isClosed || state.phase != HomeSetupPhase.widgetsCard) return;
    final HomeWidgetsPlan plan;
    try {
      plan = await _readWidgetsPlan();
    } on Exception {
      // Nobody knows right now. What is on screen stays.
      return;
    }
    if (isClosed || state.phase != HomeSetupPhase.widgetsCard) return;
    _show(HomeSetupState(phase: HomeSetupPhase.widgetsCard, widgetsPlan: plan));
  }

  /// The platform this build runs on, handed in as a value. The how-to
  /// sheet picks its iOS or Android steps from it.
  final TargetPlatform platform;
  final bool _widgetsExist;
  final FirstMessageTimerFactory _timer;
  final DateTime Function() _now;

  /// The shortest gap between two sweeps of the topics that are not being
  /// polled.
  final Duration sweepEvery;

  /// The first look failed this many times in a row, and may not be tried
  /// again before [_seedRetryAt].
  int _seedFailures = 0;
  DateTime? _seedRetryAt;
  Timer? _seedRetryTimer;

  DateTime? _lastSweep;
  int _sweepOffset = 0;

  /// How long the last tick is left on screen before the celebration
  /// replaces the rows: the tick first, then the celebration.
  final Duration tickHold;

  /// How long the finished line stays before it goes for good.
  final Duration celebrationHold;

  HomeState? _home;
  bool _isInFront = false;
  bool _isGuideActive = false;

  /// This run has drawn the checklist with a row still open, so finishing
  /// it is something the user watched happen.
  bool _hasShownOpen = false;

  /// The celebration played on this visit. The widgets card waits for the
  /// next one.
  bool _celebratedThisVisit = false;

  Timer? _momentTimer;
  bool _isInMoment = false;

  bool _isEvaluating = false;
  bool _isDirty = false;

  final Map<String, FirstMessageWatcher> _watchers = {};
  final List<StreamSubscription<bool>> _watcherSubs = [];
  bool _isWatchingPaused = false;

  /// The topics being polled for a first message right now.
  @visibleForTesting
  List<String> get watchedTopics => _watchers.keys.toList();

  /// Home drew [home]. Called on every change of Home's own state.
  Future<void> homeChanged(HomeState home) {
    _home = home;
    return _evaluate();
  }

  /// [isInFront]: Home is the screen the user sees, with the app open.
  /// [isGuideActive]: the Feature Guides offer or a guide is up.
  Future<void> screenChanged({
    required bool isInFront,
    required bool isGuideActive,
  }) {
    final isLooking = isInFront && !isGuideActive;
    _isGuideActive = isGuideActive;
    if (isLooking == _isInFront) return _evaluate();
    _isInFront = isLooking;
    if (!isLooking) {
      _pauseWatching();
      // Leaving ends the moment. It was marked done before it began, so it
      // does not come back.
      if (_isInMoment) _endMoment();
    }
    return _evaluate();
  }

  /// The user opened the how-to sheet from the widgets card.
  Future<void> widgetsHowToOpened() => _widgetsCardAnswered();

  /// The user closed the widgets card.
  Future<void> widgetsCardDismissed() => _widgetsCardAnswered();

  /// The user went to see the plans from the widgets card.
  Future<void> widgetsPlansOpened() => _widgetsCardAnswered();

  /// The user closed the checklist. It goes for good, like one that was
  /// finished, with no celebration. The widgets card waits for a later
  /// visit, so closing one thing does not open another.
  Future<void> checklistDismissed() async {
    if (state.phase != HomeSetupPhase.checklist || _isInMoment) return;
    await _store.markDone();
    _celebratedThisVisit = true;
    await _stopWatching();
    if (isClosed) return;
    _show(const HomeSetupState());
  }

  Future<void> _widgetsCardAnswered() async {
    await _store.markWidgetsCardSeen();
    if (isClosed) return;
    if (state.phase == HomeSetupPhase.widgetsCard) {
      emit(const HomeSetupState());
    }
  }

  @override
  Future<void> close() async {
    _momentTimer?.cancel();
    _seedRetryTimer?.cancel();
    await _planSub?.cancel();
    await _stopWatching();
    return super.close();
  }

  /// One evaluation at a time. A change that lands during one runs another
  /// straight after, so the last word always wins.
  Future<void> _evaluate() async {
    if (_isEvaluating) {
      _isDirty = true;
      return;
    }
    _isEvaluating = true;
    try {
      do {
        _isDirty = false;
        await _evaluateOnce();
      } while (_isDirty && !isClosed);
    } finally {
      _isEvaluating = false;
    }
  }

  Future<void> _evaluateOnce() async {
    if (isClosed || _isInMoment) return;
    final home = _home;
    final isLoaded =
        home != null && home.status == HomeStatus.success && !home.isStale;
    if (home == null || !isLoaded || !home.hasServer) {
      _pauseWatching();
      _show(const HomeSetupState());
      return;
    }

    if (!_store.isDone && !_store.isSeeded) {
      // Undecided draws nothing, and a look that failed is not repeated on
      // every change of Home: it waits its turn.
      final retryAt = _seedRetryAt;
      final mayLook = retryAt == null || !_now().isBefore(retryAt);
      final isSeeded = mayLook && await _takeFirstLook(home);
      if (isClosed) return;
      if (!isSeeded) {
        if (mayLook) _scheduleSeedRetry();
        _show(const HomeSetupState());
        return;
      }
      _seedFailures = 0;
      _seedRetryAt = null;
      _seedRetryTimer?.cancel();
    }

    final topics = [
      for (final topic in home.topicItems)
        (name: topic.name, isCritical: topic.ringsThroughSilent),
    ];
    final checklist = setupChecklistFor(
      isRetired: _store.isDone,
      hasServer: home.hasServer,
      isLoaded: isLoaded,
      topicCritical: [for (final topic in topics) topic.isCritical],
      isFirstMessageReceived: _firstMessage.isReceived,
    );

    if (checklist.isVisible && !checklist.isComplete) {
      final watched = checklist.hasFirstMessage
          ? const <String>[]
          : topicsToWatchForFirstMessage(topics);
      await _watch(watched);
      if (isClosed) return;
      if (!checklist.hasFirstMessage &&
          await _sweep([for (final topic in topics) topic.name], watched)) {
        // A topic outside the polled few holds the first message.
        _isDirty = true;
        return;
      }
      if (isClosed) return;
      final next = HomeSetupState(
        phase: HomeSetupPhase.checklist,
        checklist: checklist,
        firstTopic: topics.isEmpty ? null : topics.first.name,
        watchedTopic: watched.isEmpty ? null : watched.first,
      );
      // A row turned while Home is covered. Hold it, so the tick plays in
      // front of the user when they come back.
      final isHeld =
          state.phase == HomeSetupPhase.checklist &&
          !_isInFront &&
          state.checklist != checklist;
      if (isHeld) return;
      _hasShownOpen = true;
      _show(next);
      return;
    }

    if (checklist.isVisible && checklist.isComplete) {
      if (_hasShownOpen) {
        // The last row turns in front of the user or not at all.
        if (!_isInFront) return;
        await _stopWatching();
        // Marked done before anything is drawn, so a kill halfway through
        // cannot bring the celebration back.
        await _store.markDone();
        if (isClosed) return;
        _beginMoment(checklist);
        return;
      }
      // All three were true before the checklist was ever drawn here: a
      // user who finished setup. No checklist, no celebration.
      await _store.markDone();
      if (isClosed) return;
    }

    await _stopWatching();
    if (isClosed) return;
    final showsCard = showsHomeWidgetsCard(
      isChecklistRetired: _store.isDone,
      isSeen: _store.isWidgetsCardSeen,
      widgetsExist: _widgetsExist,
      isGuideOfferAnswered: _isGuideOfferAnswered(),
      isGuideActive: _isGuideActive,
      celebratedThisVisit: _celebratedThisVisit,
    );
    if (!showsCard) {
      _show(const HomeSetupState());
      return;
    }
    if (state.phase == HomeSetupPhase.widgetsCard) return;
    final HomeWidgetsPlan plan;
    try {
      plan = await _readWidgetsPlan();
    } on Exception {
      // Without the plan the card could say the wrong thing about what the
      // user pays for. It waits for a later look.
      _show(const HomeSetupState());
      return;
    }
    if (isClosed) return;
    _show(HomeSetupState(phase: HomeSetupPhase.widgetsCard, widgetsPlan: plan));
  }

  void _show(HomeSetupState next) {
    if (isClosed || next == state) return;
    emit(next);
  }

  /// The tick, then the celebration, then nothing.
  void _beginMoment(SetupChecklist complete) {
    _isInMoment = true;
    _celebratedThisVisit = true;
    _show(
      HomeSetupState(
        phase: HomeSetupPhase.checklist,
        checklist: complete,
        firstTopic: state.firstTopic,
        watchedTopic: state.watchedTopic,
      ),
    );
    _momentTimer = _timer(tickHold, () {
      if (isClosed || !_isInMoment) return;
      _show(const HomeSetupState(phase: HomeSetupPhase.celebration));
      _momentTimer = _timer(celebrationHold, () {
        if (isClosed || !_isInMoment) return;
        _endMoment();
      });
    });
  }

  void _endMoment() {
    _momentTimer?.cancel();
    _momentTimer = null;
    _isInMoment = false;
    _show(const HomeSetupState());
  }

  /// The one-time look at what this phone already holds. Answers false
  /// when a topic could not be read, in which case nothing is saved and
  /// the next load looks again. Until it has looked, nothing is drawn, so
  /// a long-time user never sees a checklist flash past.
  Future<bool> _takeFirstLook(HomeState home) async {
    var hasOwnMessage = false;
    final baselines = <String, String>{};
    if (!_firstMessage.isReceived) {
      try {
        for (final topic in home.topicItems) {
          final page = await _source.read(
            topic.name,
            FirstMessageSource.everything,
          );
          if (page.candidates.isNotEmpty) {
            hasOwnMessage = true;
            break;
          }
          baselines[topic.name] =
              page.newestId ?? FirstMessageSource.everything;
        }
      } on Exception {
        return false;
      }
    }
    final seed = seedSetupChecklist(
      isFirstMessageReceived: _firstMessage.isReceived,
      hasOwnMessage: hasOwnMessage,
      incidentIds: _readIncidentIds(),
      setupIncidentIds: _readSetupIncidentIds(),
      hasTopics: home.topicItems.isNotEmpty,
      wasSetUpHere: _store.wasSetUpHere,
    );
    // Every topic that exists now starts its watch from what it held at
    // this look. A topic with no baseline is therefore one made later,
    // and everything it holds counts.
    if (!seed.retiresChecklist) {
      for (final MapEntry(key: topic, value: cursor) in baselines.entries) {
        if (_firstMessage.cursorFor(topic) == null) {
          await _firstMessage.saveCursor(topic, cursor);
        }
      }
    }
    if (seed.marksFirstMessage) await _firstMessage.markReceived();
    if (seed.retiresChecklist) await _store.markDone();
    await _store.markSeeded();
    return true;
  }

  /// Polls [topics] for a first message while Home is in front. An empty
  /// list stops every poll.
  Future<void> _watch(List<String> topics) async {
    if (!listEquals(topics, _watchers.keys.toList())) await _stopWatching();
    if (!_isInFront) {
      _pauseWatching();
      return;
    }
    if (_isWatchingPaused) {
      _isWatchingPaused = false;
      for (final watcher in _watchers.values) {
        watcher.resume();
      }
    }
    for (final topic in topics) {
      if (_watchers.containsKey(topic)) continue;
      final watcher = _newWatcher();
      _watchers[topic] = watcher;
      _watcherSubs.add(
        watcher.changes.listen((_) => unawaited(_evaluate())),
      );
      // The first look gave every topic of that time a baseline. One
      // without is new since, so a message sent before this poll counts.
      unawaited(watcher.start(topic, countsFromStart: true));
    }
  }

  /// Tries the first look again after a wait that grows with each failure.
  void _scheduleSeedRetry() {
    _seedFailures++;
    final delay = setupSeedRetryDelay(_seedFailures);
    _seedRetryAt = _now().add(delay);
    _seedRetryTimer?.cancel();
    _seedRetryTimer = _timer(delay, () {
      if (!isClosed) unawaited(_evaluate());
    });
  }

  /// One read each of a few topics Home is not polling, so a first message
  /// on any topic ticks the row. At most once per [sweepEvery], and only
  /// while Home is in front. True when it found the first message.
  Future<bool> _sweep(List<String> all, List<String> watched) async {
    if (!_isInFront) return false;
    final last = _lastSweep;
    final now = _now();
    if (last != null && now.difference(last) < sweepEvery) return false;
    final turn = topicsToSweepForFirstMessage(
      all: all,
      watched: watched,
      offset: _sweepOffset,
    );
    if (turn.topics.isEmpty) return false;
    _lastSweep = now;
    _sweepOffset = turn.nextOffset;
    for (final topic in turn.topics) {
      try {
        final since =
            _firstMessage.cursorFor(topic) ?? FirstMessageSource.everything;
        final page = await _source.read(topic, since);
        if (isClosed || _firstMessage.isReceived) {
          return _firstMessage.isReceived;
        }
        if (page.candidates.isNotEmpty) {
          await _firstMessage.markReceived();
          return true;
        }
        final newest = page.newestId;
        if (newest != null && newest != since) {
          await _firstMessage.saveCursor(topic, newest);
        } else if (_firstMessage.cursorFor(topic) == null) {
          await _firstMessage.saveCursor(topic, since);
        }
      } on Exception {
        // This topic gets its turn again on a later sweep.
      }
    }
    return false;
  }

  void _pauseWatching() {
    if (_isWatchingPaused) return;
    _isWatchingPaused = true;
    for (final watcher in _watchers.values) {
      watcher.pause();
    }
  }

  Future<void> _stopWatching() async {
    final watchers = _watchers.values.toList();
    final subs = _watcherSubs.toList();
    _watchers.clear();
    _watcherSubs.clear();
    _isWatchingPaused = false;
    for (final sub in subs) {
      await sub.cancel();
    }
    for (final watcher in watchers) {
      await watcher.dispose();
    }
  }
}
