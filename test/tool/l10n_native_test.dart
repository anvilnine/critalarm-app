import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n_native.dart';
import '../../tool/l10n_parity.dart';

/// The English each native surface showed before its text moved into
/// `en.json` (A313), with `{name}` where the code interpolated a value. A
/// change here is a change to what the alarm, the cards or the widgets say.
const _englishBefore = {
  // IncidentAlarmScheduler.swift, AlarmNotificationFactory.kt
  'native.alarm.stop': 'Stop',
  'native.alarm.open_app': 'Open Crit Alarm',
  // IncidentRearm.swift
  'native.alarm.still_ringing': "Still ringing. Tap I'm up to end it.",
  // AppDelegate.swift, IncidentActivityWidget.swift, WidgetSnapshot.swift,
  // AlarmNotificationFactory.kt, StatusNotificationFactory.kt, WidgetRows.kt
  'native.action.im_up': "I'm up",
  'native.action.done': 'Done',
  // MessageNotificationFactory.kt
  'native.action.ack': 'ACK',
  // IncidentContent.swift, IncidentContent.kt
  'native.content.alert': 'Alert',
  'native.content.open_to_see': 'Open Crit Alarm to see details',
  'native.content.critical_open_to_see': 'Critical alert — open to see details',
  'native.content.critical_incident': 'Critical incident',
  'native.content.attention': 'Immediate attention required',
  // critalarm-server src/push/dispatcher.ts and apns.ts (api.md §5.1, §5.3)
  'native.content.critical_alert_on': 'Critical alert on {topic}',
  'native.content.critical_alert_on_details':
      'Critical alert on {topic} — open to see details',
  // LiveCardText.swift, WidgetSnapshot.swift, WidgetRows.kt, IncidentFace.kt
  'native.state.ringing': 'Ringing',
  'native.state.awake': 'Awake',
  'native.state.quiet': 'Quiet',
  'native.state.still_open': 'Still open',
  'native.state.closed': 'Closed',
  'native.state.missed': 'Missed',
  // LiveCardText.swift, IncidentActivityWidget.swift, LiveCardText.kt,
  // StatusNotificationFactory.kt, IncidentActivityCoordinator.swift
  'native.card.still_open_line': "Still open. Tap Done if it's fixed.",
  'native.card.acked_at': 'Acknowledged at {time}',
  'native.card.acknowledged': 'Acknowledged',
  'native.card.incident_acknowledged': 'Incident acknowledged',
  'native.card.awake_for': 'Awake for {time}',
  'native.card.open_for': 'Open for {time}',
  'native.card.opened_ago': 'Opened {time} ago',
  'native.card.silenced':
      "Stopped. Rings again in {seconds} s. Tap I'm up to end it.",
  'native.card.silenced_short': 'Stopped. Rings again in {seconds} s.',
  // WidgetViews.swift (WidgetCopy), TopicsWidget.swift, WidgetRows.kt,
  // WidgetViews.kt, strings.xml
  'native.widget.locked': 'Widgets are part of Pro. Tap to see plans.',
  'native.widget.locked_short': 'Pro',
  'native.widget.connect': 'Open Crit Alarm to connect',
  'native.widget.all_quiet': 'All quiet',
  'native.widget.no_topics': 'No topics yet',
  'native.widget.topic_not_found': 'Topic not found',
  'native.widget.choose_topic': 'Choose a topic',
  'native.widget.open_app_first': 'Open Crit Alarm first',
  'native.widget.more': '+{count} more',
  'native.widget.open_count': '{count} open',
  'native.widget.open_word': 'open',
  'native.widget.open_topic': 'open · {topic}',
  'native.widget.topics_name': 'Topics',
  'native.widget.topics_description': 'Your topics, ringing ones first.',
  'native.widget.topic_name': 'Topic',
  'native.widget.topic_description': "One topic, with I'm up and Done buttons.",
  'native.widget.count_name': 'Open incidents',
  'native.widget.count_description': 'How many incidents are open right now.',
  // NotificationChannels.kt
  'native.channel.messages': 'Messages',
  'native.channel.messages_description': 'Priority 1-3 messages',
  'native.channel.urgent': 'Urgent messages',
  'native.channel.urgent_description':
      'Priority 4, and priority 5 on a topic that is not critical',
  'native.channel.alarms': 'Critical alarms',
  'native.channel.alarms_description': 'Audible on-call incident alarms',
  'native.channel.status': 'Incident status',
  'native.channel.status_description': 'Ongoing incident status',
  'native.channel.reminders': 'Local reminders',
  'native.channel.reminders_description':
      'Test checks, silent topics, backups and plan notices',
  'native.channel.offers': 'Offers',
  'native.channel.offers_description': 'News about Pro',
  // ios/Runner/Info.plist
  'native.permission.microphone':
      'Crit Alarm uses the microphone to record alarm sounds.',
  'native.permission.alarmkit':
      'Crit Alarm needs alarm access so an alarm can ring through silent mode '
      'and Do Not Disturb until you stop it.',
};

