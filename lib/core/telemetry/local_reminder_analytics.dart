import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// Event names for reminders and the asks around them.
abstract final class LocalReminderEvents {
  static const tapped = 'reminder_tapped';
  static const switchChanged = 'reminder_switch_changed';
  static const sheetAnswered = 'reminder_sheet_answered';
  static const proAskAnswered = 'pro_prompt_answered';
  static const hostedAskShown = 'hosted_ask_shown';
  static const testRingSent = 'test_ring_sent';
  static const quickActionUsed = 'quick_action_used';
}

/// What put the Hosted ask on screen, for `hosted_ask_shown`.
enum HostedAskTrigger {
  /// The create-topic call was refused at the critical topic cap.
  capRefused('cap_refused'),

  /// A create left one critical topic on the free plan.
  lastCriticalUsed('last_critical_used'),

  /// After a real acknowledge.
  afterAck('after_ack'),

  /// Owed since a night acknowledge and shown on Home in the daytime.
  owedAfterNightAck('owed_after_night_ack');

  const HostedAskTrigger(this.wire);

  final String wire;
}

/// Thin wrapper so callers name an event instead of building a params map.
/// Nothing is sent unless the user turned analytics on in Settings.
final class LocalReminderAnalytics {
  const LocalReminderAnalytics(this._gate);

  final TelemetryGate _gate;

  /// `pro_prompt_answered` values. "Remind me later" is its own value so it
  /// is never counted as a "Not now".
  static const String seePlans = 'see_plans';
  static const String remindLater = 'remind_later';
  static const String notNow = 'not_now';

  Future<void> tapped({required String kind, required String action}) => _gate
      .logEvent(LocalReminderEvents.tapped, {'kind': kind, 'action': action});

  Future<void> switchChanged({required String name, required bool isOn}) =>
      _gate.logEvent(LocalReminderEvents.switchChanged, {
        'switch': name,
        'value': isOn ? 'on' : 'off',
      });

  Future<void> sheetAnswered({required String answer, required bool offers}) =>
      _gate.logEvent(LocalReminderEvents.sheetAnswered, {
        'answer': answer,
        'offers': offers ? 'on' : 'off',
      });

  Future<void> proAskAnswered({required String answer}) =>
      _gate.logEvent(LocalReminderEvents.proAskAnswered, {'answer': answer});

  Future<void> hostedAskShown({required HostedAskTrigger trigger}) => _gate
      .logEvent(LocalReminderEvents.hostedAskShown, {'trigger': trigger.wire});

  Future<void> testRingSent({required String result}) =>
      _gate.logEvent(LocalReminderEvents.testRingSent, {'result': result});

  Future<void> quickActionUsed({required String type}) =>
      _gate.logEvent(LocalReminderEvents.quickActionUsed, {'type': type});
}
