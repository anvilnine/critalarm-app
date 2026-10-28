import 'package:go_router/go_router.dart';

/// The path of the page on top of [routes], a pushed page included.
///
/// A `push` keeps the router's base uri in go_router, so
/// `currentConfiguration.uri` still names the page underneath while a pushed
/// `/alarm` is on screen. This reads the top match instead. An empty list
/// (before the first route) reads as `/`.
String topPathOf(RouteMatchList routes) {
  if (routes.matches.isEmpty) return '/';
  return routes.last.matchedLocation;
}

/// Whether [path] is the alarm screen: `/alarm` or one incident's.
bool isAlarmPath(String path) =>
    path == '/alarm' || path.startsWith('/incidents/');

/// Whether the page on top of [routes] is the alarm screen, opened with `go`
/// or pushed over another page.
bool alarmIsOnTop(RouteMatchList routes) => isAlarmPath(topPathOf(routes));

/// Whether a setup step at [stepPath] may open the alarm screen itself.
///
/// No when the router has gone somewhere else (a tapped notification `go`es
/// to the alarm), and no when an alarm screen was pushed over the step: a
/// second one would replace it. Any other page pushed over the step (a
/// permission dialog, the cropper, a paywall) does not stop it, since the
/// step may be the only thing that opens the alarm.
bool setupStepMayOpenAlarm(RouteMatchList routes, String stepPath) =>
    routes.uri.path == stepPath && !alarmIsOnTop(routes);
