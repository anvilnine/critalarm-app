/// Owns easy_localization persistence and waits until translations are ready.
/// The app supplies the context-bound implementation; unit tests use a fake.
abstract interface class LanguageLocaleHost {
  String? get savedTag;
  String get currentTag;

  /// Null resets to the current phone language and deletes the saved choice.
  Future<void> apply(String? tag);
}
