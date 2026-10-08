import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';

/// A relay that answers what the test scripted, and counts the calls.
class FakeWeeklyCheckApi implements WeeklyCheckApi {
  /// What `GET .../check` answers. Null throws, as no network does.
  WeeklyCheck? check = const WeeklyCheck(
    enabled: false,
    state: WeeklyCheckState.off,
    reason: WeeklyCheckOffReason.disabled,
  );

  /// The tier the relay holds for the account. On any tier but `hosted`,
  /// enrolling answers the tier error (api.md §4.5).
  String tier = 'hosted';

  /// True makes a refused enrolment answer as a relay before 1.19.0 did:
  /// the pack error, with no `tier` field.
  bool answersAsBefore119 = false;

  /// True makes every call throw, as no network does.
  bool isDown = false;

  List<WeeklyCheckRound> rounds = const [];

  int reads = 0;
  final List<bool> puts = [];
  final List<int?> limits = [];

  @override
  Future<WeeklyCheck> getWeeklyCheck() async {
    reads++;
    final answer = check;
    if (isDown || answer == null) throw Exception('no network');
    return answer;
  }

  @override
  Future<WeeklyCheck> setWeeklyCheck({required bool enabled}) async {
    puts.add(enabled);
    if (isDown) throw Exception('no network');
    if (enabled && tier != 'hosted') {
      throw answersAsBefore119
          ? const ApiException(statusCode: 403, message: 'pack', pack: 'pro')
          : const ApiException(
              statusCode: 403,
              message: 'tier',
              tier: 'hosted',
            );
    }
    return check = enabled
        ? const WeeklyCheck(
            enabled: true,
            state: WeeklyCheckState.waiting,
            nextDueAt: 2000,
            noticeAfter: 9000,
          )
        : const WeeklyCheck(
            enabled: false,
            state: WeeklyCheckState.off,
            reason: WeeklyCheckOffReason.disabled,
          );
  }

  @override
  Future<WeeklyCheckReceipt> sendWeeklyCheckReceipt(
    String checkId, {
    int? attempt,
    int? receivedAt,
  }) async => const WeeklyCheckReceipt(counted: true);

  @override
  Future<List<WeeklyCheckRound>> listWeeklyCheckRounds({int? limit}) async {
    limits.add(limit);
    if (isDown) throw Exception('no network');
    return rounds;
  }
}

class MemoryWeeklyCheckStore implements WeeklyCheckStore {
  KeptWeeklyCheck? kept;
  WeeklyCheckArrival? arrival;
  int? dismissedAt;
  int? planAwayAt;

  @override
  int? readPlanAwayAt() => planAwayAt;

  @override
  Future<void> writePlanAwayAt(int at) async => planAwayAt = at;

  @override
  KeptWeeklyCheck? readCheck() => kept;

  @override
  Future<void> writeCheck(KeptWeeklyCheck kept) async => this.kept = kept;

  @override
  Future<WeeklyCheckArrival?> readArrival() async => arrival;

  @override
  int? readDismissedAt() => dismissedAt;

  @override
  Future<void> writeDismissedAt(int at) async => dismissedAt = at;

  @override
  Future<void> clear() async {
    kept = null;
    arrival = null;
    dismissedAt = null;
    planAwayAt = null;
  }
}
