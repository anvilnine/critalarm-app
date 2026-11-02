/// What Google's sign-in sheet handed back.
final class GoogleSheetAnswer {
  const GoogleSheetAnswer({required this.idToken, this.email});

  /// Google's own id token, before our server has seen it.
  final String idToken;
  final String? email;
}

/// The person closed a sign-in sheet without signing in.
final class SignInSheetCancelled implements Exception {
  const SignInSheetCancelled();
}

/// Google's sign-in sheet, as this store's build shows it.
abstract interface class GoogleSignInSheet {
  /// Shows the sheet. Throws [SignInSheetCancelled] when the person backs
  /// out.
  Future<GoogleSheetAnswer> signIn();

  Future<void> signOut();
}
