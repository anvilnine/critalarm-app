import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';

/// Every intro that is built, by id. To add one, add its line here. `none`
/// has no line, and an id with no line plays nothing: the layout opens as
/// it does alone.
final Map<PaywallIntroId, PaywallIntro> paywallIntroBuilders = {
  PaywallIntroId.falseAlarm: falseAlarmIntro,
};

/// Whether [intro] can be played as asked: `none` always can, and any other
/// id when it has a line above.
bool paywallIntroIsBuilt(PaywallIntroId intro) =>
    intro == PaywallIntroId.none || paywallIntroBuilders.containsKey(intro);
