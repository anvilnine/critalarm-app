import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/features/paywall/presentation/intros/alarm_snack/alarm_snack_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/curtain/curtain_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/snooze/snooze_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/wake_up/wake_up_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';

/// Every intro that is built, by id. To add one, add its line here. `none`
/// has no line, and an id with no line plays nothing: the layout opens as
/// it does alone.
final Map<PaywallIntroId, PaywallIntro> paywallIntroBuilders = {
  PaywallIntroId.falseAlarm: falseAlarmIntro,
  PaywallIntroId.snooze: snoozeIntro,
  PaywallIntroId.wakeUp: wakeUpIntro,
  PaywallIntroId.curtain: curtainIntro,
  PaywallIntroId.alarmSnack: alarmSnackIntro,
};

/// Whether [intro] can be played as asked: `none` always can, and any other
/// id when it has a line above.
bool paywallIntroIsBuilt(PaywallIntroId intro) =>
    intro == PaywallIntroId.none || paywallIntroBuilders.containsKey(intro);

/// The layouts an intro leaves no tag on. Their mascot does not stand in
/// air of its own, so a tag by it would lie over the picture behind.
const Set<PaywallLayoutId> paywallIntroTaglessLayouts = {PaywallLayoutId.sheet};
