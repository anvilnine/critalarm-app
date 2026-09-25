import 'package:critalarm/features/reminders/domain/planned_record.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_copy.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_planner.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_settler.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:flutter/foundation.dart';

/// One plan pass, in this order:
///
/// 1. Reload preferences (native code writes the "Not now" flag to them in
///    the background), then settle every reminder whose fire time passed.
///    If that fails, stop: writing new records would drop unsettled ones.
/// 2. Read the inputs. If that fails, cancel only what the switches no
///    longer allow and leave the rest scheduled.
/// 3. Cancel the planned ids, pending or recorded, that are no longer
///    planned. Delivered reminders stay in the tray, and incidents and lab
///    fires are never touched.
/// 4. Schedule every planned reminder, even one `pending()` already lists:
///    a force-stop wipes Android's alarms but not the native store, and
///    scheduling the same id again is safe.
/// 5. Record what reached the scheduler so the next pass can settle it.
///
/// While `isPaused` answers true (onboarding or a "How to use the app" guide
/// is under way) the pass stops before step 1: nothing is settled, planned,
/// scheduled or cancelled. What was scheduled before stays as it was, and the
/// next pass after the pause plans as usual.
///
/// Any other failed step is logged and the rest of the pass goes on;
/// nothing is thrown to the caller. A run asked for while one is going runs
/// once more after it.
final class ReminderPlanPass implements ReminderPlanTrigger {
  ReminderPlanPass({
    required ReminderStore store,
    required ReminderScheduler scheduler,
    required ReminderSettler settler,
    required Future<ReminderInputs?> Function() readInputs,
    required ReminderCopy copy,
    Future<bool> Function()? isPaused,
    ReminderPlanner planner = const ReminderPlanner(),
    bool isWeb = kIsWeb,
    DateTime Function()? clock,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _store = store,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _scheduler = scheduler,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _settler = settler,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readInputs = readInputs,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _copy = copy,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isPaused = isPaused,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _planner = planner,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isWeb = isWeb,
       _clock = clock ?? DateTime.now;

  final ReminderStore _store;
  final ReminderScheduler _scheduler;
  final ReminderSettler _settler;
  final Future<ReminderInputs?> Function() _readInputs;
  final ReminderCopy _copy;

  /// `!SetupGate.isDone` in the app. Null in tests, and counts as running.
  final Future<bool> Function()? _isPaused;
  final ReminderPlanner _planner;
  final bool _isWeb;
  final DateTime Function() _clock;

  Future<void>? _running;
  bool _runAgain = false;

  @override
  Future<void> run() {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      return running;
    }
    final next = _loop();
    _running = next;
    return next;
  }

  Future<void> _loop() async {
    try {
      do {
        _runAgain = false;
        try {
          await _runOnce();
        } on Object catch (error) {
          _log('plan pass failed: ${error.runtimeType}');
        }
      } while (_runAgain);
    } finally {
      _running = null;
    }
  }

  Future<void> _runOnce() async {
    if (_isWeb) return;

    bool paused;
    try {
      paused = await (_isPaused?.call() ?? Future<bool>.value(false));
    } on Object catch (error) {
      _log('reading the pause failed: ${error.runtimeType}');
      paused = false;
    }
    if (paused) {
      _log('paused during onboarding or a guide');
      return;
    }

    try {
      await _store.reload();
      await _settler.settleAll(now: _clock());
    } on Object catch (error) {
      _log('settle failed: ${error.runtimeType}');
      return;
    }

    ReminderInputs? inputs;
    try {
      inputs = await _readInputs();
    } on Object catch (error) {
      _log('reading inputs failed: ${error.runtimeType}');
    }
    if (inputs == null) {
      await _cancelSwitchedOff();
      return;
    }
    final plan = _planner.plan(inputs);
    final planIds = {for (final candidate in plan) candidate.id};

    try {
      // pending() answers an empty list when the platform fails, so the
      // recorded ids are added too.
      final stale = {
        for (final id in await _plannedIds())
          if (!planIds.contains(id)) id,
      };
      if (stale.isNotEmpty) await _scheduler.cancel(stale.toList());
    } on Object catch (error) {
      _log('cancelling old reminders failed: ${error.runtimeType}');
    }

    final records = <PlannedRecord>[];
    for (final candidate in plan) {
      final record = await _schedule(candidate, inputs);
      if (record != null) records.add(record);
    }

    DateTime? fireAtOf(ReminderKind kind) {
      for (final record in records) {
        if (record.kind == kind) return record.fireAt;
      }
      return null;
    }

    await _store.writePlanned(records);
    await _store.writeReviewFireAt(fireAtOf(ReminderKind.reviewAsk));
    await _store.writeFeedbackFireAt(fireAtOf(ReminderKind.feedbackAsk));
  }

  /// Every planned id the platform holds or the last pass recorded.
  Future<Set<int>> _plannedIds() async {
    var pending = const <PendingReminder>[];
    try {
      pending = await _scheduler.pending();
    } on Object catch (error) {
      _log('reading pending reminders failed: ${error.runtimeType}');
    }
    return {
      for (final reminder in pending)
        if (ReminderIds.isPlanned(reminder.id)) reminder.id,
      for (final record in _store.readPlanned())
        if (ReminderIds.isPlanned(record.id)) record.id,
    };
  }

  /// Without inputs nothing new can be planned, but a switch the user
  /// turned off still has to win: cancel every planned id whose kind it
  /// no longer allows and forget those records.
  Future<void> _cancelSwitchedOff() async {
    final switches = _store.readSwitches();
    bool allowed(int id) {
      final kind = ReminderIds.kindOf(id);
      return kind == null || switches.allows(kind);
    }

    try {
      final off = [
        for (final id in await _plannedIds())
          if (!allowed(id)) id,
      ];
      if (off.isNotEmpty) await _scheduler.cancel(off);
      await _store.writePlanned([
        for (final record in _store.readPlanned())
          if (switches.allows(record.kind)) record,
      ]);
      if (!switches.allows(ReminderKind.reviewAsk)) {
        await _store.writeReviewFireAt(null);
      }
      if (!switches.allows(ReminderKind.feedbackAsk)) {
        await _store.writeFeedbackFireAt(null);
      }
    } on Object catch (error) {
      _log('cancelling switched off reminders failed: ${error.runtimeType}');
    }
  }

  /// Null when the scheduler refused it, so it is never settled as sent.
  Future<PlannedRecord?> _schedule(
    ReminderCandidate candidate,
    ReminderInputs inputs,
  ) async {
    try {
      await _scheduler.schedule(_copy.build(candidate));
    } on Object catch (error) {
      _log(
        'scheduling ${candidate.kind.wireName} failed: '
        '${error.runtimeType}',
      );
      return null;
    }
    return PlannedRecord(
      id: candidate.id,
      kind: candidate.kind,
      fireAt: inputs.timeZone.toInstant(candidate.fireAt),
      dedupeKey: candidate.dedupeKey,
      poolIndex: candidate.poolIndex,
    );
  }

  void _log(String message) => debugPrint('CritAlarmReminders: $message');
}
