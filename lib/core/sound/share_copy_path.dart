import 'dart:io';

import 'package:path/path.dart' as p;

/// The folder under the app's cache that "Share to Crit Alarm" copies into,
/// on both platforms. Matches `ShareReceiverActivity.FOLDER` on Android and
/// `IncomingAudioInbox.cacheFolder` on iOS.
const shareCopyFolderName = 'incoming_audio';

/// Whether [path] is a shared copy the app may open and then delete.
///
/// The platform sends the path of the copy it made. `IncomingAudio` deletes
/// that path when the file is turned away or the cropper closes, so a path
/// from anywhere else would delete one of the app's own files. On Android the
/// path rides an intent extra that any app can set, which is why this is
/// checked here as well as natively.
///
/// True only for a file directly inside [folder]:
///
/// - The path is absolute and has no `.` or `..` part.
/// - It is a plain file, never a link or a folder.
/// - Its folder, with every link in it resolved, is [folder] resolved the
///   same way. That lets `/var` and `/private/var` name the same place on
///   iOS.
///
/// A path that names nothing is let through when its folder is [folder]: a
/// copy that failed, or a file too large to copy, is still sent so the user
/// hears why. There is nothing there to open or to delete.
Future<bool> isShareCopyPath(String path, {required String folder}) async {
  if (!p.isAbsolute(path) || !p.isAbsolute(folder)) return false;
  if (p.split(path).any((part) => part == '.' || part == '..')) return false;
  final parent = p.dirname(path);
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (p.equals(parent, p.normalize(folder))) return true;
      return p.equals(await _resolved(parent), await _resolved(folder));
    }
    if (type != FileSystemEntityType.file) return false;
    return p.equals(await _resolved(parent), await _resolved(folder));
  } on FileSystemException {
    return false;
  }
}

Future<String> _resolved(String folder) =>
    Directory(folder).resolveSymbolicLinks();
