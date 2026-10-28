import 'package:critalarm/core/models/cancel_reason.dart';

/// Where the cancel question sends its answer. The sheet talks to this and
/// knows nothing about queues, accounts or the network.
abstract interface class CancelAnswerSink {
  /// The chip tap. Goes out at once. Never throws and never waits on
  /// analytics.
  Future<void> sendReason(CancelReason reason);

  /// The optional text, a second send for the same answer: the server keeps
  /// one answer per account in a rolling 30 days and files this under it.
  /// [text] is already cleaned (`cleanCancelText`) and not empty. Never
  /// throws.
  Future<void> sendText(CancelReason reason, String text);
}
