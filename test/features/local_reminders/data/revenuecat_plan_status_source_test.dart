import 'package:critalarm/features/local_reminders/data/revenuecat_plan_status_source.dart';
import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  const manila = DeviceTimeZone(name: 'Asia/Manila', offsetMinutes: 480);
  const url = 'https://apps.apple.com/account/subscriptions';

  EntitlementInfo entitlement({
    String product = 'app.critalarm.hosted.annual',
    String? plan,
    bool willRenew = true,
    String? expires = '2026-10-04T07:00:00Z',
    String? billingIssue,
  }) => EntitlementInfo(
    'hosted',
    true,
    willRenew,
    '2025-10-04T07:00:00Z',
    '2025-10-04T07:00:00Z',
    product,
    false,
    expirationDate: expires,
    billingIssueDetectedAt: billingIssue,
    productPlanIdentifier: plan,
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

  PlanStatus? read(
    EntitlementInfo? active, {
    Map<String, String> prices = const {
      'app.critalarm.hosted.annual': 'PRICE',
      'app.critalarm.hosted:yearly': 'PLAY_PRICE',
    },
  }) => RevenueCatPlanStatusSource.planStatusFrom(
    info(active),
    pricesByProduct: prices,
    timeZone: manila,
  );

  test('a yearly App Store plan, in wall-clock time, with its price', () {
    final plan = read(entitlement())!;
    expect(plan.isActive, isTrue);
    expect(plan.isYearly, isTrue);
    expect(plan.willRenew, isTrue);
    expect(plan.expiresAt, DateTime(2026, 10, 4, 15));
    expect(plan.priceString, 'PRICE');
    expect(plan.managementUrl, url);
  });

  test('a yearly Play plan reads its base plan id', () {
    final plan = read(
      entitlement(product: 'app.critalarm.hosted', plan: 'yearly'),
    )!;
    expect(plan.isYearly, isTrue);
    expect(plan.priceString, 'PLAY_PRICE');
  });

  test('takes the price of the product the user owns, never another', () {
    final plan = read(
      entitlement(product: 'app.critalarm.hosted.annual_old'),
      prices: const {'app.critalarm.hosted.annual': 'PRICE'},
    )!;
    expect(plan.isYearly, isTrue);
    expect(plan.priceString, isNull);
  });

  test('a monthly plan has no price for the renewal notice', () {
    final plan = read(entitlement(product: 'app.critalarm.hosted.monthly'))!;
    expect(plan.isYearly, isFalse);
    expect(plan.priceString, isNull);
  });

  test('reads a billing issue and a cancelled plan', () {
    final plan = read(
      entitlement(willRenew: false, billingIssue: '2026-09-21T01:00:00Z'),
    )!;
    expect(plan.willRenew, isFalse);
    expect(plan.billingIssueAt, DateTime(2026, 9, 21, 9));
  });

  test('no Pro entitlement means no plan', () {
    expect(read(null), isNull);
  });
}
