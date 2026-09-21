import 'dart:io';

import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// [SoundFilePicker] backed by the `file_selector` plugin.
///
/// `file_selector` only opens the Files picker. `file_picker` also shipped
/// camera and photo library code, which made App Store Connect ask for
/// camera and photo purpose strings the app has no use for.
class PlatformSoundFilePicker implements SoundFilePicker {
  const PlatformSoundFilePicker();

  static XTypeGroup get _audio => XTypeGroup(
    label: 'audio',
    extensions: <String>[
      ...SoundImportLimits.readableExtensionsFor(defaultTargetPlatform),
    ],
    mimeTypes: const <String>['audio/*'],
    // iOS filters by type ID only and throws without one.
    uniformTypeIdentifiers: const <String>['public.audio'],
  );

  @override
  Future<PickedSoundFile?> pickOne() async {
    final file = await openFile(acceptedTypeGroups: [_audio]);
    if (file == null) return null;
    return PickedSoundFile(
      path: file.path,
      name: file.name,
      sizeBytes: await file.length(),
    );
  }

  @override
  Future<void> discard(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone, which is what was wanted.
    }
  }
}
