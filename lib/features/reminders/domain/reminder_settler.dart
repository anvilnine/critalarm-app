import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/reminders/domain/planned_record.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';

/// Books the reminders whose fire time has passed. The platform never says
/// whether a notification showed, so a passed fire time counts as
/// delivered. Safe to run more than once: each record is settled and then
/// dropped, and each ask key is cleared after it is counted.
final class ReminderSettler {
  ReminderSettler({
    required ReminderStore store,
    required HomePromptRepository prompts,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _store = store,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _prompts = prompts;

  final ReminderStore _store;
  final HomePromptRepository _prompts;

  /// Ideas 21 and 22. Runs at the start of every plan pass and at the start
  /// of `HomeAskRules.next()`, so a delivered review ask counts as one of
  /// the 3 before the home popup can ask again.
  Future<void> settleAsks({required DateTime now}) async {
    final review = _store.readReviewFireAt();
    if (review != null && !review.isAfter(now)) {
      await _prompts.markReviewAsked(at: review);
      await _store.writeReviewFireAt(null);
    }
    final feedback = _store.readFeedbackFireAt();
    if (feedback != null && !feedback.isAfter(now)) {
      await _prompts.markFeedbackAsked(at: feedback);
      await _store.writeFeedbackFireAt(null);
    }
  }

  /// Everything a plan pass settles before it plans again.
  Future<void> settleAll({required DateTime now}) async {
    await settleAsks(now: now);

    if (await _store.takePendingProDismiss()) {
      await _prompts.markProPromptAsked();
      await _prompts.dismissProPrompt();
    }

    final left = <PlannedRecord>[];
    var spent = _store.readBudgetSpentAt();
    for (final record in _store.readPlanned()) {
      if (record.fireAt.isAfter(now)) {
        left.add(record);
        continue;
      }
      if (record.kind.usesBudget &&
          (spent == null || record.fireAt.isAfter(spent))) {
        spent = record.fireAt;
      }
      await _settle(record);
    }
    if (spent != null) await _store.writeBudgetSpentAt(spent);
    await _store.writePlanned(left);
  }

  Future<void> _settle(PlannedRecord record) async {
    final key = record.dedupeKey;
    switch (record.kind) {
      case ReminderKind.fireDrill:
        final pool = record.poolIndex;
        if (pool != null) await _store.writeDrillLastIndex(pool);
      case ReminderKind.silentTopic:
        if (key != null) await _store.addSilentDone(key);
      case ReminderKind.backup:
        await _prompts.dismissAccountPrompt();
      case ReminderKind.planHeadsUp:
        if (key != null) await _store.addPlanNoticeSent(key);
      case ReminderKind.morningAfter:
        if (key != null) await _store.addMorningAfterDone(key);
      case ReminderKind.proLater:
        await _prompts.clearProPromptLater();
      case ReminderKind.reviewAsk:
      case ReminderKind.feedbackAsk:
        // Counted through their own keys in settleAsks.
        break;
    }
  }
}
