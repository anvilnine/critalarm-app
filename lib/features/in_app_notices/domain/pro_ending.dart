import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending_rule.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:flutter/foundation.dart';

enum ProPlanSheet { none, ending, ended }

@immutable
final class ProEndingView {
  const ProEndingView({
    this.sheet = ProPlanSheet.none,
    this.showPill = false,
    this.endsAt,
  });

  static const nothing = ProEndingView();

  final ProPlanSheet sheet;
  final bool showPill;

  /// Wall-clock end of Pro. Set while a cancelled plan is still running.
  final DateTime? endsAt;
}

/// Answers what the home screen shows about Pro ending: the "Pro ends" sheet,
/// the pill that follows it, or the "Pro ended" sheet.
///
/// Paid or free always comes from the server's tier
/// ([AccountAccess.isRegisteredPaid]), never the developer Force Pro switch,
/// so turning that switch off never shows "Pro ended". The store only says
/// whether Pro will renew and when it ends.
class ProEnding {
  ProEnding({
    required this._notices,
    required this._plan,
    required this._readIdentity,
    required this._readServerMode,
    required this._refreshRegistration,
    this._onPaidChanged,
    DateTime Function()? now,
    DeviceTimeZone Function()? timeZone,
  }) : _now = now ?? DateTime.now,
       _timeZone = timeZone ?? DeviceTimeZone.fromDart;

  /// Asking the server for the tier again, or the store for the plan, happens
  /// at most this often.
  static const Duration refreshGap = Duration(minutes: 5);

  final InAppNoticeRepository _notices;
  final PlanStatusSource _plan;
  final Future<DeviceIdentity> Function() _readIdentity;
  final Future<ServerMode?> Function() _readServerMode;
  final Future<void> Function() _refreshRegistration;
  final void Function()? _onPaidChanged;
  final DateTime Function() _now;
  final DeviceTimeZone Function() _timeZone;

  DateTime? _lastRefreshAt;
  bool? _lastPaid;

  /// The last store answer, kept for [refreshGap]. Home asks on every health
  /// tick, and each store read is two network calls.
  PlanStatus? _cachedPlan;
  DateTime? _cachedPlanAt;
  String? _cachedPlanAccount;

  Future<ProEndingView> read() async {
    if (await _readServerMode() != ServerMode.hosted) {
      return ProEndingView.nothing;
    }
    final now = _now();
    var identity = await _readIdentity();
    var isPaid = AccountAccess(identity).isRegisteredPaid;

    // The server drops the tier when the store says Pro expired. Until the
    // app registers again it still holds the old tier.
    final known = _notices.getProKnownExpiry();
    if (isPaid && known != null && !now.isBefore(known) && _mayRefresh(now)) {
      _lastRefreshAt = now;
      try {
        await _refreshRegistration();
      } on Object catch (_) {
        // Offline or refused. The next resume tries again.
      }
      identity = await _readIdentity();
      isPaid = AccountAccess(identity).isRegisteredPaid;
    }

    await _notePaid(identity, isPaid);

    if (!isPaid) {
      final dueFor = _notices.getProEndedSheetDueFor();
      return dueFor != null && dueFor == identity.accountId
          ? const ProEndingView(sheet: ProPlanSheet.ended)
          : ProEndingView.nothing;
    }

    final plan = await _readPlan(now, identity.accountId);
    final endsAt = plan?.expiresAt;
    if (endsAt != null && endsAt != _notices.getProKnownExpiry()) {
      await _notices.setProKnownExpiry(endsAt);
    }
    if (plan == null ||
        endsAt == null ||
        !ProEndingRule.isCancelled(plan, now)) {
      return ProEndingView.nothing;
    }

    final key = ProEndingRule.keyFor(endsAt);
    if (_notices.getProEndingSheetShownFor() != key) {
      return ProEndingView(sheet: ProPlanSheet.ending, endsAt: endsAt);
    }
    return ProEndingView(
      showPill: ProEndingRule.shouldShowPill(
        now: now,
        endsAt: endsAt,
        sheetShown: true,
        pillDismissedAt: _notices.getProEndingNoticeDismissedAt(),
        lastDaysDismissed: _notices.getProEndingLastDaysDismissedFor() == key,
      ),
      endsAt: endsAt,
    );
  }

  Future<void> markEndingSheetShown(DateTime endsAt) =>
      _notices.markProEndingSheetShown(ProEndingRule.keyFor(endsAt));

  Future<void> dismissPill(DateTime endsAt) {
    if (ProEndingRule.isLastDays(now: _now(), endsAt: endsAt)) {
      return _notices.markProEndingLastDaysDismissed(
        ProEndingRule.keyFor(endsAt),
      );
    }
    return _notices.dismissProEndingNotice();
  }

  Future<void> markEndedSheetShown() => _notices.setProEndedSheetDueFor(null);

  Future<PlanStatus?> _readPlan(DateTime now, String? accountId) async {
    final at = _cachedPlanAt;
    if (at != null &&
        _cachedPlanAccount == accountId &&
        now.difference(at) < refreshGap) {
      return _cachedPlan;
    }
    final plan = await _plan.read(_timeZone());
    _cachedPlan = plan;
    _cachedPlanAt = now;
    _cachedPlanAccount = accountId;
    return plan;
  }

  bool _mayRefresh(DateTime now) =>
      _lastRefreshAt == null || now.difference(_lastRefreshAt!) >= refreshGap;

  /// Remembers which account was on Pro, so Pro ending on that account shows
  /// the "Pro ended" sheet, and signing in to a different free account does
  /// not.
  Future<void> _notePaid(DeviceIdentity identity, bool isPaid) async {
    final accountId = identity.accountId;
    if (isPaid) {
      if (_notices.getProEndedSheetDueFor() != null) {
        await _notices.setProEndedSheetDueFor(null);
      }
      if (accountId != null) await _notices.setProPaidAccountId(accountId);
    } else {
      final paidAccount = _notices.getProPaidAccountId();
      if (paidAccount != null) {
        if (paidAccount == accountId) {
          await _notices.setProEndedSheetDueFor(accountId);
        }
        await _notices.setProPaidAccountId(null);
      }
    }
    if (_lastPaid != null && _lastPaid != isPaid) _onPaidChanged?.call();
    _lastPaid = isPaid;
  }
}
