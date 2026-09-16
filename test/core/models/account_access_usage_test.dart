import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:flutter_test/flutter_test.dart';

AccountAccess _access({int? criticalTopics, bool known = true}) {
  return AccountAccess(
    known
        ? DeviceIdentity(
            deviceId: 'dev-1',
            accountId: 'acct-1',
            caps: AccountCaps(criticalTopics: criticalTopics),
          )
        : null,
  );
}

const _topics = [
  Topic(name: 'prod-db', critical: true),
  Topic(name: 'nas-backup'),
];

/// These lines used to be built in Dart with string interpolation, so no
/// translation could ever reach them.
void main() {
  group('AccountAccess.criticalUsage', () {
    test('says so plainly when the plan is not known yet', () {
      expect(
        _access(known: false).criticalUsage(_topics),
        'Plan limits unavailable',
      );
    });

    test('counts against a limit', () {
      expect(
        _access(criticalTopics: 3).criticalUsage(_topics),
        '1 of 3 critical topics used',
      );
    });

    test('no limit reads as unlimited, and the count is a real plural', () {
      expect(
        _access().criticalUsage(_topics),
        '1 critical topic used · Unlimited',
      );
      expect(
        _access().criticalUsage(const [
          Topic(name: 'prod-db', critical: true),
          Topic(name: 'nas-backup', critical: true),
        ]),
        '2 critical topics used · Unlimited',
      );
      expect(
        _access().criticalUsage(const []),
        '0 critical topics used · Unlimited',
      );
    });
  });
}
