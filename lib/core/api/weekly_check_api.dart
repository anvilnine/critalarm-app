import 'package:critalarm/core/models/weekly_check.dart';

/// The four relay routes of the weekly check (api.md §4.5).
///
/// All four are authorised with this device's own `dv_` token and reach this
/// one device's data.
abstract interface class WeeklyCheckApi {
  /// PUT /relay/v1/devices/{device_id}/check
  ///
  /// Enrols the device or stops its checks. Enrolling without the pack
  /// answers `403 {"error":"pack","pack":"pro"}`. Stopping always answers.
  Future<WeeklyCheck> setWeeklyCheck({required bool enabled});

  /// GET /relay/v1/devices/{device_id}/check
  Future<WeeklyCheck> getWeeklyCheck();

  /// POST /relay/v1/devices/{device_id}/checks/{check_id}/receipt
  ///
  /// [checkId] comes from the push and from nowhere else. Never log it.
  /// [attempt] and [receivedAt] (epoch seconds, this phone's clock) are
  /// notes: neither makes a receipt count or stops it counting.
  Future<WeeklyCheckReceipt> sendWeeklyCheckReceipt(
    String checkId, {
    int? attempt,
    int? receivedAt,
  });

  /// GET /relay/v1/devices/{device_id}/checks
  ///
  /// The device's rounds, newest first. Answers with or without the pack.
  Future<List<WeeklyCheckRound>> listWeeklyCheckRounds({int? limit});
}

/// For a build whose API client does not speak the weekly check routes.
/// Every call fails the way a missing server does, so a caller keeps what
/// it had.
final class NoWeeklyCheckApi implements WeeklyCheckApi {
  const NoWeeklyCheckApi();

  @override
  Future<WeeklyCheck> setWeeklyCheck({required bool enabled}) =>
      throw StateError('No weekly check API');

  @override
  Future<WeeklyCheck> getWeeklyCheck() =>
      throw StateError('No weekly check API');

  @override
  Future<WeeklyCheckReceipt> sendWeeklyCheckReceipt(
    String checkId, {
    int? attempt,
    int? receivedAt,
  }) => throw StateError('No weekly check API');

  @override
  Future<List<WeeklyCheckRound>> listWeeklyCheckRounds({int? limit}) =>
      throw StateError('No weekly check API');
}
