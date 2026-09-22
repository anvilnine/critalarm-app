import 'package:critalarm/core/notifications/channel_ids.dart';
import 'package:critalarm/features/reminders/data/noop_reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final request = ReminderRequest(
    id: 9300,
    kind: ReminderKind.backup,
    fireAt: DateTime(2026, 9, 26, 10),
    title: 't',
    body: 'b',
    hiddenPreview: 'h',
    channelId: 'reminders_v1',
    faceAsset: 'assets/reminder_faces/thinking.png',
  );

  test('the web scheduler holds nothing', () async {
    const scheduler = NoopReminderScheduler();
    await scheduler.schedule(request);
    expect(await scheduler.pending(), isEmpty);
    expect((await scheduler.systemState()).notificationsAllowed, isFalse);
    expect(await scheduler.takePendingTap(), isNull);
  });

  test(
    'the web scheduler cancels nothing and reports the device zone',
    () async {
      const scheduler = NoopReminderScheduler();
      await scheduler.cancel([9300]);
      expect(await scheduler.deviceTimeZone(), DeviceTimeZone.fromDart());
      expect(await scheduler.taps.isEmpty, isTrue);
    },
  );

  test('reminder channels stay out of the alarm health check list', () {
    expect(ChannelIds.reminders, 'reminders_v1');
    expect(ChannelIds.offers, 'offers_v1');
    expect(ChannelIds.all(), isNot(contains(ChannelIds.reminders)));
    expect(ChannelIds.all(), isNot(contains(ChannelIds.offers)));
  });
}
