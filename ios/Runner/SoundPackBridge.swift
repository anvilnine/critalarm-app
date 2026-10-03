import Foundation
#if canImport(BackgroundAssets) && os(iOS)
import BackgroundAssets
import System
#endif

/// One pack's state as Dart reads it on `app.critalarm/sound_packs`: a word
/// plus how far a download has got. The words match Android's.
struct SoundPackWire: Equatable {
  static let notDownloaded = SoundPackWire(state: "not_downloaded")
  static let downloaded = SoundPackWire(state: "downloaded", progress: 1)
  static let failed = SoundPackWire(state: "failed")
  static let unavailable = SoundPackWire(state: "unavailable")
  static let needsNewerOs = SoundPackWire(state: "needs_newer_os")

  static func downloading(_ progress: Double?) -> SoundPackWire {
    SoundPackWire(state: "downloading", progress: progress.map { min(max($0, 0), 1) })
  }

  let state: String
  var progress: Double?

  var dictionary: [String: Any] {
    var map: [String: Any] = ["state": state]
    if let progress { map["progress"] = progress }
    return map
  }
}

/// What the bridge needs from the store. `AppleSoundPackStore` wraps
/// `AssetPackManager` on iOS 26 and later; the tests hand in a fake.
protocol SoundPackStore: AnyObject {
  /// Where the pack is. Never downloads.
  func state(packID: String) async -> SoundPackWire

  /// Downloads the pack if it is not here, calling [progress] on the way.
  /// Returns once it is on the device, or it failed.
  func download(packID: String, progress: @escaping (Double?) -> Void) async -> SoundPackWire

  /// A file inside a downloaded pack, by its path in the pack. Nil when the
  /// pack is not on the device.
  func fileURL(packID: String, path: String) -> URL?
}

/// The iOS half of the sound packs. Same calls as Android's `SoundPackChannel`:
/// `packState`, `download`, `packPath`, `installPack`, `installedPackSounds`.
///
/// A pack sound in use (by a topic or as the default) is converted into the
/// app group's `Library/Sounds` as `<id>.caf`, the folder and format imported
/// sounds use, so the notification extension plays it by name like any other
/// picked sound. Sounds nobody uses stay in the pack only.
final class SoundPackBridge {
  /// Where a pack keeps its sounds, as the asset pack manifest packages them.
  static let packSoundsFolder = "sounds"
  static let packSoundExtension = "m4a"

  /// Nil below iOS 26, where Apple-hosted packs do not exist.
  private let store: SoundPackStore?
  private let soundsDirectory: () -> URL?
  private let convert: (_ source: URL, _ destination: URL) -> Bool

  init(
    store: SoundPackStore?,
    soundsDirectory: @escaping () -> URL?,
    convert: @escaping (_ source: URL, _ destination: URL) -> Bool
  ) {
    self.store = store
    self.soundsDirectory = soundsDirectory
    self.convert = convert
  }

  /// Ids and pack names come from Dart. Anything that could step out of a
  /// folder is refused before it is used in a path.
  static func isSafeName(_ name: String) -> Bool {
    !name.isEmpty && name.count <= 64 && name.allSatisfy { ch in
      ch == "_" || ("a"..."z").contains(ch) || ("0"..."9").contains(ch)
    }
  }

  static func isPackSound(_ id: String) -> Bool {
    id.hasPrefix(SharedSounds.packSoundPrefix) && isSafeName(id)
  }

  static func pathInPack(soundID: String) -> String {
    "\(packSoundsFolder)/\(soundID).\(packSoundExtension)"
  }

  func packState(_ packID: String) async -> SoundPackWire {
    guard Self.isSafeName(packID) else { return .unavailable }
    guard let store else { return .needsNewerOs }
    return await store.state(packID: packID)
  }

