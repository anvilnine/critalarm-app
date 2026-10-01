import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_switches.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings > Reminders: the two switches and whether the OS lets any of it
/// through. Turning a switch off cancels its reminders on the next plan
/// pass, which this starts right away.
class LocalReminderSettingsCubit extends Cubit<LocalReminderSettingsState> {
  LocalReminderSettingsCubit({
    required LocalReminderStore store,
    required LocalReminderScheduler scheduler,
    required Future<ServerMode?> Function() readServerMode,
    required LocalReminderPlanTrigger trigger,
    Future<bool> Function()? readIsPaid,
    LocalReminderAnalytics? analytics,
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
       _readServerMode = readServerMode,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _trigger = trigger,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readIsPaid = readIsPaid,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _analytics = analytics,
       super(const LocalReminderSettingsState());

  final LocalReminderStore _store;
  final LocalReminderScheduler _scheduler;
  final Future<ServerMode?> Function() _readServerMode;
  final LocalReminderPlanTrigger _trigger;

  /// Null in tests that do not care, and counts as free.
  final Future<bool> Function()? _readIsPaid;
  final LocalReminderAnalytics? _analytics;

  Future<void> load() async {
    final mode = await _readServerMode();
    final system = await _scheduler.systemState();
    final isPaid = await _safeIsPaid();
    if (isClosed) return;
    emit(
      state.copyWith(
        switches: _store.readSwitches(),
        notificationsAllowed: system.notificationsAllowed,
        isSelfHosted: mode == ServerMode.selfhosted,
        isPaid: isPaid,
        isLoaded: true,
      ),
    );
  }

  Future<void> setReminders({required bool isOn}) async {
    await _analytics?.switchChanged(name: 'reminders', isOn: isOn);
    await _save(state.switches.copyWith(reminders: isOn));
  }

  Future<void> setOffers({required bool isOn}) async {
    await _analytics?.switchChanged(name: 'offers', isOn: isOn);
    await _save(state.switches.copyWith(offers: isOn));
  }

  /// A failed read counts as paid, so the Offers switch stays hidden.
  Future<bool> _safeIsPaid() async {
    final read = _readIsPaid;
    if (read == null) return false;
    try {
      return await read();
    } on Object {
      return true;
    }
  }

  Future<void> _save(LocalReminderSwitches switches) async {
    await _store.writeSwitches(switches);
    if (!isClosed) emit(state.copyWith(switches: switches));
    await _trigger.run();
  }
}
