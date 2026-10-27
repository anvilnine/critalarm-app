import 'package:critalarm/design/components/readiness_pips.dart';
import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/readiness_pips.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

// How the dark card draws the phone's checks, for every screen that has one.
// The Topics card and the Settings card both read these, so a count, a pip or
// a line is worded once. The rule behind them is `readinessKindOf` and
// `ReadinessSummary` (domain).

/// The pip a check of [tone] gets.
AppPipTone readinessPipTone(PipTone tone) => switch (tone) {
  PipTone.fine => AppPipTone.fine,
  PipTone.look => AppPipTone.look,
  PipTone.broken => AppPipTone.broken,
  PipTone.open => AppPipTone.open,
};

/// The colour of the numeral for [kind].
AppStatusTone readinessNumeralTone(ReadinessKind kind) => switch (kind) {
  ReadinessKind.loading => AppStatusTone.muted,
  ReadinessKind.fine => AppStatusTone.yellow,
  ReadinessKind.look => AppStatusTone.orange,
  ReadinessKind.broken => AppStatusTone.red,
};

/// The headline [kind] maps to, so the face and the words come from the same
/// place as the Reliability screen's.
ReliabilityHeadline readinessHeadline(ReadinessKind kind) => switch (kind) {
  ReadinessKind.loading => ReliabilityHeadline.loading,
  ReadinessKind.fine => ReliabilityHeadline.fine,
  ReadinessKind.look => ReliabilityHeadline.needsLook,
  ReadinessKind.broken => ReliabilityHeadline.broken,
};

/// The face the Reliability screen wears for [kind].
FaceState readinessFace(ReadinessKind kind) =>
    reliabilityHeadlineView(readinessHeadline(kind)).face;

/// The short lower-case line for a failing check ("battery saver is on").
String readinessCheckLine(ReliabilityCheckId? id) {
  final key = switch (id?.value) {
    'notifications' => LocaleKeys.home_card_check_notifications,
    'full_screen_alarm' => LocaleKeys.home_card_check_full_screen_alarm,
    'battery_optimization' => LocaleKeys.home_card_check_battery_optimization,
    'alarms' => LocaleKeys.home_card_check_alarms,
    'time_sensitive' => LocaleKeys.home_card_check_time_sensitive,
    'push_token_confirmed' => LocaleKeys.home_card_check_push_token_confirmed,
    'last_push_received' => LocaleKeys.home_card_check_last_push_received,
    'system_update' => LocaleKeys.home_card_check_system_update,
    'phone_maker' => LocaleKeys.home_card_check_phone_maker,
    'missed_alarm' => LocaleKeys.home_card_check_missed_alarm,
    _ => LocaleKeys.home_card_check_other,
  };
  return key.tr();
}
