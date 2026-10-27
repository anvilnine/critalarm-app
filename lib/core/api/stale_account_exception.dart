/// A request for incidents or messages was answered after the phone moved to
/// another account.
///
/// The answer belongs to the account that asked. Nothing may draw it, store
/// it or act on it for the account the phone is on now, so every caller
/// treats this as "nothing happened". It is not a server failure and not
/// worth a retry.
final class StaleAccountException implements Exception {
  const StaleAccountException();

  @override
  String toString() => 'StaleAccountException';
}
