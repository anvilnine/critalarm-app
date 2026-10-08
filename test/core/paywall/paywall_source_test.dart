import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingGate extends NoopTelemetryGate {
  final events = <(String, Map<String, Object?>?)>[];

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async => events.add((name, parameters));
}

void main() {
  group('PaywallSource wire names', () {
    test('every value has its own wire name', () {
      const expected = <PaywallSource, String>{
        PaywallSource.settingsPlan: 'settings_plan',
        PaywallSource.createTopicCard: 'create_topic_card',
        PaywallSource.askSheet: 'ask_sheet',
        PaywallSource.planSheetEnding: 'plan_sheet_ending',
        PaywallSource.planSheetEnded: 'plan_sheet_ended',
        PaywallSource.settingsSearch: 'settings_search',
        PaywallSource.widgetLocked: 'widget_locked',
        PaywallSource.homeWidgets: 'home_widgets',
        PaywallSource.appIcon: 'app_icon',
        PaywallSource.historyOlder: 'history_older',
        PaywallSource.history: 'history',
        PaywallSource.reminderMorningAfter: 'reminder_morning_after',
        PaywallSource.reminderProLater: 'reminder_pro_later',
        PaywallSource.homeDay0Card: 'home_day0_card',
        PaywallSource.onboardingOffer: 'onboarding_offer',
        PaywallSource.direct: 'direct',
      };
      for (final source in PaywallSource.values) {
        expect(expected[source], isNotNull, reason: '$source has no entry');
        expect(source.wire, expected[source]);
      }
      expect(expected.length, PaywallSource.values.length);
      expect(
        PaywallSource.values.map((s) => s.wire).toSet().length,
        PaywallSource.values.length,
      );
    });

    test('the shipped wire names are fixed', () {
      expect(PaywallSource.homeWidgets.wire, 'home_widgets');
      expect(PaywallSource.appIcon.wire, 'app_icon');
      expect(PaywallSource.historyOlder.wire, 'history_older');
      expect(PaywallSource.history.wire, 'history');
      expect(PaywallSource.reminderMorningAfter.wire, 'reminder_morning_after');
      expect(PaywallSource.reminderProLater.wire, 'reminder_pro_later');
    });

    test('the location carries the wire name', () {
      for (final source in PaywallSource.values) {
        expect(paywallLocation(source), '/paywall?source=${source.wire}');
      }
    });
  });

  group('the router reads the source', () {
    test('a known source parses to itself', () {
      for (final source in PaywallSource.values) {
        expect(PaywallSource.parse(source.wire), source);
      }
    });

    test('a missing source is direct', () {
      expect(PaywallSource.parse(null), PaywallSource.direct);
      expect(PaywallSource.parse(''), PaywallSource.direct);
    });

    test('an unknown source is direct', () {
      expect(PaywallSource.parse('nonsense'), PaywallSource.direct);
      expect(PaywallSource.parse('HOME_WIDGETS'), PaywallSource.direct);
    });

    test('a location with no source query reads as direct', () {
      final uri = Uri.parse('/paywall');
      expect(
        PaywallSource.parse(uri.queryParameters['source']).wire,
        'direct',
      );
    });
  });

  group('a locked widget tap', () {
    test('opens the paywall tagged widget_locked', () {
      expect(
        PushDeepLink.fromNotificationData({'open': 'paywall'}),
        '/paywall?source=widget_locked',
      );
    });

    test('a bare /paywall from the platform is tagged, nothing else is', () {
      expect(PushDeepLink.tagged('/paywall'), '/paywall?source=widget_locked');
      expect(PushDeepLink.tagged('/'), '/');
      expect(PushDeepLink.tagged('/paywall?source=x'), '/paywall?source=x');
    });
  });

  group('hosted_ask_shown', () {
    test('the four triggers have fixed wire names', () {
      expect(HostedAskTrigger.capRefused.wire, 'cap_refused');
      expect(HostedAskTrigger.lastCriticalUsed.wire, 'last_critical_used');
      expect(HostedAskTrigger.afterAck.wire, 'after_ack');
      expect(HostedAskTrigger.owedAfterNightAck.wire, 'owed_after_night_ack');
      expect(HostedAskTrigger.values.length, 4);
    });

    test('each path logs the event with its trigger', () async {
      const paths = <HostedAskTrigger, String>{
        HostedAskTrigger.capRefused: 'cap_refused',
        HostedAskTrigger.lastCriticalUsed: 'last_critical_used',
        HostedAskTrigger.afterAck: 'after_ack',
        HostedAskTrigger.owedAfterNightAck: 'owed_after_night_ack',
      };
      for (final entry in paths.entries) {
        final gate = _RecordingGate();
        await LocalReminderAnalytics(gate).hostedAskShown(trigger: entry.key);
        expect(gate.events.single.$1, 'hosted_ask_shown');
        expect(gate.events.single.$2, {'trigger': entry.value});
      }
    });
  });
}