  func download(_ packID: String, progress: @escaping (Double?) -> Void) async -> SoundPackWire {
    guard Self.isSafeName(packID) else { return .unavailable }
    guard let store else { return .needsNewerOs }
    return await store.download(packID: packID, progress: progress)
  }

  /// The folder the pack's sounds sit in, or nil when it is not here.
  func packPath(_ packID: String, anySoundID: String?) -> String? {
    guard let store, Self.isSafeName(packID), let id = anySoundID, Self.isPackSound(id),
          let url = store.fileURL(packID: packID, path: Self.pathInPack(soundID: id))
    else { return nil }
    return url.deletingLastPathComponent().path
  }

  /// The copy the notification plays, in the group's `Library/Sounds`.
  func installedURL(soundID: String) -> URL? {
    soundsDirectory()?.appendingPathComponent(SharedSounds.fileNameFor(soundID: soundID))
  }

  /// The sound's file inside the downloaded pack, or nil.
  private func packFile(_ packID: String, soundID: String) -> URL? {
    guard let url = store?.fileURL(packID: packID, path: Self.pathInPack(soundID: soundID)),
          Self.holdsBytes(url) else { return nil }
    return url
  }

  /// Which of [soundIDs] can be played now, as `{id, path}`: the caf when a
  /// topic or the default uses the sound, else the file in the pack. The
  /// picker previews from either.
  func installed(_ packID: String, _ soundIDs: [String]) -> [[String: String]] {
    soundIDs.compactMap { id in
      guard Self.isPackSound(id) else { return nil }
      if let caf = installedURL(soundID: id), Self.holdsBytes(caf) { return ["id": id, "path": caf.path] }
      guard Self.isSafeName(packID), let file = packFile(packID, soundID: id) else { return nil }
      return ["id": id, "path": file.path]
    }
  }

  /// Nothing is copied when the pack arrives. A 16-bit caf runs about
  /// 96 KB a second, so all 23 would take some 30 MB for a 2.9 MB pack.
  /// [sync] makes a caf only for a sound in use. This reports which
  /// sounds the pack holds.
  func install(_ packID: String, soundIDs: [String]) -> [[String: String]] {
    guard Self.isSafeName(packID) else { return [] }
    return installed(packID, soundIDs)
  }

  /// Brings the group's `Library/Sounds` in line with the choices, around
  /// [publish], in the order that never leaves the extension naming a caf
  /// that is gone:
  ///
  /// 1. with [convertMissing], make the caf for each pack sound in [inUse]
  ///    that has none (a new choice, a failed conversion, a lost file);
  /// 2. [publish] the choices;
  /// 3. delete the caf of every pack sound no choice uses, but only when
  ///    [choicesReadable]: preferences that could not be read must never
  ///    wipe the cafs in use.
  ///
  /// A sound in use whose caf cannot be made (the pack is gone, or this is
  /// before iOS 26) keeps whatever caf it has; with none, the notification
  /// extension rings the default, then classic_siren.
  func sync(
    inUse: Set<String>,
    choicesReadable: Bool,
    convertMissing: Bool,
    publish: () -> Void
  ) {
    let wanted = Set(inUse.filter(Self.isPackSound))
    if convertMissing { makeCopies(wanted) }
    publish()
    if choicesReadable { removeCopies(except: wanted) }
  }

  /// [sync] with nothing to publish, for the tests and callers that publish
  /// elsewhere.
  func syncCopies(inUse: Set<String>, convertMissing: Bool = true) {
    sync(inUse: inUse, choicesReadable: true, convertMissing: convertMissing) {}
  }

