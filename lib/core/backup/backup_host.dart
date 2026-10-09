import 'package:flutter/services.dart';

/// Where this install stands against the phone it is running on.
///
/// The names are the ones `InstallMarkerRule.Verdict` answers with in
/// ios/Runner/BackupGuard.swift.
enum InstallMarkerVerdict {
  /// No marker yet: a first launch, or the first launch of a version that
  /// has one.
  first,

  /// The install is where it was.
  same,

  /// The app's preferences came out of a backup of another phone.
  moved,

  /// Not known this launch. Nothing is dropped on a guess.
  unknown;

  static InstallMarkerVerdict fromName(String? name) {
    for (final verdict in values) {
      if (verdict.name == name) return verdict;
    }
    return unknown;
  }
}

/// What the phone's backups do with this app, as far as Dart has to know.
///
/// An iPhone backup carries the app's preferences and files to the next
/// phone. Two things follow from that, and both are here:
///
/// - [installMarker] says whether this install was restored onto another
///   phone, so what named the old phone can be dropped.
/// - [excludeFromBackup] keeps a folder out of every backup.
///
/// Android needs neither. The manifest and the two rules files in
/// `android/app/src/main/res/xml/` leave every file out of a backup and a
/// phone to phone transfer, so nothing is restored there at all.
abstract interface class BackupHost {
  /// Never throws. A phone that cannot answer says
  /// [InstallMarkerVerdict.unknown].
  Future<InstallMarkerVerdict> installMarker();

  /// Makes this phone the marker's home. Called once everything that came
  /// from another phone is dropped. Never throws.
  Future<void> settleInstallMarker();

  /// Keeps the file or folder at [path] out of every backup. A folder takes
  /// what is in it along. Does nothing when there is nothing at [path].
  /// Never throws.
  Future<void> excludeFromBackup(String path);
}

/// For Android, the web and tests: an install that has never moved, and
/// nothing to flag.
final class NoBackupHost implements BackupHost {
  const NoBackupHost();

  @override
  Future<InstallMarkerVerdict> installMarker() async =>
      InstallMarkerVerdict.same;

  @override
  Future<void> settleInstallMarker() async {}

  @override
  Future<void> excludeFromBackup(String path) async {}
}

/// The iPhone: `app.critalarm/backup`, answered by `BackupChannel` in
/// ios/Runner/AppDelegate.swift.
final class ChannelBackupHost implements BackupHost {
  const ChannelBackupHost({
    this.channel = const MethodChannel('app.critalarm/backup'),
  });

  final MethodChannel channel;

  @override
  Future<InstallMarkerVerdict> installMarker() async {
    try {
      return InstallMarkerVerdict.fromName(
        await channel.invokeMethod<String>('installMarker'),
      );
    } on Object catch (_) {
      return InstallMarkerVerdict.unknown;
    }
  }

  @override
  Future<void> settleInstallMarker() async {
    try {
      await channel.invokeMethod<bool>('settleInstallMarker');
    } on Object catch (_) {
      // The next launch reads moved again and drops again, which is safe.
    }
  }

  @override
  Future<void> excludeFromBackup(String path) async {
    if (path.isEmpty) return;
    try {
      await channel.invokeMethod<bool>('excludeFromBackup', {'path': path});
    } on Object catch (_) {
      // Tried again at the next launch and the next save.
    }
  }
}
