import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/feedback/data/platform_device_report_repository.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/access/access_fakes.dart';

class _Account extends Mock implements AccountRepository {}

class _Info extends Fake implements BaseDeviceInfo {}

class _Plugin extends Fake implements DeviceInfoPlugin {
  @override
  Future<BaseDeviceInfo> get deviceInfo async => _Info();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Crit Alarm',
      packageName: 'app.critalarm',
      version: '0.1.0',
      buildNumber: '5',
      buildSignature: '',
    );
  });

  /// What a report says when the phone holds [hosted] and [pro].
  Future<({String plan, String pro, String server})> read({
    required bool hosted,
    required HoldingState pro,
  }) async {
    final account = _Account();
    when(account.readHoldsHosted).thenAnswer((_) async => hosted);
    when(account.readServerMode).thenAnswer((_) async => null);
    final holdings = Holdings([
      FakeHoldingSource(Holding.hosted),
      FakeHoldingSource(Holding.pro, pro),
    ]);
    addTearDown(holdings.dispose);
    final report = await PlatformDeviceReportRepository(
      accountRepository: account,
      holdings: holdings,
      deviceInfo: _Plugin(),
    ).read(locale: 'en-PH');
    return (plan: report.plan, pro: report.pro, server: report.server);
  }

  group('a problem report names the plan and the pack as two fields', () {
    test('Cloud and Pro', () async {
      final report = await read(hosted: true, pro: HoldingState.held);
      expect(report.plan, 'cloud');
      expect(report.pro, 'yes');
    });

    test('Cloud and no Pro', () async {
      final report = await read(hosted: true, pro: HoldingState.notHeld);
      expect(report.plan, 'cloud');
      expect(report.pro, 'no');
    });

    test('Free and Pro: the pack does not make the plan Cloud', () async {
      final report = await read(hosted: false, pro: HoldingState.held);
      expect(report.plan, 'free');
      expect(report.pro, 'yes');
    });

    test('Free and no Pro', () async {
      final report = await read(hosted: false, pro: HoldingState.notHeld);
      expect(report.plan, 'free');
      expect(report.pro, 'no');
    });

    test(
      'a pending Pro purchase counts as held, as the app counts it',
      () async {
        final report = await read(hosted: false, pro: HoldingState.pending);
        expect(report.pro, 'yes');
      },
    );

    test('a pack that could not be read is unknown, never no', () async {
      final report = await read(hosted: false, pro: HoldingState.unknown);
      expect(report.plan, 'free');
      expect(report.pro, 'unknown');
    });

    test('the server field is as it was', () async {
      final report = await read(hosted: true, pro: HoldingState.held);
      expect(report.server, 'none');
    });
  });
}
