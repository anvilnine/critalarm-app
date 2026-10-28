import 'package:critalarm/features/local_reminders/data/revenuecat_plan_status_source.dart';
import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  const manila = DeviceTimeZone(name: 'Asia/Manila', offsetMinutes: 480);
  const newYork = DeviceTimeZone(name: 'America/New_York', offsetMinutes: -240);
  const url = 'https://apps.apple.com/account/subscriptions';

  EntitlementInfo entitlement({String? expires = '2026-10-20T09:15:02.481Z'}) =>
      EntitlementInfo(
        'hosted',
        true,
        false,
        '2025-10-04T07:00:00Z',
        '2025-10-04T07:00:00Z',
        'app.critalarm.hosted.annual',
        false,
        expirationDate: expires,
      );

  CustomerInfo info(EntitlementInfo? active) => CustomerInfo(
    EntitlementInfos({'hosted': ?active}, {'hosted': ?active}),
    const {},
    const [],
    const [],
    const [],
    '2025-10-04T07:00:00Z',
    'user_1',
    const {},
    '2026-09-22T00:00:00Z',
    managementURL: url,
  );

  PlanStatus? read(EntitlementInfo? active, DeviceTimeZone zone) =>
      RevenueCatPlanStatusSource.planStatusFrom(
        info(active),
        pricesByProduct: const {},
        timeZone: zone,
      );

  test('the instant is the parsed expiry in UTC in every zone', () {
    final expected = DateTime.utc(2026, 10, 20, 9, 15, 2, 481);
    for (final zone in [manila, newYork, DeviceTimeZone.utc]) {
      final plan = read(entitlement(), zone)!;
      expect(plan.expiresAtInstant, expected);
      expect(plan.expiresAtInstant!.isUtc, isTrue);
    }
  });

  test('the wall-clock expiry still differs by zone', () {
    final inManila = read(entitlement(), manila)!;
    final inNewYork = read(entitlement(), newYork)!;
    expect(inManila.expiresAt, isNot(inNewYork.expiresAt));
    expect(inManila.expiresAtInstant, inNewYork.expiresAtInstant);
  });

  test('no expiry date gives a null instant', () {
    expect(read(entitlement(expires: null), manila)!.expiresAtInstant, isNull);
  });
}
