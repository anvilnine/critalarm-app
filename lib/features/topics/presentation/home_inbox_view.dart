import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/format/when_label.dart';
import 'package:critalarm/design/components/inbox_row.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

// What an inbox row draws for a topic, as plain values. Pure, so the screen
// only hands them to `AppInboxRow`.

/// The row kind for a topic. A muted topic dims only when nothing else is
/// wrong with it, and a read topic with unread messages reads in bold.
AppInboxRowKind inboxRowKindFor({
  required InboxRowKind state,
  required bool isMuted,
  required int unreadCount,
}) => switch (state) {
  InboxRowKind.ringing => AppInboxRowKind.ringing,
  InboxRowKind.acknowledged => AppInboxRowKind.acknowledged,
  InboxRowKind.warning => AppInboxRowKind.warning,
  InboxRowKind.missed => AppInboxRowKind.missed,
  InboxRowKind.handled => AppInboxRowKind.handled,
  InboxRowKind.normal =>
    isMuted
        ? AppInboxRowKind.muted
        : (unreadCount > 0 ? AppInboxRowKind.unread : AppInboxRowKind.normal),
};

/// The words in the time cell. A row that needs the user names its state. Any
/// other row shows when its newest message came in (see `formatWhen`).
String inboxTimeText({
  required InboxRowKind state,
  required DateTime? lastMessageAt,
  required DateTime now,
}) {
  switch (state) {
    case InboxRowKind.ringing:
      return LocaleKeys.home_card_row_ringing.tr();
    case InboxRowKind.acknowledged:
      return LocaleKeys.home_card_row_acknowledged.tr();
    case InboxRowKind.warning:
      return LocaleKeys.home_card_row_warning.tr();
    case InboxRowKind.missed:
      return LocaleKeys.home_card_row_missed.tr();
    case InboxRowKind.handled:
      return LocaleKeys.home_card_row_handled.tr();
    case InboxRowKind.normal:
      break;
  }
  if (lastMessageAt == null) return '';
  return formatWhen(
    at: lastMessageAt,
    now: now,
    yesterday: LocaleKeys.home_card_row_yesterday.tr(),
  );
}

/// What a screen reader says for the bell on a Critical topic. The words
/// come from the ring claim, so an older iPhone is never told it rings
/// through silent mode.
String inboxBellLabel(RingClaim claim) => switch (claim) {
  RingClaim.alarm => LocaleKeys.home_card_bell_label.tr(),
  RingClaim.timeSensitive =>
    LocaleKeys.home_card_bell_label_time_sensitive.tr(),
};
