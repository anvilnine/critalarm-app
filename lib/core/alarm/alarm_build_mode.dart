// Off unless asked for. A store build always rings at full volume for as long
// as the server says, because that is the product.
//
// --dart-define=QUIET_ALARM=true skips the volume override and cuts the ring
// short, so testing an alarm on a desk at 2pm does not hurt.
const buildUsesQuietAlarm = bool.fromEnvironment('QUIET_ALARM');

/// How long a quiet ring lasts before it stops on its own.
const quietAlarmSeconds = 5;
