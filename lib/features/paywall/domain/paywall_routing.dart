import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter/foundation.dart';

/// A place a paywall opens from. One value per row of the table in
/// [paywallRowFor]. Several sources can share a place: the history filter
/// and the "Older alarms" line are both [history].
enum PaywallPlace {
  /// The count card under the Critical switch on the new topic screen.
  criticalLimit,

  /// The History filter and the "Older alarms" line.
  history,

  /// The widgets card on Home, a tap on a locked widget, the Personalize
  /// widgets row.
  widgets,

  /// The App icon screen and the Personalize app icon row.
  appIcons,

  /// An own alarm sound, from any way in.
  ownSounds,

  /// The alarm look, on Personalize and on a topic's page.
  alarmLook,

  /// A wake-up challenge, on Personalize and on a topic's page.
  challenge,

  /// The weekly check row on the Reliability screen.
  weeklyCheck,

  /// The plan row in Settings, Settings search, and a link with no source.
  plan,

  /// The app asked: the ask sheet, the day 0 card, the two reminders, the
  /// setup offer.
  nudge,

  /// A cancelled plan that is still running.
  planEnding,

  /// A plan that has ended.
  planEnded,
}

/// The place each Hosted source belongs to.
PaywallPlace paywallPlaceOf(PaywallSource source) => switch (source) {
  PaywallSource.createTopicCard => PaywallPlace.criticalLimit,
  PaywallSource.historyOlder || PaywallSource.history => PaywallPlace.history,
  PaywallSource.widgetLocked ||
  PaywallSource.homeWidgets ||
  PaywallSource.personalizeWidgets => PaywallPlace.widgets,
  PaywallSource.appIcon ||
  PaywallSource.personalizeAppIcon => PaywallPlace.appIcons,
  PaywallSource.personalizeSound => PaywallPlace.ownSounds,
  PaywallSource.reliability => PaywallPlace.weeklyCheck,
  PaywallSource.settingsPlan ||
  PaywallSource.settingsSearch ||
  PaywallSource.direct => PaywallPlace.plan,
  PaywallSource.askSheet ||
  PaywallSource.homeDay0Card ||
  PaywallSource.onboardingOffer ||
  PaywallSource.reminderMorningAfter ||
  PaywallSource.reminderProLater => PaywallPlace.nudge,
  PaywallSource.planSheetEnding => PaywallPlace.planEnding,
  PaywallSource.planSheetEnded => PaywallPlace.planEnded,
};

/// The place each Pro source belongs to.
PaywallPlace paywallPlaceOfPro(ProPackSheetSource source) => switch (source) {
  ProPackSheetSource.createTopicCard => PaywallPlace.criticalLimit,
  ProPackSheetSource.history ||
  ProPackSheetSource.historyOlder => PaywallPlace.history,
  ProPackSheetSource.homeWidgets ||
  ProPackSheetSource.widgetLocked ||
  ProPackSheetSource.personalizeWidgets => PaywallPlace.widgets,
  ProPackSheetSource.appIcon ||
  ProPackSheetSource.personalizeAppIcon => PaywallPlace.appIcons,
  ProPackSheetSource.personalizeSound ||
  ProPackSheetSource.sounds => PaywallPlace.ownSounds,
  ProPackSheetSource.personalizeLook ||
  ProPackSheetSource.topicLook => PaywallPlace.alarmLook,
  ProPackSheetSource.personalizeChallenge ||
  ProPackSheetSource.topicChallenge => PaywallPlace.challenge,
  ProPackSheetSource.reliability => PaywallPlace.weeklyCheck,
  ProPackSheetSource.direct => PaywallPlace.plan,
};

/// What `auto` opens for one place.
@immutable
class PaywallPlaceRow {
  const PaywallPlaceRow(
    this.layout, {
    this.lead,
    this.intro = PaywallIntroId.none,
    this.headline = PaywallHeadlineVariant.none,
  });

  final PaywallLayoutId layout;

  /// The benefit the paywall opens on, or null for a place that names none.
  final PaywallBenefitId? lead;

  /// The intro that plays first, unless Developer options set another.
  final PaywallIntroId intro;

  /// The words for a plan that is ending or ended.
  final PaywallHeadlineVariant headline;
}

