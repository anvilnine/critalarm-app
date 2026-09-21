import 'package:critalarm/features/feedback/domain/device_report.dart';

/// Reads the phone, the build and the account into a [DeviceReport].
// ignore: one_member_abstracts
abstract interface class DeviceReportRepository {
  Future<DeviceReport> read({required String locale});
}
