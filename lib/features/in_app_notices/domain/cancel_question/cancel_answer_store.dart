import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer.dart';

/// What the cancel question keeps on the phone: which end date it asked
/// about, and the sends still waiting for a retry.
abstract interface class CancelAnswerStore {
  /// The key (`CancelQuestionRule.keyFor`) of the end date last asked about.
  String? readAskedFor();
  Future<void> writeAskedFor(String key);

  /// Oldest first. An unreadable list reads as empty.
  List<CancelAnswer> readPending();
  Future<void> writePending(List<CancelAnswer> entries);
}
