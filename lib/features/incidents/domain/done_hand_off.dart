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
///
/// The repositories turn every exception into [UnexpectedFailure] with the
/// exception's text and nothing else, so "the phone is offline" and "the
/// answer could not be read" arrive as the same type. An answer that came
/// back and did not parse is told apart by the one thing left, its text.
/// Telling the two apart by type needs a network variant on [Failure].
bool serverGaveNoAnswer(Failure failure) => switch (failure) {
  UnexpectedFailure(:final message) => !_isUnreadableAnswer(message),
  ApiFailure(:final statusCode) =>
    statusCode == 408 || statusCode == 429 || statusCode >= 500,
  _ => false,
};

/// An exception text that says a response arrived and could not be read.
bool _isUnreadableAnswer(String? message) =>
    message != null &&
    (message.contains('FormatException') ||
        message.contains('is not a subtype of'));
