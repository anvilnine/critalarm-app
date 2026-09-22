import 'package:critalarm/app/reminder_bindings.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/reminders/fake_reminder_scheduler.dart';
import '../../helpers/fake_home_prompt_repository.dart';

class _RecordingGate extends NoopTelemetryGate {
  final events = <(String, Map<String, Object?>?)>[];

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async => events.add((name, parameters));
}

void main() {
  late _RecordingGate gate;
  late ReminderAnalytics analytics;

  setUp(() {
    gate = _RecordingGate();
    analytics = ReminderAnalytics(gate);
  });

  test('"Remind me later" has its own answer value', () async {
    await analytics.proPromptAnswered(answer: ReminderAnalytics.remindLater);
    expect(gate.events.single.$1, 'pro_prompt_answered');
    expect(gate.events.single.$2, {'answer': 'remind_later'});
  });

  test('switches, sheet answers, test rings and quick actions', () async {
    await analytics.switchChanged(name: 'offers', isOn: true);
    await analytics.sheetAnswered(answer: 'on', offers: false);
    await analytics.testRingSent(result: 'not_critical');
    await analytics.quickActionUsed(type: 'ring_me_now');
    expect(gate.events.map((e) => e.$1), [
      'reminder_switch_changed',
      'reminder_sheet_answered',
      'test_ring_sent',
      'quick_action_used',
    ]);
    expect(gate.events.first.$2, {'switch': 'offers', 'value': 'on'});
  });

  test('a reminder tap is logged with its kind and action', () async {
    final bindings = ReminderBindings(
      scheduler: FakeReminderScheduler(),
      prompts: FakeHomePromptRepository(),
      focus: AlarmFocus(),
      navigate: (_) {},
      openUrl: (_) async {},
      openStoreReview: () async {},
      openFeedbackForm: (_) async {},
      analytics: analytics,
    );
    await bindings.handle(
      const ReminderTap(kind: ReminderKind.fireDrill, actionId: 'ring'),
    );
    expect(gate.events.single.$1, 'reminder_tapped');
    expect(gate.events.single.$2, {'kind': 'fire_drill', 'action': 'ring'});
  });
}
