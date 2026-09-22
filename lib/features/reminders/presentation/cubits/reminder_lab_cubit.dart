import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/reminders/domain/reminder_copy.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_lab_samples.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/presentation/cubits/reminder_lab_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Developer options > Reminder lab: what is planned, why, and a way to
/// fire any reminder by hand to see the real lock screen.
class ReminderLabCubit extends Cubit<ReminderLabState> {
  ReminderLabCubit({
    required ReminderStore store,
    required HomePromptRepository prompts,
    required ReminderScheduler scheduler,
    required ReminderCopy copy,
    required ReminderPlanTrigger trigger,
    required Future<ServerMode?> Function() readServerMode,
    DateTime Function()? clock,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _store = store,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _prompts = prompts,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _scheduler = scheduler,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _copy = copy,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _trigger = trigger,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readServerMode = readServerMode,
       _clock = clock ?? DateTime.now,
       super(const ReminderLabState());

  final ReminderStore _store;
  final HomePromptRepository _prompts;
  final ReminderScheduler _scheduler;
  final ReminderCopy _copy;
  final ReminderPlanTrigger _trigger;
  final Future<ServerMode?> Function() _readServerMode;
  final DateTime Function() _clock;

  Future<void> load() async {
    final system = await _scheduler.systemState();
    final zone = await _scheduler.deviceTimeZone();
    final pending = await _scheduler.pending();
    final mode = await _readServerMode();
    if (isClosed) return;
    emit(
      ReminderLabState(
        switches: _store.readSwitches(),
        notificationsAllowed: system.notificationsAllowed,
        isSelfHosted: mode == ServerMode.selfhosted,
        timeZone: zone.name,
        budgetSpentAt: _store.readBudgetSpentAt(),
        proAskedAt: _prompts.getProPromptAskedAt(),
        proDismissCount: _prompts.getProPromptDismissCount(),
        reviewAskedAt: _prompts.getReviewAskedAt(),
        reviewAskCount: _prompts.getReviewAskCount(),
        feedbackAskedAt: _prompts.getFeedbackAskedAt(),
        pending: pending,
        skipRules: _store.readSkipRules(),
      ),
    );
  }

  Future<void> cancel(int id) async {
    await _scheduler.cancel([id]);
    await load();
  }

  /// "Now" is one second out: the platform needs a future time.
  Future<void> fire(ReminderKind kind, {required Duration delay}) async {
    const floor = Duration(seconds: 1);
    final zone = await _scheduler.deviceTimeZone();
    final fireAt = zone.toWall(_clock().add(delay < floor ? floor : delay));
    try {
      await _scheduler.schedule(
        _copy.build(ReminderLabSamples.candidate(kind, fireAt)),
      );
    } on ReminderScheduleRefused {
      // The pending list below shows it did not arm.
    }
    await load();
  }

  Future<void> setSkipRules({required bool skip}) async {
    await _store.writeSkipRules(skip: skip);
    await _trigger.run();
    await load();
  }

  Future<void> resetAll() async {
    await _store.resetAll();
    await _trigger.run();
    await load();
  }

  List<ReminderRequest> poolPreview() => [
    for (final candidate in ReminderLabSamples.drillPool(_clock()))
      _copy.build(candidate),
  ];
}
