import 'dart:async';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_notice_rule.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';
import 'package:flutter/foundation.dart';

/// How a tap on the weekly check switch ended.
enum WeeklyCheckSwitchOutcome {
  /// The relay took the change.
  done,

  /// The relay answered that the account does not hold the pack.
  packRefused,

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
final class WeeklyCheckMonitor {
  WeeklyCheckMonitor({
    required this._api,
    required this._store,
    required this._readDeviceId,
    required this._onPackRefused,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// One read per this long at most, unless forced.
  static const readWindow = Duration(seconds: 60);

  final WeeklyCheckApi _api;
  final WeeklyCheckStore _store;
  final Future<String?> Function() _readDeviceId;

  /// Told the pack a `403` named, so the app reads the account's packs
  /// again and the row locks if the relay says the pack is gone.
  final Future<void> Function(String? packId) _onPackRefused;
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

  Future<void> _read() async {
    try {
      final deviceId = await _dropOtherDevice();
      _lastRead = _now();
      final check = await _api.getWeeklyCheck();
      await _keep(check, deviceId: deviceId);
      // The relay says the pack is gone. The packs list is what locks the
      // row, so it is read again rather than decided here.
      if (check.state == WeeklyCheckState.off &&
          check.reason == WeeklyCheckOffReason.pack) {
        await _onPackRefused(proPackId);
      }
    } on Object catch (error) {
      // No server, no network, a relay that predates the route: all of them
      // leave the kept answer as it is.
      debugPrint('weekly_check_read_failed error=${error.runtimeType}');
    }
  }

  /// Switches the check on or off with `PUT .../check`.
  ///
  /// Enrolling without the pack answers `403`. The app does not decide the
  /// pack is gone by itself: it hands the pack named to [_onPackRefused]
  /// and reads the check back.
  Future<WeeklyCheckSwitchOutcome> setEnabled({required bool enabled}) async {
    try {
      final deviceId = await _dropOtherDevice();
      final answer = await _api.setWeeklyCheck(enabled: enabled);
      _lastRead = _now();
      await _keep(answer, deviceId: deviceId);
      return WeeklyCheckSwitchOutcome.done;
    } on ApiException catch (error) {
      if (error.statusCode == 403 && error.pack != null) {
        await _onPackRefused(error.pack);
        await refresh(force: true);
        return WeeklyCheckSwitchOutcome.packRefused;
      }
      debugPrint('weekly_check_switch_failed status=${error.statusCode}');
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
    );
  }

  /// Whether Home should say that checks stopped arriving, right now.
  Future<bool> shouldShowNotice({required bool isSetupDone}) async =>
      WeeklyCheckNoticeRule.shouldShow(
        isSetupDone: isSetupDone,
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
