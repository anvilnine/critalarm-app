import 'dart:async';

import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/topics/domain/home_card/handled_window.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_rule.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_effect.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Starts a timer that runs [run] after [after]. A test hands in its own to
/// fire it by hand.
typedef HomeCardTimerFactory =
    Timer Function(Duration after, void Function() run);

/// Turns what Home knows into the one thing its dark card shows.
///
/// It listens to Home's lists and facts, the reliability checks, the setup
/// checklist and the missed alarm feed, builds a [HomeCardInput] and calls
/// `resolveHomeCard`. It emits only when the card changes.
///
/// It reads the shared cubits and the phone's own stores. It never calls the
/// server, never navigates and never touches a topic, so Critical delivery
/// stays the user's own switch. [actionFor] says what the screen should do for
/// the card's button and the screen does it.
///
/// Readiness is read again on open, and the screen asks for it again on app
/// resume, on pull to refresh and when a route that covered Home returns
/// ([refreshReadiness]). A message newer than the last one held also asks,
/// because a push changes the last push check. There is no timer for it.
///
/// The only timer is a one-shot for the moment a card kind ends by itself:
/// the short "answered in" window and a desk timer running out.
class HomeCardCubit extends Cubit<HomeCardState> {
  HomeCardCubit({
    required this._home,
    required this._reliability,
    required this._setup,
    required this._missed,
    required this._testRouteName,
    required this._askPermissionsRouteName,
    DateTime Function()? clock,
    HomeCardTimerFactory? timer,
  }) : _now = clock ?? DateTime.now,
       _newTimer = timer ?? Timer.new,
       super(
         HomeCardState(
           model: resolveHomeCard(
             HomeCardInput(now: (clock ?? DateTime.now)(), isLoading: true),
           ),
         ),
       ) {
    _subs = [
      _home.stream.listen(_onHome),
      _reliability.stream.listen((_) => _recompute()),
      _setup.stream.listen((_) => _recompute()),
      _missed.changes.listen((_) => unawaited(_readMissed())),
    ];
    _onHome(_home.state);
    unawaited(refreshReadiness());
  }

  final StateStreamable<HomeState> _home;
  final ReliabilityCubit _reliability;
  final StateStreamable<HomeSetupState> _setup;
  final MissedAlarmFeed _missed;
  final String _testRouteName;
  final String _askPermissionsRouteName;
  final DateTime Function() _now;
  final HomeCardTimerFactory _newTimer;

  late final List<StreamSubscription<Object?>> _subs;
  Timer? _boundary;

  /// The missed alarm entry the card may show, or null.
  MissedFact? _missedFact;

  /// Only the newest missed alarm read may land. An earlier one that finishes
  /// late would put an old entry back.
  int _missedRead = 0;

  /// The newest message time Home has held, and whether Home has built a
  /// list yet. A time later than the held one is a message that just came in.
  DateTime? _heldNewest;
  bool _hasHeldBuild = false;

  /// Reads the phone's checks and the missed alarm entry again.
  ///
  /// The screen calls it on app resume, on pull to refresh and when a route
  /// that covered Home returns. The cubit calls it once when it opens.
  Future<void> refreshReadiness() async {
    await Future.wait([_reliability.refresh(), _readMissed()]);
  }

  /// What the screen should do for the card's button.
  HomeCardEffect actionFor(HomeCardAction action) => homeCardEffectFor(
    action,
    missed: _missedFact,
    testRouteName: _testRouteName,
    askPermissionsRouteName: _askPermissionsRouteName,
  );

  void _onHome(HomeState home) {
    if (home.status == HomeStatus.success) {
      final newest = home.facts.newestMessageAt;
      final isNewer =
          newest != null &&
          (_heldNewest == null || newest.isAfter(_heldNewest!));
      if (isNewer) _heldNewest = newest;
      // Never on the first list: opening already asks.
      if (isNewer && _hasHeldBuild) unawaited(refreshReadiness());
      _hasHeldBuild = true;
    }
    _recompute();
  }

  Future<void> _readMissed() async {
    final read = ++_missedRead;
    MissedFact? fact;
    try {
      fact = await _missed.read();
    } on Object {
      // A failed read is "nothing to say", never an error on Home.
      fact = null;
    }
    if (isClosed || read != _missedRead || fact == _missedFact) return;
    _missedFact = fact;
    _recompute();
  }

  HomeCardInput _input(DateTime now) {
    final home = _home.state;
    final facts = home.facts;
    final setup = _setup.state;
    final snapshot = _reliability.state;
    return HomeCardInput(
      now: now,
      isLoading:
          home.status == HomeStatus.initial ||
          home.status == HomeStatus.loading,
      hasServer: home.hasServer,
      isStale: home.isStale,
      // A server is saved, the list failed and there is no old copy.
      loadFailed:
          home.status == HomeStatus.failure && home.hasServer && !home.isStale,
      lastKnownGoodAt: home.lastKnownGoodAt,
      topicCount: home.topicItems.length,
      ringing: facts.ringing,
      acknowledged: facts.acknowledged,
      handled: facts.handled,
      missed: _missedFact,
      warningCount: facts.warningCount,
      readiness: ReadinessInput(
        loaded: snapshot.loaded,
        incomplete: snapshot.incomplete,
        checks: snapshot.checks,
      ),
      setup: setup.checklist,
      firstTopic: setup.firstTopic,
      watchedTopic: setup.watchedTopic,
      newestMessageAt: facts.newestMessageAt,
      lastAlarmAt: facts.lastAlarmAt,
      hasCriticalTopic: home.topicItems.any((t) => t.ringsThroughSilent),
    );
  }

  void _recompute() {
    if (isClosed) return;
    final now = _now();
    final input = _input(now);
    final next = HomeCardState(
      model: resolveHomeCard(input),
      readinessLoaded: input.readiness.loaded,
    );
    if (next != state) emit(next);
    _scheduleBoundary(input, now);
  }

  /// Wakes the cubit when a kind ends on its own: the "answered in" window
  /// closes, or a desk timer reaches its deadline.
  void _scheduleBoundary(HomeCardInput input, DateTime now) {
    _boundary?.cancel();
    _boundary = null;
    DateTime? next;
    void consider(DateTime? at) {
      if (at != null &&
          at.isAfter(now) &&
          (next == null || at.isBefore(next!))) {
        next = at;
      }
    }

    consider(input.handled?.closedAt.add(handledCardWindow));
    consider(input.acknowledged?.deadline);
    final at = next;
    if (at == null) return;
    final wait = at.difference(now);
    _boundary = _newTimer(
      wait < const Duration(milliseconds: 1)
          ? const Duration(milliseconds: 1)
          : wait,
      _recompute,
    );
  }

  @override
  Future<void> close() async {
    _boundary?.cancel();
    _boundary = null;
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
