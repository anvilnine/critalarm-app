/// Links that open the app from outside: `https://critalarm.app/...` and the
/// `critalarm://` form of the same routes.
///
/// [parseAppLink] is the only place a link becomes something the app acts on.
/// It answers from a fixed list. A link on the host that is not on the list
/// opens Home, and a link that is not the app's at all gives nothing.
library;

import 'package:flutter/foundation.dart';

/// The locations a link can open.
abstract final class AppLinkRoutes {
  static const home = '/';
  static const settings = '/settings';

  /// The Reliability screen.
  static const reliability = '/settings/reliability';

  /// What a Reliability link opens today. The router has no
  /// [reliability] route yet, so the link lands on Settings. Point this at
  /// [reliability] when the route exists.
  static const String reliabilityTarget = settings;

  static String incident(String id) => '/incidents/${Uri.encodeComponent(id)}';

  static String topic(String name) => '/topics/${Uri.encodeComponent(name)}';
}

/// The one host whose https links belong to the app.
const appLinkHost = 'critalarm.app';

/// The custom scheme. Widgets and tapped notifications use it too.
const appLinkScheme = 'critalarm';

/// What a link asks for.
sealed class AppLink {
  const AppLink();
}

/// A link that opens a screen.
@immutable
final class AppLinkRoute extends AppLink {
  const AppLinkRoute(this.location);

  static const home = AppLinkRoute(AppLinkRoutes.home);

  /// A go_router location from [AppLinkRoutes].
  final String location;

  @override
  bool operator ==(Object other) =>
      other is AppLinkRoute && other.location == location;

  @override
  int get hashCode => location.hashCode;

  @override
  String toString() => 'AppLinkRoute($location)';
}

/// A link that offers a server to connect to.
///
/// The token is a secret. It lives in memory only: never in a route, a log,
/// a preference or an analytics event. [toString] leaves it out, and so does
/// everything that prints this object.
@immutable
final class ConnectLink extends AppLink {
  const ConnectLink({required this.serverUrl, required this.token});

  final Uri serverUrl;
  final String token;

  @override
  bool operator ==(Object other) =>
      other is ConnectLink &&
      other.serverUrl == serverUrl &&
      other.token == token;

  @override
  int get hashCode => Object.hash(serverUrl, token);

  @override
  String toString() => 'ConnectLink(host: ${serverUrl.host}, token: hidden)';
}

/// Turns [uri] into a typed link.
///
/// Null when the link is not the app's: another scheme, another host, another
/// port. Everything on the host or the scheme gets an answer, and the answer
/// for a path that is not listed is Home.
///
/// | Link | Result |
/// |---|---|
/// | `/connect#url=..&token=..` | [ConnectLink] |
/// | `/open/settings/reliability` | [AppLinkRoutes.reliabilityTarget] |
/// | `/open/incidents/<id>` | that incident |
/// | `/open/topics/<name>` | that topic |
///
/// The `critalarm://` form drops the host: `critalarm://connect?url=..`,
/// `critalarm://topics/<name>`. `critalarm://open/topics/<name>` works too.
AppLink? parseAppLink(Uri uri) {
  try {
    if (uri.scheme == 'https') {
      if (uri.host != appLinkHost) return null;
      if (uri.hasPort && uri.port != 443) return null;
      final segments = _nonEmpty(uri.pathSegments);
      // Only /connect and /open/ are the app's. The rest of the site stays
      // in the browser, and one that reaches the app anyway opens Home.
      if (segments.isEmpty) return AppLinkRoute.home;
      if (segments.first == _connect) return _connectFrom(uri, segments);
      if (segments.first == _open) return _routeFrom(segments.sublist(1));
      return AppLinkRoute.home;
    }
    if (uri.scheme == appLinkScheme) {
      final segments = _nonEmpty([uri.host, ...uri.pathSegments]);
      if (segments.isEmpty) return AppLinkRoute.home;
      if (segments.first == _connect) return _connectFrom(uri, segments);
      if (segments.first == _open) return _routeFrom(segments.sublist(1));
      return _routeFrom(segments);
    }
    return null;
  } on FormatException {
    return AppLinkRoute.home;
  }
}

