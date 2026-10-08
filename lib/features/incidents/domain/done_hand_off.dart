import 'package:critalarm/core/failures/failure.dart';

/// Whether a load failed because the server gave no answer: the phone is
/// offline, the request timed out, or the server said to come back later
/// (408, 429, 5xx).
///
/// Any other answer is the server speaking, and what it said stands: a 404
/// or a 401 is never "no answer".
///
/// This is the one thing Dart decides on the way to handing a close back to
/// native. It says nothing about whether an incident is ringing or
/// acknowledged. Native said that, by drawing the Done button the link came
/// from.
bool serverGaveNoAnswer(Failure failure) => switch (failure) {
  UnexpectedFailure() => true,
  ApiFailure(:final statusCode) =>
    statusCode == 408 || statusCode == 429 || statusCode >= 500,
  _ => false,
};
