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

  /// What a Reliability link opens.
  static const String reliabilityTarget = reliability;

  /// Names that are a screen of their own under `/topics/`, so they cannot
  /// also be a topic there: `/topics/new` is the create-topic form. A link
  /// from outside the app must never open one of these by naming a topic.
  ///
  /// This has to match the router. `test/app/router_test.dart` reads the
  /// router's fixed `/topics/<word>` routes and fails when the two differ.
  static const Set<String> reservedTopicNames = {'new'};

  /// The same for `/incidents/`. The router has none today.
  static const Set<String> reservedIncidentIds = {};

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
///
/// The https form is the strict one, because anyone can write such a link:
///
/// - A connect link carries its server address and token after the `#` only.
///   One that has either in the query is refused, because a query reaches
///   the web server and its logs.
/// - A name that is a fixed screen under `/topics/` or `/incidents/`
///   ([AppLinkRoutes.reservedTopicNames]) opens Home, never that screen.
/// - A path with an empty segment (`//open/...`) or a user name in front of
///   the host opens Home.
///
/// `critalarm://topics/<name>` and `critalarm://incidents/<id>` are what
/// widgets and notifications inside the app use, and they keep the lenient
/// reading they always had.
AppLink? parseAppLink(Uri uri) {
  try {
    if (uri.scheme == 'https') {
      if (uri.host != appLinkHost) return null;
      if (uri.hasPort && uri.port != 443) return null;
      if (uri.userInfo.isNotEmpty) return AppLinkRoute.home;
      final segments = uri.pathSegments.toList();
      // One trailing slash is fine. Any other empty segment is not a path
      // the site has.
      if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
      if (segments.any((s) => s.isEmpty)) return AppLinkRoute.home;
      // Only /connect and /open/ are the app's. The rest of the site stays
      // in the browser, and one that reaches the app anyway opens Home.
      if (segments.isEmpty) return AppLinkRoute.home;
      if (segments.first == _connect) {
        return _connectFrom(uri, segments, fragmentOnly: true);
      }
      if (segments.first == _open) {
        return _routeFrom(segments.sublist(1), strict: true);
      }
      return AppLinkRoute.home;
    }
    if (uri.scheme == appLinkScheme) {
      final segments = _nonEmpty([uri.host, ...uri.pathSegments]);
      if (segments.isEmpty) return AppLinkRoute.home;
      if (segments.first == _connect) {
        return _connectFrom(uri, segments, fragmentOnly: false);
      }
      if (segments.first == _open) {
        return _routeFrom(segments.sublist(1), strict: true);
      }
      return _routeFrom(segments, strict: false);
    }
    return null;
  } on FormatException {
    return AppLinkRoute.home;
  }
}

/// [parseAppLink] for a link that arrived as text, which is how the platform
/// hands one over. Text that is not a URI at all is nobody's link.
///
/// A `.` or `..` segment is refused here, on the text as it was written:
/// [Uri] folds those away while it parses, so `/open/../connect` would
/// otherwise read as `/connect`.
AppLink? parseAppLinkText(String text) {
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  final link = parseAppLink(uri);
  if (link == null) return null;
  final end = text.indexOf(RegExp('[?#]'));
  final beforeQuery = end < 0 ? text : text.substring(0, end);
  return _dotSegment.hasMatch(beforeQuery) ? AppLinkRoute.home : link;
}

/// A `.` or `..` path segment, plain or percent-encoded.
final _dotSegment = RegExp(r'/(\.|%2e){1,2}(/|$)', caseSensitive: false);

final _brokenEscape = RegExp('%(?![0-9A-Fa-f]{2})');

const _connect = 'connect';
const _open = 'open';

List<String> _nonEmpty(Iterable<String> segments) => [
  for (final s in segments)
    if (s.isNotEmpty) s,
];

/// [strict] is for a link from outside the app (`/open/...`): a name that is
/// a fixed screen of the router opens Home.
AppLinkRoute _routeFrom(List<String> segments, {required bool strict}) {
  if (segments.length == 2) {
    final [kind, value] = segments;
    if (kind == 'settings' && value == 'reliability') {
      return const AppLinkRoute(AppLinkRoutes.reliabilityTarget);
    }
    if (kind == 'incidents') {
      if (strict && AppLinkRoutes.reservedIncidentIds.contains(value)) {
        return AppLinkRoute.home;
      }
      return AppLinkRoute(AppLinkRoutes.incident(value));
    }
    if (kind == 'topics') {
      if (strict && AppLinkRoutes.reservedTopicNames.contains(value)) {
        return AppLinkRoute.home;
      }
      return AppLinkRoute(AppLinkRoutes.topic(value));
    }
  }
  return AppLinkRoute.home;
}

/// A connect link, or Home when it is not a usable one. A refused link says
/// nothing about why.
///
/// [fragmentOnly] is the https form. A browser never sends what follows the
/// `#` to a server, so that is the only place such a link may carry the
/// address and the token. `critalarm://` never reaches a server, so it may
/// use the query, and the fragment is read first there too.
AppLink _connectFrom(
  Uri uri,
  List<String> segments, {
  required bool fragmentOnly,
}) {
  if (segments.length != 1) return AppLinkRoute.home;
  // A broken percent escape is refused here, before anything decodes it.
  if (_brokenEscape.hasMatch(uri.fragment) ||
      _brokenEscape.hasMatch(uri.query)) {
    return AppLinkRoute.home;
  }
  final fragment = uri.fragment.isEmpty
      ? const <String, String>{}
      : Uri.splitQueryString(uri.fragment);
  final query = uri.queryParameters;
  if (fragmentOnly &&
      (query.containsKey('url') || query.containsKey('token'))) {
    return AppLinkRoute.home;
  }
  final rawUrl = _firstFilled(
    fragment['url'],
    fragmentOnly ? null : query['url'],
  );
  final token = _firstFilled(
    fragment['token'],
    fragmentOnly ? null : query['token'],
  );
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
/// `http` only to this device or a private network. An address with a user
/// name or password in it is refused: the host a person reads would not be
/// the whole story.
bool isAllowedServerUrl(Uri url) {
  if (url.host.isEmpty) return false;
  if (url.userInfo.isNotEmpty) return false;
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
