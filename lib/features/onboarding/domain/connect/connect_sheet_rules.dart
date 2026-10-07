import 'package:flutter/foundation.dart';

/// What stops the connect sheet from opening right now.
enum ConnectSheetBlock {
  /// An alarm has focus. Nothing talks over an alarm.
  alarm,

  /// Setup is not finished and the person is not on the connect step.
  setup,

  /// A sheet, dialog or guide is already up.
  otherSheet,
}

/// What the rule reads about the app at one moment.
@immutable
class ConnectSheetSituation {
  const ConnectSheetSituation({
    required this.setupDone,
    required this.onConnectStep,
    required this.alarmOn,
    required this.sheetUp,
  });

  /// Setup is finished.
  final bool setupDone;

  /// The connect step of setup is the screen on top.
  final bool onConnectStep;

  /// At least one open incident is inside its ring window.
  final bool alarmOn;

  /// A sheet, a dialog or a Feature Guide is up.
  final bool sheetUp;
}

/// Why the sheet cannot open now, or null when it can.
///
/// An alarm comes first, then setup, then another sheet. A link that is held
/// back stays in the holder and is asked about again when the situation
/// changes.
ConnectSheetBlock? connectSheetBlock(ConnectSheetSituation now) {
  if (now.alarmOn) return ConnectSheetBlock.alarm;
  if (!now.setupDone && !now.onConnectStep) return ConnectSheetBlock.setup;
  if (now.sheetUp) return ConnectSheetBlock.otherSheet;
  return null;
}

/// True when the sheet can open now. See [connectSheetBlock].
bool canShowConnectSheetNow(ConnectSheetSituation now) =>
    connectSheetBlock(now) == null;
