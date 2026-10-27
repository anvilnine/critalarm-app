/// Asks a server whether it accepts a management credential, before any
/// session names that server.
// ignore: one_member_abstracts
abstract interface class ManagementCredentialProbe {
  /// Completes when the server at [baseUri] accepts [credential] on a read
  /// that changes nothing. Throws an `ApiException` carrying the status
  /// when it does not.
  Future<void> checkManagementCredential(Uri baseUri, String credential);
}
