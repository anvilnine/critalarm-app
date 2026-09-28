import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';

/// Where idea 8 reads the Pro plan from. Null when there is no active Pro
/// plan or the store cannot be reached.
// ignore: one_member_abstracts
abstract interface class PlanStatusSource {
  Future<PlanStatus?> read(DeviceTimeZone timeZone);
}
