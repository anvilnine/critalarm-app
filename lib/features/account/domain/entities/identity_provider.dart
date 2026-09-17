/// The two ways a person can sign in.
///
/// Apple is offered on iOS only. On Android it needs a browser redirect
/// through a Services ID and a server route to catch Apple's form POST, and
/// the contract has neither, so Android shows Google alone.
enum IdentityProvider {
  apple,
  google;

  /// What `POST /api/auth/sign-in/social` expects in `provider`.
  String get wireValue => name;
}
