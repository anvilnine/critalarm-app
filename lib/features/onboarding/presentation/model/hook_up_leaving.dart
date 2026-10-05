/// The two ways out of the hook-up step, and the rule that only one of
/// them ever runs.
///
/// - [done]: the Done button. Finishes the step and opens what comes next.
/// - [alarm]: the user's own message set off an alarm and the phone is
///   ringing. The row gets [wait] to turn, then the step is finished and
///   the alarm screen opens, where the stop control is. The alarm screen
///   leaves for Home, never back to this step, so the step has to be
///   finished first.
///
/// Whichever is asked for first wins. Done tapped while the alarm is on
/// its way does nothing: the alarm screen is about to take over.
///
/// The screen hands in what each move does, so the rule tests without a
/// widget.
class HookUpLeaving {
  HookUpLeaving({
    required this.finishAndGoNext,
    required this.finishStep,
    required this.openAlarm,
    required this.wait,
    required this.isStillHere,
    this.forgetFirstTool,
  });

  /// Finishes the step and navigates to whatever follows it.
  final void Function() finishAndGoNext;

  /// Finishes the step and navigates nowhere.
  final Future<void> Function() finishStep;
  final void Function(String incidentId) openAlarm;

  /// The moment the row gets to show that the message arrived.
  final Future<void> Function() wait;

  /// False once something else has already taken the user off this step,
  /// such as a tap on the alarm's notification.
  final bool Function() isStillHere;

  /// Drops the record of the alarm this step heard. Done is the user
  /// ending setup themselves, so an alarm that rings around that moment is
  /// not owed the setup acknowledged screen. Null in tests that do not
  /// look at it.
  final void Function()? forgetFirstTool;

  bool _hasLeft = false;
  bool _leftByDone = false;

  /// Whether a way out has been taken.
  bool get hasLeft => _hasLeft;

  void done() {
    if (_hasLeft) return;
    _hasLeft = true;
    _leftByDone = true;
    forgetFirstTool?.call();
    finishAndGoNext();
  }

  Future<void> alarm(String incidentId) async {
    if (_hasLeft) {
      // Done won. The cubit recorded this alarm a moment ago: take it
      // back. A second alarm after the first one took over changes
      // nothing: that record is in use.
      if (_leftByDone) forgetFirstTool?.call();
      return;
    }
    _hasLeft = true;
    await wait();
    // The message arrived either way, so the step is over. Only the move
    // to the alarm screen depends on the user still being here.
    final isHere = isStillHere();
    await finishStep();
    if (isHere) openAlarm(incidentId);
  }
}