/// The table. The same for both products: Pro has no entry point in the
/// rows that are Hosted only. The one place a place is mapped to a lead
/// benefit.
PaywallPlaceRow paywallRowFor(PaywallPlace place) => switch (place) {
  PaywallPlace.criticalLimit => const PaywallPlaceRow(
    PaywallLayoutId.sheet,
    lead: PaywallBenefitId.topics,
    intro: PaywallIntroId.falseAlarm,
  ),
  PaywallPlace.history => const PaywallPlaceRow(
    PaywallLayoutId.proof,
    lead: PaywallBenefitId.history,
  ),
  PaywallPlace.widgets => const PaywallPlaceRow(
    PaywallLayoutId.sheet,
    lead: PaywallBenefitId.widgets,
  ),
  PaywallPlace.appIcons => const PaywallPlaceRow(
    PaywallLayoutId.sheet,
    lead: PaywallBenefitId.appIcons,
  ),
  PaywallPlace.ownSounds => const PaywallPlaceRow(
    PaywallLayoutId.sheet,
    lead: PaywallBenefitId.customSounds,
  ),
  PaywallPlace.alarmLook => const PaywallPlaceRow(
    PaywallLayoutId.sheet,
    lead: PaywallBenefitId.customAlarmScreens,
  ),
  PaywallPlace.challenge => const PaywallPlaceRow(
    PaywallLayoutId.sheet,
    lead: PaywallBenefitId.wakeUpChallenges,
  ),
  PaywallPlace.weeklyCheck => const PaywallPlaceRow(
    PaywallLayoutId.proof,
    lead: PaywallBenefitId.reliabilityChecks,
  ),
  PaywallPlace.plan => const PaywallPlaceRow(PaywallLayoutId.hero),
  PaywallPlace.nudge => const PaywallPlaceRow(PaywallLayoutId.reel),
  PaywallPlace.planEnding => const PaywallPlaceRow(
    PaywallLayoutId.wipe,
    lead: PaywallBenefitId.history,
    headline: PaywallHeadlineVariant.leaving,
  ),
  PaywallPlace.planEnded => const PaywallPlaceRow(
    PaywallLayoutId.wipe,
    lead: PaywallBenefitId.history,
    headline: PaywallHeadlineVariant.ended,
  ),
};

/// What plays after a confirmed purchase when Developer options set nothing:
/// Receipt party for Hosted, Stamp for Pro.
PaywallThanksId paywallDefaultThanksFor(PaywallProduct product) =>
    switch (product) {
      PaywallProduct.hosted => PaywallThanksId.receiptParty,
      PaywallProduct.pro => PaywallThanksId.stamp,
    };

/// The success outro a product's paywall plays when Developer options set
/// nothing: Cloud climb for Hosted, Break, lift, ring for Pro.
PaywallOutroId paywallDefaultOutroFor(PaywallProduct product) =>
    switch (product) {
      PaywallProduct.hosted => PaywallOutroId.cloudClimb,
      PaywallProduct.pro => PaywallOutroId.breakLiftRing,
    };

/// What the door worked out about a plan that is ending: which of the two
/// layouts the person's numbers earn, and how many days of history the
/// phone holds.
@immutable
class LeavingChoice {
  const LeavingChoice({required this.showsReceipt, this.historyDaysHeld});

  final bool showsReceipt;

  /// Null when it is not known. That reads as enough history.
  final int? historyDaysHeld;
}

/// What opens: a layout, the intro that plays before it, the thanks that
/// plays after a confirmed purchase, the benefit it opens on and the
/// headline variant.
@immutable
class PaywallOpening {
  const PaywallOpening(
    this.layout, {
    this.intro = PaywallIntroId.none,
    this.thanks = PaywallThanksId.none,
    this.outro = PaywallOutroId.none,
    this.lead,
    this.headline = PaywallHeadlineVariant.none,
  });

  final PaywallLayoutId layout;

  /// `none` when the layout opens with its own entrance alone.
  final PaywallIntroId intro;

  /// `none` when a purchase ends with nothing of its own.
  final PaywallThanksId thanks;

  /// `none` when a purchase goes straight to the thanks. Always `none`
  /// when [thanks] is.
  final PaywallOutroId outro;

  /// The benefit to open on. Null when the place names none, or when the
  /// product does not list it.
  final PaywallBenefitId? lead;

  /// `none` unless the plan is ending or has ended.
  final PaywallHeadlineVariant headline;

