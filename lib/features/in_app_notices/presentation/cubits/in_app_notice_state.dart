import 'package:flutter/foundation.dart';

/// The reminders Home can pin above the tab bar. One at a time.
enum InAppNoticeType { none, proEnding, accountBackup }

@immutable
class InAppNoticeState {
  const InAppNoticeState({
    this.noticeType = InAppNoticeType.none,
    this.isDismissing = false,
    this.proEndsAt,
  });

  final InAppNoticeType noticeType;
  final bool isDismissing;

  /// When Pro ends, while [noticeType] is [InAppNoticeType.proEnding].
  final DateTime? proEndsAt;

  InAppNoticeState copyWith({
    InAppNoticeType? noticeType,
    bool? isDismissing,
    DateTime? proEndsAt,
  }) {
    return InAppNoticeState(
      noticeType: noticeType ?? this.noticeType,
      isDismissing: isDismissing ?? this.isDismissing,
      proEndsAt: proEndsAt ?? this.proEndsAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNoticeState &&
          noticeType == other.noticeType &&
          isDismissing == other.isDismissing &&
          proEndsAt == other.proEndsAt;

  @override
  int get hashCode => Object.hash(noticeType, isDismissing, proEndsAt);
}
