// The picture on the connect step: two routes from the user's tool to their
// phone, one through Crit Alarm Cloud and one through their own server. These
// rules say which route is lit, what state it shows, and where the one dot
// that travels along it is.

/// One of the two ways an alert gets from a tool to the phone.
enum ConnectRoute {
  /// Tool, Crit Alarm Cloud, phone.
  cloud,

  /// Tool, the user's own server, phone.
  ownServer,
}

/// What the lit route shows.
enum ConnectRouteStatus {
  /// Nothing is connecting. The dot travels to show the way.
  waiting,

  /// A connect is on its way. The dot keeps travelling.
  connecting,

  /// The server answered. The whole route is drawn connected, with no dot.
  connected,

  /// The server did not answer. The route stops at the server, with no dot.
  broken,
}

/// Which route is lit and what it shows.
typedef ConnectRoutesView = ({ConnectRoute lit, ConnectRouteStatus status});

/// The picture for a connect screen in this state.
///
/// The Cloud route is lit until the user opens the form for their own
/// server, because Cloud is the default action. A connect that landed wins
/// over one that is running, and a running one wins over an old failure.
ConnectRoutesView connectRoutesFor({
  required bool isSelfHosting,
  required bool isConnecting,
  required bool isConnected,
  required bool hasFailed,
}) => (
  lit: isSelfHosting ? ConnectRoute.ownServer : ConnectRoute.cloud,
  status: isConnected
      ? ConnectRouteStatus.connected
      : isConnecting
      ? ConnectRouteStatus.connecting
      : hasFailed
      ? ConnectRouteStatus.broken
      : ConnectRouteStatus.waiting,
);

/// Whether the dot travels in [status]. A connected or broken route is drawn
/// still.
bool connectRouteHasDot(ConnectRouteStatus status) =>
    status == ConnectRouteStatus.waiting ||
    status == ConnectRouteStatus.connecting;

/// How long the dot takes from the tool to the phone, in seconds.
const double routeDotTravelTakes = 1.6;

/// How long the dot is away between two runs.
const double routeDotRests = 0.9;

/// How long the first run takes right after the user chose a server. Short,
/// so the dot reaches the phone before the screen moves on.
const double routeDotChosenRunTakes = 0.4;

/// Where the dot is [seconds] after its route was lit: 0 at the tool, 1 at
/// the phone, and null while it is away between two runs. The first run
/// takes [firstRunTakes] and every later one [routeDotTravelTakes].
double? routeDotProgressAt(
  double seconds, {
  double firstRunTakes = routeDotTravelTakes,
}) {
  if (seconds < 0) return null;
  if (seconds <= firstRunTakes) return seconds / firstRunTakes;
  const lap = routeDotRests + routeDotTravelTakes;
  final into = (seconds - firstRunTakes) % lap;
  return into < routeDotRests
      ? null
      : (into - routeDotRests) / routeDotTravelTakes;
}

/// Whether the dot's first run reached the phone while the clock moved from
/// [a] to [b]. That is the one moment the phone answers with a light tap.
bool routeDotFirstArrivedBetween(
  double a,
  double b, {
  double firstRunTakes = routeDotTravelTakes,
}) => a < firstRunTakes && b >= firstRunTakes;
