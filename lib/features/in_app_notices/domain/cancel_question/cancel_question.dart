import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_store.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_question_rule.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:flutter/foundation.dart';

/// One question that is due: the end date to show, and the store's instant
/// that makes the local key.
@immutable
final class CancelQuestionDue {
  const CancelQuestionDue({required this.endsAt, required this.endsAtInstant});

  final DateTime endsAt;
  final DateTime endsAtInstant;
}

/// Decides whether Home asks "What made you cancel?", and writes down that it
/// did. The sheet itself is `showCancelQuestionSheet`.
final class CancelQuestion {
  CancelQuestion({required this._store});

  final CancelAnswerStore _store;

  /// What to ask about, or null when nothing is due. It looks at `endsAt` and
  /// not at the sheet, because a person who already saw the "Cloud ends"
  /// sheet is on the pill and still has not been asked. The local key is made
  /// from the store's instant, so without it nothing is due.
  CancelQuestionDue? dueFor(ProEndingView view) {
    final endsAt = view.endsAt;
    final instant = view.endsAtInstant;
    if (endsAt == null || instant == null) return null;
    final isDue = CancelQuestionRule.isDue(
      endsAtInstant: instant,
      askedFor: _store.readAskedFor(),
      hasBillingIssue: view.hasBillingIssue,
    );
    return isDue
        ? CancelQuestionDue(endsAt: endsAt, endsAtInstant: instant)
        : null;
  }

  /// Marks the question asked for [due] and then runs [show]. The mark comes
  /// first, so a swipe, a tap outside, the x and a killed app all count as
  /// asked.
  Future<void> ask(CancelQuestionDue due, Future<void> Function() show) async {
    await _store.writeAskedFor(CancelQuestionRule.keyFor(due.endsAtInstant));
    await show();
  }
}
