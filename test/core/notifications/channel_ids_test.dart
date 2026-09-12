import 'package:critalarm/core/notifications/channel_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel IDs are stable until their explicit version changes', () {
    expect(ChannelIds.alarm(), 'critical_alarm_v1');
    expect(ChannelIds.alarm(), ChannelIds.alarm());
    expect(ChannelIds.alarm(version: 2), 'critical_alarm_v2');
    expect(ChannelIds.status(), 'incident_status_v1');
    expect(ChannelIds.status(version: 2), 'incident_status_v2');
  });
}
