import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_rule.dart';

/// Puts the default icon back when Pro has ended.
///
/// Runs on every resume and whenever the plan changes. It only ever switches
/// a Pro icon back to the default, never the other way, and only once Pro is
/// really gone: `readUnlocked` should answer true whenever it is unsure, since
/// a wrong switch on iOS costs the user a system alert and their chosen icon.
class AppIconGuard {
  AppIconGuard({
    required this._readCurrent,
    required this._apply,
    required this._readUnlocked,
  });

  final Future<AppIcon?> Function() _readCurrent;
  final Future<bool> Function(AppIcon icon) _apply;
  final Future<bool> Function() _readUnlocked;

  bool _running = false;

  /// Switches back to the default icon if the one showing is no longer
  /// allowed. Returns the icon it switched to, or null when nothing changed.
  Future<AppIcon?> check() async {
    // A resume and a plan change can land together. One check is enough.
    if (_running) return null;
    _running = true;
    try {
      final current = await _readCurrent();
      // Nothing to guard on a platform with no icon to change, and nothing to
      // ask the plan about while the default icon is showing.
      if (current == null || !current.isPro) return null;

      final bool unlocked;
      try {
        unlocked = await _readUnlocked();
      } on Object catch (_) {
        return null;
      }
      final target = AppIconRule.revertTo(current, unlocked: unlocked);
      if (target == null) return null;
      return await _apply(target) ? target : null;
    } finally {
      _running = false;
    }
  }
}
