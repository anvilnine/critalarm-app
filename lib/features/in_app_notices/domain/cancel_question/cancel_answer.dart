import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:flutter/foundation.dart';

/// One send that did not reach the server yet. It names the account it was
/// made on, so a retry never lands on someone else's.
@immutable
final class CancelAnswer {
  const CancelAnswer({
    required this.accountId,
    required this.reason,
    required this.appVersion,
    required this.platform,
    this.text,
    this.retries = 0,
  });

  final String accountId;
  final CancelReason reason;
  final String? text;
  final String appVersion;
  final String platform;

  /// Later launches that already tried this send and failed.
  final int retries;

  CancelAnswer withRetry() => CancelAnswer(
    accountId: accountId,
    reason: reason,
    text: text,
    appVersion: appVersion,
    platform: platform,
    retries: retries + 1,
  );

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'reason': reason.wire,
    'text': text,
    'app_version': appVersion,
    'platform': platform,
    'retries': retries,
  };

  /// Null for anything that is not a whole entry.
  static CancelAnswer? fromJson(Object? json) {
    if (json is! Map) return null;
    final accountId = json['account_id'];
    final rawReason = json['reason'];
    final reason = rawReason is String
        ? CancelReason.fromWire(rawReason)
        : null;
    final appVersion = json['app_version'];
    final platform = json['platform'];
    final text = json['text'];
    final retries = json['retries'];
    if (accountId is! String ||
        reason == null ||
        appVersion is! String ||
        platform is! String ||
        (text != null && text is! String) ||
        retries is! int ||
        retries < 0) {
      return null;
    }
    return CancelAnswer(
      accountId: accountId,
      reason: reason,
      text: text as String?,
      appVersion: appVersion,
      platform: platform,
      retries: retries,
    );
  }
}