  private func makeCopies(_ wanted: Set<String>) {
    guard let directory = soundsDirectory() else { return }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for id in wanted.sorted() {
      let destination = directory.appendingPathComponent(SharedSounds.fileNameFor(soundID: id))
      if Self.holdsBytes(destination) { continue }
      // url(for:) finds a file in any downloaded pack, so no pack id is needed.
      guard let source = store?.fileURL(packID: "", path: Self.pathInPack(soundID: id)) else {
        NSLog("CritAlarmSound: pack_copy_unavailable id=%@", id)
        continue
      }
      // Written beside the real name, then moved, so a half-written caf is
      // never taken for a sound.
      let partial = directory.appendingPathComponent("\(id).partial.caf")
      try? FileManager.default.removeItem(at: partial)
      guard convert(source, partial), Self.holdsBytes(partial) else {
        try? FileManager.default.removeItem(at: partial)
        NSLog("CritAlarmSound: pack_copy_failed id=%@", id)
        continue
      }
      try? FileManager.default.removeItem(at: destination)
      if (try? FileManager.default.moveItem(at: partial, to: destination)) == nil {
        try? FileManager.default.removeItem(at: partial)
      }
    }
  }

  private func removeCopies(except wanted: Set<String>) {
    guard let directory = soundsDirectory() else { return }
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    for name in names where name.hasPrefix(SharedSounds.packSoundPrefix) && name.hasSuffix(".caf") {
      let id = String(name.dropLast(".caf".count))
      if !wanted.contains(id) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        NSLog("CritAlarmSound: pack_copy_removed name=%@", name)
      }
    }
  }

  private static func holdsBytes(_ url: URL) -> Bool {
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    return size > 0
  }
}

#if canImport(BackgroundAssets) && os(iOS)
/// Apple-hosted Managed Background Assets. The downloader extension
/// (`CritAlarmDownloader`) does the downloading; this asks for it and reads
/// the files.
@available(iOS 26.0, *)
final class AppleSoundPackStore: SoundPackStore {
  private let manager = AssetPackManager.shared

  func state(packID: String) async -> SoundPackWire {
    if #available(iOS 26.4, *), manager.assetPackIsAvailableLocally(withID: packID) {
      return .downloaded
    }
    do {
      // The ID-based call is the one iOS 26.0 to 26.3 have. 26.4 renamed it.
      let status = try await manager.status(ofAssetPackWithID: packID)
      return Self.wire(status)
    } catch {
      NSLog("CritAlarmSound: pack_state_failed pack=%@ error=%@", packID, "\(error)")
      return Self.wire(error)
    }
  }

  func download(packID: String, progress: @escaping (Double?) -> Void) async -> SoundPackWire {
    do {
      let pack = try await manager.assetPack(withID: packID)
      // Progress comes from the status stream while the download runs.
      let watcher = Task {
        for await update in manager.statusUpdates(forAssetPackWithID: packID) {
          if case .downloading(_, let fraction) = update { progress(fraction.fractionCompleted) }
          if Task.isCancelled { break }
        }
      }
      defer { watcher.cancel() }
      if #available(iOS 26.4, *) {
        try await manager.ensureLocalAvailability(of: pack, requireLatestVersion: false)
      } else {
        try await manager.ensureLocalAvailability(of: pack)
      }
      NSLog("CritAlarmSound: pack_downloaded pack=%@ bytes=%ld", packID, pack.downloadSize)
      return .downloaded
    } catch {
      NSLog("CritAlarmSound: pack_download_failed pack=%@ error=%@", packID, "\(error)")
      return Self.wire(error)
    }
  }

  /// `url(for:)` throws `fileNotFound` while the pack is not on the device.
  func fileURL(packID: String, path: String) -> URL? {
    try? manager.url(for: FilePath(path))
  }

  static func wire(_ status: AssetPack.Status) -> SoundPackWire {
    if status.contains(.downloaded) { return .downloaded }
    if status.contains(.downloading) { return .downloading(nil) }
    return .notDownloaded
  }

  /// A pack App Store Connect does not have (a build not from TestFlight or
  /// the App Store, or a pack not uploaded yet) can never download here.
  static func wire(_ error: Error) -> SoundPackWire {
    if case ManagedBackgroundAssetsError.assetPackNotFound = error { return .unavailable }
    return .failed
  }
}
#endif
