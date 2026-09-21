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

  /// 5 MB. Large enough for a minute of mp3, small enough that a backup of
  /// app data stays sane.
  static const int maxBytes = 5 * 1024 * 1024;

  /// Extensions both platforms can read without help. Anything else is
  /// handed to the platform to convert first.
  static const Set<String> readableExtensions = {
    'mp3',
    'ogg',
    'oga',
    'm4a',
    'aac',
    'wav',
    'aiff',
    'aif',
    'caf',
    'flac',
  };
}

/// Why an import was turned away. Null means it passed.
enum SoundImportRejection {
  /// Over [SoundImportLimits.maxClipDuration].
  tooLong,

  /// Over [SoundImportLimits.maxBytes].
  tooLarge,

  /// The file is empty, or nothing could read a length out of it.
  unreadable,

  /// Not an audio file either platform knows.
  unsupportedFormat,
}

/// Checks one candidate file against the caps.
///
/// [duration] is what the platform measured. A zero or negative duration
/// means nothing could decode it.
SoundImportRejection? checkSoundImport({
  required String fileName,
  required int sizeBytes,
  required Duration duration,
  required TargetPlatform platform,
}) {
  if (sizeBytes <= 0 || duration <= Duration.zero) {
    return SoundImportRejection.unreadable;
  }
  if (!SoundImportLimits.readableExtensions.contains(extensionOf(fileName))) {
    return SoundImportRejection.unsupportedFormat;
  }
  if (duration > SoundImportLimits.maxClipDuration(platform)) {
    return SoundImportRejection.tooLong;
  }
  if (sizeBytes > SoundImportLimits.maxBytes) {
    return SoundImportRejection.tooLarge;
  }
  return null;
}

/// Lowercase extension with no dot. Empty when the name has none.
String extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}
