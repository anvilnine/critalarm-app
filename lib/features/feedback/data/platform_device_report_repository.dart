import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/feedback/domain/device_report.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the device through `device_info_plus` and the build through
/// `package_info_plus`.
class PlatformDeviceReportRepository implements DeviceReportRepository {
  PlatformDeviceReportRepository({
    required this.accountRepository,
    required this.holdings,
    DeviceInfoPlugin? deviceInfo,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final AccountRepository accountRepository;
  final Holdings holdings;
  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<DeviceReport> read({required String locale}) async {
    final package = await PackageInfo.fromPlatform();
    final (device, os) = await _readDevice();
    final serverMode = await accountRepository.readServerMode();
    final holdsHosted = await accountRepository.readHoldsHosted();

    return DeviceReport(
      appVersion: package.version,
      buildNumber: package.buildNumber,
      device: device,
      os: os,
      server: serverMode?.name ?? 'none',
      plan: holdsHosted ? 'cloud' : 'free',
      pro: await _readPro(),
      locale: locale,
    );
  }

  /// `yes` or `no` for the Pro pack, from the same holdings the app locks
  /// by. A pack that could not be read is `unknown`, never `no`.
  Future<String> _readPro() async {
    try {
      return await holdings.holdsOnceReady(Holding.pro) ? 'yes' : 'no';
    } on HoldingUnreadable {
      return 'unknown';
    }
  }

  Future<(String, String)> _readDevice() async {
    final info = await _deviceInfo.deviceInfo;
    return switch (info) {
      IosDeviceInfo() => (
        info.utsname.machine,
        '${info.systemName} ${info.systemVersion}',
      ),
      AndroidDeviceInfo() => (
        '${info.manufacturer} ${info.model}',
        'Android ${info.version.release}',
      ),
      WebBrowserInfo() => (info.browserName.name, info.platform ?? 'web'),
      _ => ('unknown', 'unknown'),
    };
  }
}
