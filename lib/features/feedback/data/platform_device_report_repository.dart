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
    DeviceInfoPlugin? deviceInfo,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final AccountRepository accountRepository;
  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<DeviceReport> read({required String locale}) async {
    final package = await PackageInfo.fromPlatform();
    final (device, os) = await _readDevice();
    final serverMode = await accountRepository.readServerMode();
    final isPaid = await accountRepository.readIsPaid();

    return DeviceReport(
      appVersion: package.version,
      buildNumber: package.buildNumber,
      device: device,
      os: os,
      server: serverMode?.name ?? 'none',
      plan: isPaid ? 'pro' : 'free',
      locale: locale,
    );
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
