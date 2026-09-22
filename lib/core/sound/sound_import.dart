import 'package:flutter/foundation.dart';

/// Rules for bringing in a user's own audio file.
///
/// Pure checks, so the caps can be tested without a file picker or a device.
abstract final class SoundImportLimits {
  /// iOS plays the default sound instead of any notification sound of 30
  /// seconds or more.
  static const Duration iosNotificationLimit = Duration(seconds: 30);

  /// The longest clip the app keeps. On iOS the notification plays the sound,
  /// so it stays half a second under Apple's limit. Android rings through its
  /// own alarm player, and past a minute it stops being an alarm sound.
  static Duration maxClipDuration(TargetPlatform platform) =>
      platform == TargetPlatform.iOS
      ? const Duration(milliseconds: 29500)
      : const Duration(seconds: 60);

  /// True for a sound that iOS will swap for the default when a push arrives.
  static bool tooLongToRing(TargetPlatform platform, Duration duration) =>
      platform == TargetPlatform.iOS && duration >= iosNotificationLimit;

  /// 5 MB, checked on the clip that gets saved. A minute of the saved
  /// format is about 2.6 MB, so this only trips if a platform misbehaves.
  static const int maxBytes = 5 * 1024 * 1024;

  /// 100 MB, checked on the picked file before anything decodes it.
  static const int maxSourceBytes = 100 * 1024 * 1024;

  /// The longest file the cropper opens.
  static const Duration maxSourceDuration = Duration(minutes: 20);

  static const Set<String> _sharedExtensions = {
    'mp3',
    'ogg',
    'oga',
    'm4a',
    'aac',
    'wav',
    'flac',
  };

  /// Extensions this platform can decode. Android has no reader for aiff or
  /// caf. iOS also reads `qta`, which is what Voice Memos saves a layered
  /// recording as.
  static Set<String> readableExtensionsFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS
      ? const {..._sharedExtensions, 'aiff', 'aif', 'caf', 'qta'}
      : _sharedExtensions;
}

/// Why a picked file was turned away. Null means it passed.
enum SoundImportRejection {
  /// Over [SoundImportLimits.maxSourceDuration].
  sourceTooLong,

  /// Over [SoundImportLimits.maxSourceBytes].
  tooLarge,

  /// The file is empty, or nothing could read a length out of it.
  unreadable,

  /// Not an audio file this platform can read.
  unsupportedFormat,
}

/// Checks a picked file before the cropper opens. Cheap: only the name and
/// the size, so a 400 MB video never gets decoded.
SoundImportRejection? checkPickedSound({
  required String fileName,
  required int sizeBytes,
  required TargetPlatform platform,
}) {
  if (sizeBytes <= 0) return SoundImportRejection.unreadable;
  final readable = SoundImportLimits.readableExtensionsFor(platform);
  if (!readable.contains(extensionOf(fileName))) {
    return SoundImportRejection.unsupportedFormat;
  }
  if (sizeBytes > SoundImportLimits.maxSourceBytes) {
    return SoundImportRejection.tooLarge;
  }
  return null;
}

/// Checks the length the platform measured. Zero or less means nothing could
/// decode the file.
SoundImportRejection? checkSourceDuration(Duration duration) {
  if (duration <= Duration.zero) return SoundImportRejection.unreadable;
  if (duration > SoundImportLimits.maxSourceDuration) {
    return SoundImportRejection.sourceTooLong;
  }
  return null;
}

/// Lowercase extension with no dot. Empty when the name has none.
String extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}
