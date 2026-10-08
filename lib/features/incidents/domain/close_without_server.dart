import 'package:critalarm/core/failures/failure.dart';

/// What a close, or the load in front of it, that the server did not take
/// means for the person who wants the incident closed.
enum ServerRefusal {
  /// There is nothing left to close: the incident already moved on (409)
  /// or is not there at all (404, 410). The card for it goes.
  settled,

  /// The server could not be reached, or asked to be tried later. The
  /// close is written to the ack queue and sent when it can be, the same
  /// queue the Done button on the card uses with no signal.
  queue,

  /// The server answered and said no for a reason a retry will not change,
  /// such as a session that ended. Nothing is queued.
  refused,
}

/// Sorts a failed close or a failed load.
///
/// The Android receiver (`ActionResponseRule.isSettled`) and the queue
/// itself (`AckQueue`) draw the same lines: 404, 409 and 410 are settled,
/// 408, 429 and 5xx are worth another try, and anything that is not an
/// answer at all is a phone with no way to the server.
ServerRefusal serverRefusalFor(Failure failure) => switch (failure) {
  ApiFailure(:final statusCode) => switch (statusCode) {
    404 || 409 || 410 => ServerRefusal.settled,
    408 || 429 => ServerRefusal.queue,
    >= 500 => ServerRefusal.queue,
    _ => ServerRefusal.refused,
  },
  NotFoundFailure() || ConflictFailure() => ServerRefusal.settled,
  // No answer: offline, DNS, a timeout.
  UnexpectedFailure() => ServerRefusal.queue,
  _ => ServerRefusal.refused,
};
