import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:flutter/foundation.dart';

/// A topic as the rules see it. Times are wall-clock.
@immutable
final class ReminderTopic {
  const ReminderTopic({
    required this.name,
    this.isCritical = false,
    this.createdAt,
  });

  final String name;
  final bool isCritical;
  final DateTime? createdAt;
}

/// An incident as the rules see it. Times are wall-clock.
@immutable
final class ReminderIncident {
  const ReminderIncident({
    required this.id,
    required this.topic,
    this.isTest = false,
    this.isOpenOrAcked = false,
    this.openedAt,
    this.ackedAt,
  });

  final String id;
  final String topic;

  /// A test or demo alarm (`IncidentKinds.isTest`).
  final bool isTest;

  /// Still ringing or waiting for "At my desk".
  final bool isOpenOrAcked;

  /// When it rang.
  final DateTime? openedAt;
  final DateTime? ackedAt;
}

/// What RevenueCat says about the Pro plan, reduced to what idea 8 reads.
@immutable
final class PlanStatus {
  const PlanStatus({
    required this.isActive,
    required this.isYearly,
    required this.willRenew,
    this.expiresAt,
    this.billingIssueAt,
    this.priceString,
    this.managementUrl,
  });

  final bool isActive;
  final bool isYearly;
  final bool willRenew;

  /// Wall-clock.
  final DateTime? expiresAt;

  /// Wall-clock. Set while the store cannot take the payment.
  final DateTime? billingIssueAt;

  /// The store's own price text for the yearly plan, in the user's currency.
  final String? priceString;

  /// The store's subscription page.
  final String? managementUrl;
}

/// Everything the planner reads, gathered once per plan pass.
///
/// Every `DateTime` in here is wall-clock time on the phone (see
/// `DeviceTimeZone.toWall`). Defaults describe a fresh hosted install with
/// nothing done yet, so a test only sets what it cares about.
@immutable
final class ReminderInputs {
  const ReminderInputs({
    required this.now,
    this.timeZone = DeviceTimeZone.utc,
    this.switches = ReminderSwitches.defaults,
    this.isWeb = false,
    this.isIos = false,
    this.isSelfHosted = false,
    this.isHosted = true,
    this.quietHours = QuietHours.defaults,
    this.topics = const [],
    this.incidents = const [],
    this.lastTestAt = const {},
    this.lastTestFailedAt,
    this.installedAt,
    this.topicsCreatedHere = const {},
    this.silentTopicNames = const {},
    this.silentDone = const {},
    this.isSignedIn = false,
    this.accountPromptDismissedAt,
    this.plan,
    this.planNoticesSent = const {},
    this.morningAfterDone = const {},
    this.isSetupDone = true,
    this.proShouldAsk = false,
    this.isPaid = false,
    this.proDismissCount = 0,
    this.proLaterAt,
    this.consentAskedAt,
    this.isConsentGiven = false,
    this.reviewAskedAt,
    this.reviewAskCount = 0,
    this.lastAcknowledgedAt,
    this.proAskedAt,
    this.feedbackAskedAt,
    this.appStoreId = '',
    this.feedbackFormUrl = '',
    this.budgetSpentAt,
    this.drillLastIndex,
    this.skipRules = false,
  });

  final DateTime now;
  final DeviceTimeZone timeZone;
  final ReminderSwitches switches;
  final bool isWeb;
  final bool isIos;
  final bool isSelfHosted;

  /// `mode: hosted` from `/v1/info`. Backup and plan heads-up need it.
  final bool isHosted;
  final QuietHours quietHours;
  final List<ReminderTopic> topics;
  final List<ReminderIncident> incidents;

  /// Last successful `POST /v1/test` per topic.
  final Map<String, DateTime> lastTestAt;

  /// Last test that answered 409, 401 or never left the phone.
  final DateTime? lastTestFailedAt;

  /// `HomePromptRepository.getFirstSeenAt()`.
  final DateTime? installedAt;

  /// Topics made on this phone, with when.
  final Map<String, DateTime> topicsCreatedHere;

  /// Topics made here that had zero messages when this pass polled them.
  final Set<String> silentTopicNames;

  /// Topics whose silent topic reminder already fired.
  final Set<String> silentDone;
  final bool isSignedIn;

  /// The home "Back up your topics" card's snooze stamp.
  final DateTime? accountPromptDismissedAt;
  final PlanStatus? plan;

  /// Plan heads-up keys already delivered (`PlanHeadsUpRule.keyFor`).
  final Set<String> planNoticesSent;

  /// Incident ids whose morning after already fired.
  final Set<String> morningAfterDone;

  /// `SetupGate.isDone()` at plan time: onboarding finished and the tour
  /// seen. No ask is planned before both.
  final bool isSetupDone;

  /// `ProPromptRules.shouldAsk()` at plan time.
  final bool proShouldAsk;
  final bool isPaid;
  final int proDismissCount;

  /// `HomePromptRepository.getProPromptLaterAt()`.
  final DateTime? proLaterAt;
  final DateTime? consentAskedAt;
  final bool isConsentGiven;
  final DateTime? reviewAskedAt;
  final int reviewAskCount;
  final DateTime? lastAcknowledgedAt;
  final DateTime? proAskedAt;
  final DateTime? feedbackAskedAt;

  /// `FeedbackLinks.appStoreId`. Blank keeps idea 21 off on iOS.
  final String appStoreId;

  /// `FeedbackLinks.feedbackFormUrl`. Blank keeps idea 22 off.
  final String feedbackFormUrl;

  /// When the weekly slot was last spent.
  final DateTime? budgetSpentAt;

  /// The fire drill line used last time.
  final int? drillLastIndex;

  /// The Reminder lab's "Skip all rules".
  final bool skipRules;
}
