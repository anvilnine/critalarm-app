/// The one list of languages the app ships, as BCP 47 tags.
///
/// The Flutter app (`app_locales.dart`), the native string generator
/// (`tool/l10n_native.dart`) and the Language screen all read this list. Add a
/// tag here only once `assets/translations/<tag>.json` exists, then run
/// `make l10n` so the iOS and Android string files follow.
///
/// The debug pseudo-locale `en-XA` is never listed here. It is added in debug
/// builds only, and the native code fakes it at run time.
///
/// Pure Dart, no Flutter import, so command line tools can read it.
const List<String> shippedLocaleTags = ['en', 'de', 'ja'];

/// The debug pseudo-locale's tag (`make l10n-pseudo`).
const String pseudoLocaleTag = 'en-XA';
