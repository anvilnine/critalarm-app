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
