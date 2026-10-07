import 'package:flutter/foundation.dart';

/// What the relay reports about a device's last weekly check rounds
/// (api.md §4.5). It says what happened to the rounds and makes no claim
/// about the phone.
enum WeeklyCheckState {
  /// Enrolled, and no round has closed yet.
  waiting('waiting'),

  /// The last closed round was received.
  received('received'),

  /// The last closed round was missed, and the one before it was not.
  missedOnce('missed_once'),

  /// The last two or more closed rounds were missed or refused.
  missedRepeatedly('missed_repeatedly'),

  /// The last closed round was refused, and the one before it was not.
  tokenRefused('token_refused'),

  /// The relay holds no push token for the device.
  noToken('no_token'),

  /// Not enrolled, or the account no longer holds the pack.
  off('off');

  const WeeklyCheckState(this.wireValue);
  final String wireValue;

  /// A value this build does not know reads as null, and the caller shows
  /// nothing for it.
  static WeeklyCheckState? fromWire(Object? value) {
    for (final state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

/// Why [WeeklyCheckState.off] is off.
enum WeeklyCheckOffReason {
  /// The account no longer holds the pack.
  pack('pack'),

  /// The device is not enrolled.
  disabled('disabled');

  const WeeklyCheckOffReason(this.wireValue);
  final String wireValue;

  static WeeklyCheckOffReason? fromWire(Object? value) {
    for (final reason in values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}

int? _seconds(Object? value) => value is num ? value.toInt() : null;

/// `GET` and `PUT /relay/v1/devices/{device_id}/check`. Times are epoch
/// seconds on the relay's clock, and null when there is nothing to report.
@immutable
final class WeeklyCheck {
  const WeeklyCheck({
    required this.enabled,
    required this.state,
    this.reason,
    this.misses = 0,
    this.lastSentAt,
    this.lastReceivedAt,
    this.nextDueAt,
    this.noticeAfter,
  });

  factory WeeklyCheck.fromJson(Map<String, dynamic> json) => WeeklyCheck(
    // Only a literal true counts as enrolled.
    enabled: json['enabled'] == true,
    state: WeeklyCheckState.fromWire(json['state']),
    reason: WeeklyCheckOffReason.fromWire(json['reason']),
    misses: _seconds(json['misses']) ?? 0,
    lastSentAt: _seconds(json['last_sent_at']),
    lastReceivedAt: _seconds(json['last_received_at']),
    nextDueAt: _seconds(json['next_due_at']),
    noticeAfter: _seconds(json['notice_after']),
  );

  final bool enabled;

  /// Null for a state this build does not know.
  final WeeklyCheckState? state;
  final WeeklyCheckOffReason? reason;

  /// How many closed rounds in a row were missed or refused.
  final int misses;
  final int? lastSentAt;
  final int? lastReceivedAt;
  final int? nextDueAt;

  /// The second at which this device will have missed two rounds in a row if
  /// no check arrives. In the past once [misses] is 2 or more.
  final int? noticeAfter;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'state': state?.wireValue,
    'reason': reason?.wireValue,
    'misses': misses,
    'last_sent_at': lastSentAt,
    'last_received_at': lastReceivedAt,
    'next_due_at': nextDueAt,
    'notice_after': noticeAfter,
  };

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheck &&
      other.enabled == enabled &&
      other.state == state &&
      other.reason == reason &&
      other.misses == misses &&
      other.lastSentAt == lastSentAt &&
      other.lastReceivedAt == lastReceivedAt &&
      other.nextDueAt == nextDueAt &&
      other.noticeAfter == noticeAfter;

  @override
  int get hashCode => Object.hash(
    enabled,
    state,
    reason,
    misses,
    lastSentAt,
    lastReceivedAt,
    nextDueAt,
    noticeAfter,
  );

  @override
  String toString() =>
      'WeeklyCheck(enabled: $enabled, state: ${state?.wireValue}, '
      'misses: $misses)';
}

/// The answer to a receipt (api.md §4.5).
@immutable
final class WeeklyCheckReceipt {
  const WeeklyCheckReceipt({
    required this.counted,
    this.nextDueAt,
    this.noticeAfter,
  });

  factory WeeklyCheckReceipt.fromJson(Map<String, dynamic> json) =>
      WeeklyCheckReceipt(
        counted: json['counted'] == true,
        nextDueAt: _seconds(json['next_due_at']),
        noticeAfter: _seconds(json['notice_after']),
      );

  /// True when the receipt reached the relay while its round was open.
  final bool counted;
  final int? nextDueAt;
  final int? noticeAfter;
}

/// How one round ended. Null on the round means it is still open.
enum WeeklyCheckResult {
  received('received'),
  missed('missed'),
  refused('refused'),
  skipped('skipped');

  const WeeklyCheckResult(this.wireValue);
  final String wireValue;

  static WeeklyCheckResult? fromWire(Object? value) {
    for (final result in values) {
      if (result.wireValue == value) return result;
    }
    return null;
  }
}

/// One round from `GET /relay/v1/devices/{device_id}/checks`. The id here is
/// the round's own. It is never the id a push carries.
@immutable
final class WeeklyCheckRound {
  const WeeklyCheckRound({
    required this.id,
    required this.openedAt,
    this.closesAt,
    this.closedAt,
    this.attempts = 0,
    this.result,
    this.isOpen = false,
    this.attemptReceived,
    this.receiptAt,
    this.deviceReceivedAt,
    this.lateReceiptAt,
    this.reason,
  });

  factory WeeklyCheckRound.fromJson(Map<String, dynamic> json) =>
      WeeklyCheckRound(
        id: json['id']?.toString() ?? '',
        openedAt: _seconds(json['opened_at']) ?? 0,
        closesAt: _seconds(json['closes_at']),
        closedAt: _seconds(json['closed_at']),
        attempts: _seconds(json['attempts']) ?? 0,
        result: WeeklyCheckResult.fromWire(json['result']),
        // A result this build does not know is a closed round with no word
        // for it. Only a null result is an open round.
        isOpen: json['result'] == null,
        attemptReceived: _seconds(json['attempt_received']),
        receiptAt: _seconds(json['receipt_at']),
        deviceReceivedAt: _seconds(json['device_received_at']),
        lateReceiptAt: _seconds(json['late_receipt_at']),
        reason: json['reason'] as String?,
      );

  final String id;
  final int openedAt;
  final int? closesAt;
  final int? closedAt;
  final int attempts;
  final WeeklyCheckResult? result;
  final bool isOpen;
  final int? attemptReceived;
  final int? receiptAt;
  final int? deviceReceivedAt;
  final int? lateReceiptAt;

  /// Why a skipped round was skipped: `pack`, `no_token`, `disabled`, `held`
  /// or `unsent`.
  final String? reason;

  Map<String, dynamic> toJson() => {
    'id': id,
    'opened_at': openedAt,
    'closes_at': closesAt,
    'closed_at': closedAt,
    'attempts': attempts,
    'result': result?.wireValue,
    'attempt_received': attemptReceived,
    'receipt_at': receiptAt,
    'device_received_at': deviceReceivedAt,
    'late_receipt_at': lateReceiptAt,
    'reason': reason,
  };
}