void main() {
  final english = nativeStrings(
    readTranslation(File('assets/translations/en.json')),
  );

  test('every native English string is exactly what the code said before', () {
    expect(english, _englishBefore);
  });

  test('the committed native files are what the generator writes', () {
    final files = generate(Directory.current);
    for (final entry in files.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        entry.value,
        reason: '${entry.key} is out of date: run make l10n',
      );
    }
  });

  test('only shipped locales are written, never the pseudo-locale', () {
    expect(shippedLocaleTags, isNot(contains(pseudoLocaleTag)));
    final files = generate(Directory.current);
    expect(
      files.keys.where((path) => path.contains('XA')),
      isEmpty,
    );
    final table = jsonDecode(files[iosTablePath]!) as Map<String, dynamic>;
    final strings = table['strings'] as Map<String, dynamic>;
    for (final value in strings.values) {
      final localizations =
          (value as Map<String, dynamic>)['localizations'] as Map;
      expect(localizations.keys.toSet(), shippedLocaleTags.toSet());
    }
  });

  test('the Native table carries every code string and no prompt', () {
    final table =
        jsonDecode(File(iosTablePath).readAsStringSync())
            as Map<String, dynamic>;
    final keys = (table['strings'] as Map<String, dynamic>).keys.toSet();
    expect(
      keys,
      english.keys.where((key) => !infoPlistKeys.containsKey(key)).toSet(),
    );
    final info =
        jsonDecode(File(iosInfoStringsPath).readAsStringSync())
            as Map<String, dynamic>;
    expect(
      (info['strings'] as Map<String, dynamic>).keys.toSet(),
      infoPlistKeys.values.toSet(),
    );
  });

  test('Info.plist lists the shipped locales and the English prompts', () {
    final plist = File(iosInfoPlistPath).readAsStringSync();
    expect(
      plist,
      contains(
        '<key>CFBundleLocalizations</key>\n\t<array>\n\t\t<string>en</string>'
        '\n\t</array>',
      ),
    );
    expect(
      plist,
      contains(
        '<string>${_englishBefore['native.permission.microphone']}</string>',
      ),
    );
  });

  test('a catalog holds each language under its own tag', () {
    final catalog = xcstrings({
      'en': {'native.a.b': 'Stop', 'native.a.c': 'Say "hi"'},
      'pt-BR': {'native.a.b': 'Parar'},
    });
    final strings =
        (jsonDecode(catalog) as Map<String, dynamic>)['strings']
            as Map<String, dynamic>;
    final b =
        (strings['native.a.b'] as Map<String, dynamic>)['localizations']
            as Map<String, dynamic>;
    expect(b.keys, ['en', 'pt-BR']);
    expect(
      ((b['pt-BR'] as Map)['stringUnit'] as Map)['value'],
      'Parar',
    );
    final c =
        (strings['native.a.c'] as Map<String, dynamic>)['localizations']
            as Map<String, dynamic>;
    expect(c.keys, ['en']);
    expect(((c['en'] as Map)['stringUnit'] as Map)['value'], 'Say "hi"');
    expect(
      (strings['native.a.b'] as Map<String, dynamic>)['extractionState'],
      'manual',
    );
  });

  test('Android folders and escapes', () {
    expect(androidQualifier('de'), 'de');
    expect(androidQualifier('pt-BR'), 'pt-rBR');
    expect(androidQualifier('zh-Hans'), 'b+zh+Hans');
    expect(androidValue("I'm up"), r"I\'m up");
    expect(androidValue('a & b <c>'), 'a &amp; b &lt;c&gt;');
    expect(androidValue('@home'), r'\@home');
    expect(androidValue('"x"\n'), r'\"x\"\n');
    expect(androidName('native.widget.open_count'), 'native_widget_open_count');
  });

  test('Swift and Kotlin names', () {
    expect(swiftCase('native.widget.open_count'), 'widgetOpenCount');
    expect(swiftCase('native.action.im_up'), 'actionImUp');
    expect(kotlinEntry('native.widget.open_count'), 'WIDGET_OPEN_COUNT');
    final swift = swiftNativeText(
      {
        'native.card.silenced': "Rings in {seconds} s. Tap I'm up.",
      },
      ['Crit'],
    );
    expect(swift, contains('case cardSilenced = "native.card.silenced"'));
    expect(
      swift,
      contains(
        'case .cardSilenced: return "Rings in {seconds} s. Tap I\'m up."',
      ),
    );
    final kotlin = kotlinNativeText({'native.a.b': r'Costs $5 "now"'});
    expect(
      kotlin,
      contains(r'A_B(R.string.native_a_b, "Costs \$5 \"now\"");'),
    );
  });

  test('a new language reaches Info.plist and locales_config.xml', () {
    const plist =
        '<plist version="1.0">\n<dict>\n'
        '\t<key>NSMicrophoneUsageDescription</key>\n'
        '\t<string>Old</string>\n'
        '</dict>\n</plist>\n';
    final once = updateInfoPlist(
      plist,
      tags: ['en', 'de'],
      prompts: {'NSMicrophoneUsageDescription': 'New & better'},
    );
    expect(once, contains('<string>New &amp; better</string>'));
    expect(
      once,
      contains(
        '\t<key>CFBundleLocalizations</key>\n\t<array>\n'
        '\t\t<string>en</string>\n\t\t<string>de</string>\n\t</array>\n',
      ),
    );
    final twice = updateInfoPlist(
      once,
      tags: ['en', 'de'],
      prompts: {'NSMicrophoneUsageDescription': 'New & better'},
    );
    expect(twice, once, reason: 'running twice changes nothing');
    expect(localesConfig(['en', 'pt-BR']), contains('android:name="pt-BR"'));
  });

  test('a translation that is not a plain string is refused', () {
    expect(
      () => nativeStrings({
        'native': {
          'a': {'one': 1},
        },
      }),
      throwsFormatException,
    );
    expect(
      () => nativeStrings({'app': <String, dynamic>{}}),
      throwsFormatException,
    );
  });
}
