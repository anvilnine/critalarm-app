import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/feedback/data/platform_device_report_repository.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:get_it/get_it.dart';

/// The device report repository.
void registerDeviceReport(GetIt getIt) {
  getIt.registerLazySingleton<DeviceReportRepository>(
    () => PlatformDeviceReportRepository(
      accountRepository: getIt<AccountRepository>(),
      holdings: getIt<Holdings>(),
    ),
  );
}
