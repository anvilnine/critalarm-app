import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Counts the sheets and dialogs open on the root navigator.
///
/// A sheet or dialog is a [PopupRoute]. Something that wants to open a sheet
/// of its own asks [isUp] first, so two never stack. Screens are not counted.
class PopupRouteTracker extends NavigatorObserver {
  final _open = ValueNotifier<int>(0);

  /// Moves whenever a sheet or dialog opens or closes.
  ValueListenable<int> get changes => _open;

  /// A sheet or dialog is open.
  bool get isUp => _open.value > 0;

  void _add(Route<dynamic>? route, int by) {
    if (route is! PopupRoute) return;
    final next = _open.value + by;
    _open.value = next < 0 ? 0 : next;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _add(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _add(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _add(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _add(oldRoute, -1);
    _add(newRoute, 1);
  }
}

/// The tracker for the app's root router.
final appPopupRoutes = PopupRouteTracker();
