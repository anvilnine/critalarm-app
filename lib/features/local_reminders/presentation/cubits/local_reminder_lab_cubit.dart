import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_lab_samples.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_lab_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Developer options > Reminder lab: what is planned, why, and a way to
/// fire any reminder by hand to see the real lock screen.
class LocalReminderLabCubit extends Cubit<LocalReminderLabState> {
  LocalReminderLabCubit({
    required LocalReminderStore store,
    required InAppNoticeRepository notices,
    required LocalReminderScheduler scheduler,
    required LocalReminderCopy copy,
    required LocalReminderPlanTrigger trigger,
    required Future<ServerMode?> Function() readServerMode,
    DateTime Function()? clock,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _store = store,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _notices = notices,
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
       super(const LocalReminderLabState());

  final LocalReminderStore _store;
  final InAppNoticeRepository _notices;
  final LocalReminderScheduler _scheduler;
  final LocalReminderCopy _copy;
  final LocalReminderPlanTrigger _trigger;
  final Future<ServerMode?> Function() _readServerMode;
  final DateTime Function() _clock;

  Future<void> load() async {
    final system = await _scheduler.systemState();
    final zone = await _scheduler.deviceTimeZone();
    final pending = await _scheduler.pending();
    final mode = await _readServerMode();
    if (isClosed) return;
    emit(
      LocalReminderLabState(
        switches: _store.readSwitches(),
        notificationsAllowed: system.notificationsAllowed,
        isSelfHosted: mode == ServerMode.selfhosted,
        timeZone: zone.name,
        budgetSpentAt: _store.readBudgetSpentAt(),
        proAskedAt: _notices.getProAskedAt(),
        proDismissCount: _notices.getProAskDismissCount(),
        reviewAskedAt: _notices.getReviewAskedAt(),
        reviewAskCount: _notices.getReviewAskCount(),
        feedbackAskedAt: _notices.getFeedbackAskedAt(),
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
  Future<void> fire(LocalReminderKind kind, {required Duration delay}) async {
    const floor = Duration(seconds: 1);
    final zone = await _scheduler.deviceTimeZone();
    final fireAt = zone.toWall(_clock().add(delay < floor ? floor : delay));
    try {
      await _scheduler.schedule(
        _copy.build(LocalReminderLabSamples.candidate(kind, fireAt)),
      );
    } on LocalReminderScheduleRefused {
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

  List<LocalReminderRequest> poolPreview() => [
    for (final candidate in LocalReminderLabSamples.drillPool(_clock()))
      _copy.build(candidate),
  ];
}
