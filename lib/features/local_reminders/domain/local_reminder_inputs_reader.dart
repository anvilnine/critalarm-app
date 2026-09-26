import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:flutter/foundation.dart';

/// Reads everything the planner needs, once per plan pass, and turns every
/// instant into wall-clock time in the zone the phone reports right now.
///
/// Runs on the main isolate: `readIsPaid` goes through a Keychain channel.
final class LocalReminderInputsReader {
  LocalReminderInputsReader({
    required LocalReminderStore store,
    required InAppNoticeRepository notices,
    required QuietHoursStore quietHours,
    required LocalReminderScheduler scheduler,
    required PlanStatusSource planStatus,
    required PrivacyRepository privacy,
    required Future<List<Topic>?> Function() readTopics,
    required Future<List<Incident>?> Function() readIncidents,
    required Future<bool> Function(String topic) topicHasMessages,
    required Future<ServerMode?> Function() readServerMode,
    required Future<bool> Function() readIsPaid,
    required Future<bool> Function() readIsSignedIn,
    required Future<bool> Function() proShouldAsk,
    required bool isWeb,
    required bool isIos,
    Future<bool> Function()? isSetupDone,
    String appStoreId = FeedbackLinks.appStoreId,
    String feedbackFormUrl = FeedbackLinks.feedbackFormUrl,
    DateTime Function()? clock,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _store = store,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _notices = notices,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _quietHours = quietHours,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _scheduler = scheduler,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _planStatus = planStatus,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _privacy = privacy,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readTopics = readTopics,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readIncidents = readIncidents,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _topicHasMessages = topicHasMessages,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readServerMode = readServerMode,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readIsPaid = readIsPaid,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readIsSignedIn = readIsSignedIn,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _proShouldAsk = proShouldAsk,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _isSetupDone = isSetupDone,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isWeb = isWeb,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isIos = isIos,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _appStoreId = appStoreId,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _feedbackFormUrl = feedbackFormUrl,
       _clock = clock ?? DateTime.now;

  /// A topic made here more than this long ago is past its silent topic
  /// reminder, so it is not polled any more.
  static const Duration silentLookBack = Duration(days: 7);

  final LocalReminderStore _store;
  final InAppNoticeRepository _notices;
  final QuietHoursStore _quietHours;
  final LocalReminderScheduler _scheduler;
  final PlanStatusSource _planStatus;
  final PrivacyRepository _privacy;
  final Future<List<Topic>?> Function() _readTopics;
  final Future<List<Incident>?> Function() _readIncidents;
  final Future<bool> Function(String topic) _topicHasMessages;
  final Future<ServerMode?> Function() _readServerMode;
  final Future<bool> Function() _readIsPaid;
  final Future<bool> Function() _readIsSignedIn;
  final Future<bool> Function() _proShouldAsk;

  /// `SetupGate.isDone` in the app. Null in tests, and counts as done.
  final Future<bool> Function()? _isSetupDone;
  final bool _isWeb;
  final bool _isIos;
  final String _appStoreId;
  final String _feedbackFormUrl;
  final DateTime Function() _clock;

  /// Null when topics or incidents cannot be read, for example offline.
  /// Without them "no open incident" cannot be checked, so the pass leaves
  /// what is already scheduled alone. With no server connection at all
  /// there are no topics or incidents to read, so both count as empty and
  /// the drills for a removed server get cancelled.
  ///
  /// Every other source that fails falls back to the answer that sends the
  /// fewest reminders.
  Future<LocalReminderInputs?> read() async {
    // Native code (or another isolate) can have written the "Not now" flag
    // or a test time since this preferences file was last loaded.
    await _store.reload();

    final zone = await _scheduler.deviceTimeZone();
    DateTime? wall(DateTime? at) => at == null ? null : zone.toWall(at);

    ServerMode? mode;
    var modeFailed = false;
    try {
      mode = await _readServerMode();
    } on Object catch (error) {
      _log('server mode', error);
      modeFailed = true;
    }
    final isConnected = modeFailed || mode != null;
    final topics = isConnected ? await _readTopics() : const <Topic>[];
    final incidents = isConnected ? await _readIncidents() : const <Incident>[];
    if (topics == null || incidents == null) return null;

    final now = zone.toWall(_clock());
    // An unknown mode counts as self-hosted: no offers and no backup nudge.
    final isSelfHosted = modeFailed || mode == ServerMode.selfhosted;
    final isHosted = mode == ServerMode.hosted;
    final skipRules = _store.readSkipRules();

    final createdHere = {
      for (final entry in _store.readTopicsCreatedHere().entries)
        entry.key: zone.toWall(entry.value),
    };
    final silentDone = _store.readSilentDone();
    final liveNames = {for (final topic in topics) topic.name};
    final silentNames = <String>{};
    for (final entry in createdHere.entries) {
      if (silentDone.contains(entry.key)) continue;
      if (!liveNames.contains(entry.key)) continue;
      if (now.difference(entry.value) > silentLookBack) continue;
      // A failed poll counts as "has messages", so no false silent nudge.
      final hasMessages = await _safe(
        'topic messages',
        () => _topicHasMessages(entry.key),
        fallback: true,
      );
      if (!hasMessages) silentNames.add(entry.key);
    }

    final privacy = await _safe<PrivacySettings?>(
      'privacy settings',
      () async => (await _privacy.getPrivacySettings()).getOrNull(),
      fallback: const PrivacySettings(),
    );

    return LocalReminderInputs(
      now: now,
      timeZone: zone,
      switches: _store.readSwitches(),
      isWeb: _isWeb,
      isIos: _isIos,
      isSelfHosted: isSelfHosted,
      isHosted: isHosted,
      quietHours: _quietHours.read(),
      topics: [
        for (final topic in topics)
          LocalReminderTopic(
            name: topic.name,
            isCritical: topic.critical,
            createdAt: wall(topic.createdAt),
          ),
      ],
      incidents: [
        for (final incident in incidents)
          LocalReminderIncident(
            id: incident.id,
            topic: incident.topic,
            isTest: IncidentKinds.isTest(incident),
            isOpenOrAcked: incident.isOpen || incident.isAcked,
            openedAt: wall(incident.openedAt),
            ackedAt: wall(incident.ackedAt),
          ),
      ],
      lastTestAt: {
        for (final entry in _store.readLastTestAt().entries)
          entry.key: zone.toWall(entry.value),
      },
      lastTestFailedAt: wall(_store.readLastTestFailedAt()),
      // Never null: a fire drill checks "never tested since installedAt",
      // and a null here would let it silently skip a topic it has never
      // seen tested. Fall back to home's first-seen stamp, then to now.
      installedAt: wall(_notices.getFirstSeenAt()) ?? now,
      topicsCreatedHere: createdHere,
      silentTopicNames: silentNames,
      silentDone: silentDone,
      // Failing counts as signed in, so no backup nudge.
      isSignedIn: await _safe('sign-in', _readIsSignedIn, fallback: true),
      accountNoticeDismissedAt: wall(_notices.getAccountNoticeDismissedAt()),
      plan: isHosted ? await _planStatus.read(zone) : null,
      planHeadsUpsSent: _store.readPlanHeadsUpsSent(),
      morningAfterDone: _store.readMorningAfterDone(),
      isSetupDone:
          skipRules || await (_isSetupDone?.call() ?? Future<bool>.value(true)),
      proShouldAsk: skipRules || await _proShouldAsk(),
      // Failing counts as paid, so no Pro ask.
      isPaid: await _safe('paid state', _readIsPaid, fallback: true),
      proDismissCount: _notices.getProAskDismissCount(),
      proLaterAt: wall(_notices.getProAskLaterAt()),
      consentAskedAt: wall(_notices.getConsentAskedAt()),
      isConsentGiven:
          privacy != null &&
          privacy.analyticsEnabled &&
          privacy.crashReportingEnabled,
      reviewAskedAt: wall(_notices.getReviewAskedAt()),
      reviewAskCount: _notices.getReviewAskCount(),
      lastAcknowledgedAt: wall(_notices.getLastAcknowledgedAt()),
      proAskedAt: wall(_notices.getProAskedAt()),
      feedbackAskedAt: wall(_notices.getFeedbackAskedAt()),
      appStoreId: _appStoreId,
      feedbackFormUrl: _feedbackFormUrl,
      budgetSpentAt: wall(_store.readBudgetSpentAt()),
      drillLastIndex: _store.readDrillLastIndex(),
      skipRules: skipRules,
    );
  }

  Future<T> _safe<T>(
    String what,
    Future<T> Function() read, {
    required T fallback,
  }) async {
    try {
      return await read();
    } on Object catch (error) {
      _log(what, error);
      return fallback;
    }
  }

  void _log(String what, Object error) => debugPrint(
    'CritAlarmReminders: reading $what failed: ${error.runtimeType}',
  );
}
