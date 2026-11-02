import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs [action] and swallows anything it throws, so a step that must never
/// surface as an error cannot. In a debug build the swallowed error is
/// printed with [tag], so a failure that used to vanish leaves a line in the
/// console. A release build prints nothing, and nothing leaves the phone.
///
/// Catches [Object], so an [Error] is swallowed too. Use it only where the
/// caller has no use for the failure.
Future<void> quietly(String tag, FutureOr<void> Function() action) async {
  try {
    await action();
  } on Object catch (error) {
    noteQuiet(tag, error);
  }
}

/// Leaves the trace for an error a caller swallows itself, for a `catch`
/// that has to keep its own shape (a `catchError`, a sync block that
/// assigns). Prints in a debug build only.
void noteQuiet(String tag, Object error) {
  if (!kDebugMode) return;
  debugPrint('[quiet] $tag: $error');
}
