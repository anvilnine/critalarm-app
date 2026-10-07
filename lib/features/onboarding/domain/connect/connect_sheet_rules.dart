import 'package:flutter/foundation.dart';

/// What stops the connect sheet from opening right now.
enum ConnectSheetBlock {
  /// An alarm has focus. Nothing talks over an alarm.
  alarm,

  /// A screen that owns the display is on top: the paywall, the alarm, the
  /// lock screen. See [isConnectSheetBlockedPath].
  screen,

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
    this.blockedScreen = false,
  });

  /// Setup is finished.
  final bool setupDone;

  /// The connect step of setup is the screen on top.
  final bool onConnectStep;

  /// At least one open incident is inside its ring window.
  final bool alarmOn;

  /// A sheet, a dialog or a Feature Guide is up.
  final bool sheetUp;

  /// The screen on top is one the sheet never opens over.
  final bool blockedScreen;
}

/// Screens that own the display. A purchase, an alarm and the lock screen
/// each end in one thing the person is doing, and a sheet over them is in
/// the way.
bool isConnectSheetBlockedPath(String path) =>
    _blockedPaths.contains(path) || path.startsWith('/incidents/');

const _blockedPaths = {
  '/paywall',
  '/paywall/success',
  '/alarm',
  '/ring',
  '/lockscreen',
};

/// Why the sheet cannot open now, or null when it can.
///
/// An alarm comes first, then a screen that owns the display, then setup,
/// then another sheet. A link that is held
/// back stays in the holder and is asked about again when the situation
/// changes.
ConnectSheetBlock? connectSheetBlock(ConnectSheetSituation now) {
  if (now.alarmOn) return ConnectSheetBlock.alarm;
  if (now.blockedScreen) return ConnectSheetBlock.screen;
  if (!now.setupDone && !now.onConnectStep) return ConnectSheetBlock.setup;
  if (now.sheetUp) return ConnectSheetBlock.otherSheet;
  return null;
}

/// True when the sheet can open now. See [connectSheetBlock].
bool canShowConnectSheetNow(ConnectSheetSituation now) =>
    connectSheetBlock(now) == null;
