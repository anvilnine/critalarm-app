import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:critalarm/features/reminders/presentation/cubits/reminder_settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings > Reminders: the two switches and whether the OS lets any of it
/// through. Turning a switch off cancels its reminders on the next plan
/// pass, which this starts right away.
class ReminderSettingsCubit extends Cubit<ReminderSettingsState> {
  ReminderSettingsCubit({
    required ReminderStore store,
    required ReminderScheduler scheduler,
    required Future<ServerMode?> Function() readServerMode,
    required ReminderPlanTrigger trigger,
    ReminderAnalytics? analytics,
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
       _analytics = analytics,
       super(const ReminderSettingsState());

  final ReminderStore _store;
  final ReminderScheduler _scheduler;
  final Future<ServerMode?> Function() _readServerMode;
  final ReminderPlanTrigger _trigger;
  final ReminderAnalytics? _analytics;

  Future<void> load() async {
    final mode = await _readServerMode();
    final system = await _scheduler.systemState();
    if (isClosed) return;
    emit(
      state.copyWith(
        switches: _store.readSwitches(),
        notificationsAllowed: system.notificationsAllowed,
        isSelfHosted: mode == ServerMode.selfhosted,
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

  Future<void> _save(ReminderSwitches switches) async {
    await _store.writeSwitches(switches);
    if (!isClosed) emit(state.copyWith(switches: switches));
    await _trigger.run();
  }
}