/// [parseAppLink] for a link that arrived as text. Text that is not a URI at
/// all is nobody's link.
AppLink? parseAppLinkText(String text) {
  final uri = Uri.tryParse(text);
  return uri == null ? null : parseAppLink(uri);
}

final _brokenEscape = RegExp('%(?![0-9A-Fa-f]{2})');

const _connect = 'connect';
const _open = 'open';

List<String> _nonEmpty(Iterable<String> segments) => [
  for (final s in segments)
    if (s.isNotEmpty) s,
];

AppLinkRoute _routeFrom(List<String> segments) {
  if (segments.length == 2) {
    final [kind, value] = segments;
    if (kind == 'settings' && value == 'reliability') {
      return const AppLinkRoute(AppLinkRoutes.reliabilityTarget);
    }
    if (kind == 'incidents') return AppLinkRoute(AppLinkRoutes.incident(value));
    if (kind == 'topics') return AppLinkRoute(AppLinkRoutes.topic(value));
  }
  return AppLinkRoute.home;
}

/// A connect link, or Home when it is not a usable one. A refused link says
/// nothing about why.
AppLink _connectFrom(Uri uri, List<String> segments) {
  if (segments.length != 1) return AppLinkRoute.home;
  // A broken percent escape is refused here, before anything decodes it.
  if (_brokenEscape.hasMatch(uri.fragment) ||
      _brokenEscape.hasMatch(uri.query)) {
    return AppLinkRoute.home;
  }
  // The fragment first: a browser never sends it to a server, so that is
  // where the https link carries the token. The query is for the custom
  // scheme, and for a link whose fragment was lost on the way.
  final fragment = uri.fragment.isEmpty
      ? const <String, String>{}
      : Uri.splitQueryString(uri.fragment);
  final query = uri.queryParameters;
  final rawUrl = _firstFilled(fragment['url'], query['url']);
  final token = _firstFilled(fragment['token'], query['token']);
  if (rawUrl == null || token == null) return AppLinkRoute.home;
  final serverUrl = Uri.tryParse(rawUrl.trim());
  if (serverUrl == null || !isAllowedServerUrl(serverUrl)) {
    return AppLinkRoute.home;
  }
  return ConnectLink(serverUrl: serverUrl, token: token);
}

String? _firstFilled(String? first, String? second) {
  if (first != null && first.trim().isNotEmpty) return first;
  if (second != null && second.trim().isNotEmpty) return second;
  return null;
}

/// True for a server address a connect link may carry: `https` to anywhere,
/// `http` only to this device or a private network.
bool isAllowedServerUrl(Uri url) {
  if (url.host.isEmpty) return false;
  if (url.scheme == 'https') return true;
  if (url.scheme == 'http') return isPrivateOrLoopbackHost(url.host);
  return false;
}

/// True for `localhost` and for an IP address that is loopback, private or
/// link-local. A name is never private, whatever it resolves to: the check
/// reads the text and asks no resolver.
bool isPrivateOrLoopbackHost(String host) {
  final name = host.toLowerCase();
  if (name == 'localhost') return true;
  final v4 = _tryParse(() => Uri.parseIPv4Address(name));
  if (v4 != null) return _isPrivateV4(v4);
  final v6 = _tryParse(() => Uri.parseIPv6Address(name));
  if (v6 == null) return false;
  // An IPv4 address written as IPv6, `::ffff:192.168.1.5`.
  final mapped =
      v6.take(10).every((b) => b == 0) && v6[10] == 0xff && v6[11] == 0xff;
  if (mapped) return _isPrivateV4(v6.sublist(12));
  final loopback = v6.take(15).every((b) => b == 0) && v6[15] == 1;
  final uniqueLocal = (v6[0] & 0xfe) == 0xfc;
  final linkLocal = v6[0] == 0xfe && (v6[1] & 0xc0) == 0x80;
  return loopback || uniqueLocal || linkLocal;
}

bool _isPrivateV4(List<int> ip) {
  final [a, b, _, _] = ip;
  return a == 127 ||
      a == 10 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 169 && b == 254);
}

List<int>? _tryParse(List<int> Function() parse) {
  try {
    return parse();
  } on FormatException {
    return null;
  }
}
