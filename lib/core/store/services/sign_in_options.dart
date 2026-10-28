/// A way to sign in that a build can offer.
enum SignInProvider { apple, google }

/// Which sign-in providers this store's build shows, in the order it shows
/// them.
abstract interface class SignInOptions {
  List<SignInProvider> get providers;
}

/// [SignInOptions] as a fixed list.
final class FixedSignInOptions implements SignInOptions {
  const FixedSignInOptions(this.providers);

  @override
  final List<SignInProvider> providers;
}
