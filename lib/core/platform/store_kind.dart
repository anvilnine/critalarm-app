import 'package:flutter/foundation.dart' show TargetPlatform;

/// The store this build is made for.
///
/// An Android build names it with `--dart-define=STORE=play|galaxy|huawei`,
/// next to the matching `--flavor`. The Makefile passes both. It is read once,
/// in `lib/app/di.dart`, and registered in `get_it`, like
/// `PlatformCapabilities`. Nothing reads it yet. The store seams that read it
/// come with their own tasks.
enum StoreKind {
  /// Google Play. Every Android build without the define.
  play,

  /// Samsung Galaxy Store.
  galaxy,

  /// Huawei AppGallery, on phones with no Google services.
  huawei,

  /// The App Store. Every iPhone and Mac build without the define.
  apple;

  /// The store for [define], the raw `STORE` value.
  ///
  /// An empty define falls back on the platform, so `flutter run` on an
  /// iPhone needs no define. Android, the web build and anything else fall
  /// back on [play]. A value that names no store is a mistake in a build
  /// command: it throws, so the build that carries it never starts quietly as
  /// the wrong store.
  static StoreKind resolve({
    required String define,
    required TargetPlatform platform,
  }) {
    final value = define.trim().toLowerCase();
    if (value.isEmpty) {
      return switch (platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => apple,
        _ => play,
      };
    }
    for (final store in values) {
      if (store.name == value) return store;
    }
    throw ArgumentError.value(
      define,
      'STORE',
      'names no store. Use one of ${values.map((s) => s.name).join(', ')}',
    );
  }
}