  @override
  bool operator ==(Object other) =>
      other is PaywallOpening &&
      other.layout == layout &&
      other.intro == intro &&
      other.thanks == thanks &&
      other.outro == outro &&
      other.lead == lead &&
      other.headline == headline;

  @override
  int get hashCode => Object.hash(layout, intro, thanks, outro, lead, headline);

  @override
  String toString() =>
      'PaywallOpening(${layout.key}, intro: ${intro.key}, '
      'thanks: ${thanks.key}'
      '${outro == PaywallOutroId.none ? '' : ', outro: ${outro.key}'}, '
      'lead: ${lead?.key}, headline: ${headline.key})';
}

/// What opens for [product] from [place]: a layout with its intro, thanks,
/// outro, lead and headline. There is always an answer. No remote value has
/// a say: every default is written here and in the table.
///
/// [developer] is what Developer options pinned, null in a store build and
/// whenever nothing is pinned. A pinned layout outranks the table for the
/// layout. A pinned `doors` reads as `hero`. The lead and the headline
/// always come from the place. A lead that is not in [listedBenefits] (what
/// this build lists for [product]) is dropped and the layout stays.
///
/// The intro is a second value. [developerIntro] outranks the table's
/// intro, which only Hosted plays. The false alarm plays once on an install:
/// while [hasSeenFalseAlarm] is true no setting plays it again.
///
/// The thanks is a third value. [developerThanks] outranks the product's
/// own thanks ([paywallDefaultThanksFor]), `none` included.
///
/// The outro is a fourth value. [developerOutro] outranks the product's own
/// outro ([paywallDefaultOutroFor]), `none` included. The place never
/// changes it. It plays between a purchase and the thanks, so it is `none`
/// whenever the thanks is.
///
/// [leaving] is the one input for a Hosted plan that is ending
/// ([PaywallPlace.planEnding]), and no other place reads it. With good
/// numbers the layout is the receipt and no lead. With thin ones it is Wipe,
/// on history when the phone holds a week of it or more (or does not know),
/// and on critical topics when it holds less. With no choice the table's
/// row stands. A pinned layout still outranks all of it, and the headline
/// is `leaving` either way. The receipt opens from no other place.
PaywallOpening paywallOpeningFor({
  required PaywallProduct product,
  required PaywallPlace place,
  required bool hasSeenFalseAlarm,
  required Set<PaywallBenefitId> listedBenefits,
  PaywallLayoutSetting? developer,
  PaywallIntroId? developerIntro,
  PaywallThanksId? developerThanks,
  PaywallOutroId? developerOutro,
  LeavingChoice? leaving,
}) {
  var row = paywallRowFor(place);
  if (product == PaywallProduct.hosted &&
      place == PaywallPlace.planEnding &&
      leaving != null) {
    final held = leaving.historyDaysHeld;
    final hasWeek = held == null || held >= (AccountCaps.free.historyDays ?? 7);
    row = leaving.showsReceipt
        ? const PaywallPlaceRow(
            PaywallLayoutId.receipt,
            headline: PaywallHeadlineVariant.leaving,
          )
        : PaywallPlaceRow(
            PaywallLayoutId.wipe,
            lead: hasWeek ? PaywallBenefitId.history : PaywallBenefitId.topics,
            headline: PaywallHeadlineVariant.leaving,
          );
  }

  var layout = developer?.layout ?? row.layout;
  // Doors left the table. A value that still names it opens hero.
  if (layout == PaywallLayoutId.doors) layout = PaywallLayoutId.hero;

  final wanted = row.lead;
  final lead = wanted != null && listedBenefits.contains(wanted)
      ? wanted
      : null;

  // The false alarm joke is Hosted's: Pro never plays it from the table.
  // A developer intro value still plays for either product.
  final isHosted = product == PaywallProduct.hosted;
  var intro = developerIntro ?? (isHosted ? row.intro : PaywallIntroId.none);
  if (intro == PaywallIntroId.falseAlarm && hasSeenFalseAlarm) {
    intro = PaywallIntroId.none;
  }

  final thanks = developerThanks ?? paywallDefaultThanksFor(product);
  return PaywallOpening(
    layout,
    intro: intro,
    thanks: thanks,
    outro: thanks == PaywallThanksId.none
        ? PaywallOutroId.none
        : developerOutro ?? paywallDefaultOutroFor(product),
    lead: lead,
    headline: row.headline,
  );
}
