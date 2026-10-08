import 'dart:async';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_notice_rule.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';
import 'package:flutter/foundation.dart';

/// How a tap on the weekly check switch ended.
enum WeeklyCheckSwitchOutcome {
  /// The relay took the change.
  done,

  /// The relay answered that the account is not on the tier the check
  /// needs.
  tierRefused,

  /// The phone is on a server of the user's own, where the check does not
  /// exist. The relay was not asked.
  notOffered,

  /// The relay answered and said no, for a reason other than the tier.
  /// Nothing changed.
  refused,

  /// The relay could not be asked. Nothing changed.
  failed,
}

/// Holds what the relay last said about this device's weekly check
/// (api.md §4.5), switches it on and off, and answers whether Home should
/// say that checks stopped arriving.
///
/// The check itself is answered by native code, with no Dart running. This
/// class never sends a receipt. It reads what the relay reports on launch
/// and resume, and what the native handler left on disk.
///
/// A received check is never proof that alarms work, and nothing here says
/// so: an alarm travels as an alert, at a higher priority, with a sound.
///
/// The check needs Hosted, and it does not exist on a server of the user's
/// own (api.md §4.5). This class decides neither: [_readAccess] hands it
/// the access layer's answer. It acts on that answer in three ways. It
/// never enrols a phone the check is not offered to, and tells the relay
/// to stop sending to one that was enrolled before. It never calls a check
/// that did not arrive a miss while the relay is sending none. And it
/// writes down when it saw that, so a clock that ran on through a lapse
/// raises nothing when Hosted is back.
final class WeeklyCheckMonitor {
  WeeklyCheckMonitor({
    required this._api,
    required this._store,
    required this._readDeviceId,
    required this._readAccess,
    required this._onTierRefused,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// One read per this long at most, unless forced.
  static const readWindow = Duration(seconds: 60);

  final WeeklyCheckApi _api;
  final WeeklyCheckStore _store;
  final Future<String?> Function() _readDeviceId;

  /// Where the check stands with the plan and the server, asked each time
  /// it matters.
  final WeeklyCheckAccess Function() _readAccess;

  /// Called when the relay says the account is not on Hosted while this
  /// phone still counts it as held, so the app reads the account's tier
  /// again. The row locks when that read says Hosted is gone. Nothing is
  /// taken away here.
  final Future<void> Function() _onTierRefused;
  final DateTime Function() _now;

  final _changes = StreamController<void>.broadcast();
  DateTime? _lastRead;
  Future<void>? _reading;

  int _nowSeconds() => _now().millisecondsSinceEpoch ~/ 1000;

  /// The relay's last answer, or null when it never answered on this phone.
  WeeklyCheck? get check => _store.readCheck()?.check;

  /// Fires when [check] or the notice may have changed.
  Stream<void> get changes => _changes.stream;

  /// Reads `GET .../check`. For launch, resume and the Reliability screen.
  ///
  /// A read that fails changes nothing: the kept answer stands.
  Future<void> refresh({bool force = false}) {
    final running = _reading;
    if (running != null) return running;
    final last = _lastRead;
    if (!force && last != null) {
      final age = _now().difference(last);
      if (!age.isNegative && age < readWindow) return Future<void>.value();
    }
    return _reading = _read().whenComplete(() => _reading = null);
  }

  static bool _saysNotHosted(WeeklyCheck? check) =>
      check != null &&
      check.state == WeeklyCheckState.off &&
      check.reason == WeeklyCheckOffReason.tier;

  Future<void> _read() async {
    try {
      await _notePlanAway();
      final deviceId = await _dropOtherDevice();
      _lastRead = _now();
      final before = _store.readCheck()?.check;
      final check = await _api.getWeeklyCheck();
      await _keep(check, deviceId: deviceId);
      // The relay says the account is not on Hosted and this phone still
      // counts it as held. What is held is what locks the row, so the tier
      // is read again rather than decided here. Asked once per change of
      // the relay's answer, so a tier that trails does not mean a read of
      // it on every resume.
      if (_saysNotHosted(check) &&
          !_saysNotHosted(before) &&
          !_readAccess().isPlanAway) {
        await _tierRefused();
      }
    } on Object catch (error) {
      // No server, no network, a relay that predates the route: all of them
      // leave the kept answer as it is.
      debugPrint('weekly_check_read_failed error=${error.runtimeType}');
    }
    await _stopWhereNotOffered();
  }

  Future<void> _tierRefused() async {
    try {
      await _onTierRefused();
    } on Object catch (error) {
      debugPrint('weekly_check_tier_read_failed error=${error.runtimeType}');
    }
    await _notePlanAway();
  }

  /// What the plan or the server allows may have changed: Hosted bought,
  /// lapsed or back, or the phone moved to or from a server of the user's
  /// own. Reads the check again at once. Hosted coming back needs no tap:
  /// the relay kept the device enrolled, and the read shows it.
  Future<void> accessChanged() async {
    await _notePlanAway();
    await refresh(force: true);
    // A read that was already running may have ended before the server
    // was known.
    await _stopWhereNotOffered();
    _announce();
  }

  /// Writes down that the relay is sending this phone no check because of
  /// the plan or the server, while that is so.
  Future<void> _notePlanAway() async {
    if (!_readAccess().isPlanAway) return;
    final now = _nowSeconds();
    if (_store.readPlanAwayAt() == now) return;
    try {
      await _store.writePlanAwayAt(now);
    } on Object catch (error) {
      debugPrint('weekly_check_store_failed error=${error.runtimeType}');
    }
  }

  /// On a server of the user's own the check is not offered, and the relay
  /// cannot see which server a phone is on (api.md §4.5). So a phone that
  /// was enrolled before it moved there tells the relay to stop, with
  /// `"enabled":false`.
  ///
  /// It is sent while the relay's last answer says the device is enrolled,
  /// which is once: the answer to it says it is not. A send that fails is
  /// tried again on the next read (launch, resume, the Reliability screen,
  /// a change of server). Nothing waits on it.
  Future<void> _stopWhereNotOffered() async {
    if (_readAccess() != WeeklyCheckAccess.notOffered) return;
    final kept = _store.readCheck();
    if (kept == null || !kept.check.enabled) return;
    try {
      final deviceId = await _dropOtherDevice();
      final answer = await _api.setWeeklyCheck(enabled: false);
      await _keep(answer, deviceId: deviceId);
    } on Object catch (error) {
      debugPrint('weekly_check_stop_failed error=${error.runtimeType}');
    }
  }

  /// Switches the check on or off with `PUT .../check`.
  ///
  /// Never enrols a phone on a server of the user's own: the relay is not
  /// asked. Enrolling without Hosted answers `403` with the tier the check
  /// needs. The app does not decide Hosted is gone by itself: it has the
  /// tier read again ([_onTierRefused]) and reads the check back. Any other
  /// refusal the relay answers with, such as the `403` with no tier that a
  /// relay before 1.19.0 sends, is [WeeklyCheckSwitchOutcome.refused]: the
  /// relay was reached, so the row must not say it was not. Only a relay
  /// that could not be asked, or that failed on its own side, is
  /// [WeeklyCheckSwitchOutcome.failed].
  Future<WeeklyCheckSwitchOutcome> setEnabled({required bool enabled}) async {
    if (enabled && _readAccess() == WeeklyCheckAccess.notOffered) {
      return WeeklyCheckSwitchOutcome.notOffered;
    }
    try {
      final deviceId = await _dropOtherDevice();
      final answer = await _api.setWeeklyCheck(enabled: enabled);
      _lastRead = _now();
      await _keep(answer, deviceId: deviceId);
      return WeeklyCheckSwitchOutcome.done;
    } on ApiException catch (error) {
      if (error.statusCode == 403 && error.tier != null) {
        await _tierRefused();
        await refresh(force: true);
        return WeeklyCheckSwitchOutcome.tierRefused;
      }
      debugPrint('weekly_check_switch_failed status=${error.statusCode}');
      if (error.statusCode >= 400 && error.statusCode < 500) {
        // Read back, so the switch shows what the relay holds.
        await refresh(force: true);
        return WeeklyCheckSwitchOutcome.refused;
      }
      return WeeklyCheckSwitchOutcome.failed;
    } on Object catch (error) {
      debugPrint('weekly_check_switch_failed error=${error.runtimeType}');
      return WeeklyCheckSwitchOutcome.failed;
    }
  }

  /// What the Home notice is decided from, or null when the relay never
  /// answered on this phone.
  Future<WeeklyCheckNoticeFacts?> noticeFacts() async {
    final kept = _store.readCheck();
    if (kept == null) return null;
    await _notePlanAway();
    WeeklyCheckArrival? arrival;
    try {
      arrival = await _store.readArrival();
    } on Object catch (error) {
      debugPrint('weekly_check_arrival_failed error=${error.runtimeType}');
    }

    // Two places hand the phone a `notice_after`: the read above, and the
    // answer to a receipt the native handler sent. The newer one stands.
    var noticeAfter = kept.check.noticeAfter;
    var noticeAfterSeenAt = kept.seenAt;
    final fromReceipt = arrival?.noticeAfter;
    final receiptAt = arrival?.noticeAfterSeenAt;
    if (fromReceipt != null && receiptAt != null && receiptAt >= kept.seenAt) {
      noticeAfter = fromReceipt;
      noticeAfterSeenAt = receiptAt;
    }
    return WeeklyCheckNoticeFacts(
      check: kept.check,
      checkSeenAt: kept.seenAt,
      noticeAfter: noticeAfter,
      noticeAfterSeenAt: noticeAfterSeenAt,
      lastArrivalAt: arrival?.receivedAt,
      dismissedAt: _store.readDismissedAt(),
      isPlanAway: _readAccess().isPlanAway,
      planAwaySeenAt: _store.readPlanAwayAt(),
    );
  }

  /// Whether Home should say that checks stopped arriving, right now.
  Future<bool> shouldShowNotice({required bool isSetupDone}) async =>
      WeeklyCheckNoticeRule.shouldShow(
        isSetupDone: isSetupDone,
        facts: await noticeFacts(),
        now: _nowSeconds(),
      );

  /// Whether two rounds in a row were missed as far as this phone can
  /// tell, whatever happened to the Home notice. For the Reliability
  /// screen. Reads what the phone holds and calls nobody.
  Future<bool> twoRoundsMissed() async => WeeklyCheckNoticeRule.twoRoundsMissed(
    facts: await noticeFacts(),
    now: _nowSeconds(),
  );

  /// The notice was closed. It stays gone for this run of misses.
  Future<void> dismissNotice() async {
    await _store.writeDismissedAt(_nowSeconds());
    _announce();
  }

  /// The kept answer belongs to one device. After a sign-out the phone has
  /// a new device id with no check state, so the old answer is dropped.
  Future<String?> _dropOtherDevice() async {
    final deviceId = await _readDeviceId();
    final kept = _store.readCheck();
    if (kept != null &&
        kept.deviceId != null &&
        deviceId != null &&
        kept.deviceId != deviceId) {
      await _store.clear();
      _announce();
    }
    return deviceId;
  }

  Future<void> _keep(WeeklyCheck check, {String? deviceId}) async {
    try {
      await _store.writeCheck(
        KeptWeeklyCheck(
          check: check,
          seenAt: _nowSeconds(),
          deviceId: deviceId,
        ),
      );
    } on Object catch (error) {
      debugPrint('weekly_check_store_failed error=${error.runtimeType}');
    }
    _announce();
  }

  void _announce() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
