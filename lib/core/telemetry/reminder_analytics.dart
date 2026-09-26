import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// Event names for reminders and the asks around them.
abstract final class ReminderEvents {
  static const tapped = 'reminder_tapped';
  static const switchChanged = 'reminder_switch_changed';
  static const sheetAnswered = 'reminder_sheet_answered';
  static const proAskAnswered = 'pro_prompt_answered';
  static const testRingSent = 'test_ring_sent';
  static const quickActionUsed = 'quick_action_used';
}

/// Thin wrapper so callers name an event instead of building a params map.
/// Nothing is sent unless the user turned analytics on in Settings.
final class ReminderAnalytics {
  const ReminderAnalytics(this._gate);

  final TelemetryGate _gate;

  /// `pro_prompt_answered` values. "Remind me later" is its own value so it
  /// is never counted as a "Not now".
  static const String seePlans = 'see_plans';
  static const String remindLater = 'remind_later';
  static const String notNow = 'not_now';

  Future<void> tapped({required String kind, required String action}) =>
      _gate.logEvent(ReminderEvents.tapped, {'kind': kind, 'action': action});

  Future<void> switchChanged({required String name, required bool isOn}) =>
      _gate.logEvent(ReminderEvents.switchChanged, {
        'switch': name,
        'value': isOn ? 'on' : 'off',
      });

  Future<void> sheetAnswered({required String answer, required bool offers}) =>
      _gate.logEvent(ReminderEvents.sheetAnswered, {
        'answer': answer,
        'offers': offers ? 'on' : 'off',
      });

  Future<void> proAskAnswered({required String answer}) =>
      _gate.logEvent(ReminderEvents.proAskAnswered, {'answer': answer});

  Future<void> testRingSent({required String result}) =>
      _gate.logEvent(ReminderEvents.testRingSent, {'result': result});

  Future<void> quickActionUsed({required String type}) =>
      _gate.logEvent(ReminderEvents.quickActionUsed, {'type': type});
}
