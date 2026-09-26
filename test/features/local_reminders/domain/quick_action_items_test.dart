import 'package:critalarm/features/local_reminders/domain/quick_action_items.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ring me now shows only with a critical topic to test', () {
    expect(QuickActionItems.visible(hasCriticalTopic: true), [
      QuickActionType.ringMeNow,
      QuickActionType.openIncidents,
      QuickActionType.newTopic,
    ]);
    expect(QuickActionItems.visible(hasCriticalTopic: false), [
      QuickActionType.openIncidents,
      QuickActionType.newTopic,
    ]);
  });

  test('each action opens its screen; Ring me now always confirms first', () {
    expect(QuickActionType.ringMeNow.path, '/ring');
    expect(QuickActionType.openIncidents.path, '/history');
    expect(QuickActionType.newTopic.path, '/topics/new');
    expect(QuickActionType.fromWire('ring_me_now'), QuickActionType.ringMeNow);
    expect(QuickActionType.fromWire('nope'), isNull);
  });
}
