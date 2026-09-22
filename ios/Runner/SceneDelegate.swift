import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// A cold start. A file shared from Voice Memos or Files arrives here when
  /// the app was not running.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    IncomingAudioInbox.receive(connectionOptions.urlContexts)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  /// A warm open: the app was already running when the file was shared.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    IncomingAudioInbox.receive(URLContexts)
    super.scene(scene, openURLContexts: URLContexts)
  }
}

/// "Share to Crit Alarm" on iOS.
///
/// iOS copies a shared file into `Documents/Inbox` and hands over its URL.
/// That copy is not ours to keep, so it is copied again into
/// `Caches/incoming_audio`, which the Dart side can read and the cropper
/// deletes from when it closes, and `Documents/Inbox` is emptied.
///
/// The copy is held for `takeIncomingAudio` and also sent live as
/// `incomingAudio` on the sound channel. Dart may get it both ways; each share
/// has its own path, which is what Dart goes by to open it once.
enum IncomingAudioInbox {
  /// Set when the sound channel is wired up.
  static var channel: FlutterMethodChannel?

  /// Read and written on the main thread only.
  private static var pending: [String: Any]?

  private static let queue = DispatchQueue(
    label: "app.critalarm.sound.incoming", qos: .userInitiated
  )

  /// Takes the held file, once.
  static func take() -> [String: Any]? {
    let held = pending
    pending = nil
    return held
  }

  /// Process launch only: drops copies nobody opened last time. Not on a
  /// scene connect, which can happen while a cropper still reads a copy. The
  /// Inbox is left alone here, because on a cold start it holds the file that
  /// is about to be copied; it is emptied after every copy instead.
  static func startFresh() {
    queue.async {
      if let folder = cacheFolder { try? FileManager.default.removeItem(at: folder) }
    }
  }

  static func receive(_ contexts: Set<UIOpenURLContext>) {
    guard let url = contexts.map(\.url).first(where: \.isFileURL) else { return }
    queue.async {
      let copied = copy(url)
      clearInbox()
      DispatchQueue.main.async {
        pending = copied
        channel?.invokeMethod("incomingAudio", arguments: copied)
      }
    }
  }

  private static var cacheFolder: URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("incoming_audio", isDirectory: true)
  }

  /// Copies [url] into the cache. A copy that fails still goes to Dart, with
  /// size 0, so the user is told the file could not be opened.
  private static func copy(_ url: URL) -> [String: Any] {
    let name = url.lastPathComponent
    let fm = FileManager.default
    guard let folder = cacheFolder else {
      return ["path": url.path, "name": name, "size_bytes": 0]
    }
    let target = folder.appendingPathComponent("\(UUID().uuidString)_\(name)")
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      try fm.createDirectory(at: folder, withIntermediateDirectories: true)
      try fm.copyItem(at: url, to: target)
      let size = (try? fm.attributesOfItem(atPath: target.path)[.size] as? Int) ?? 0
      return ["path": target.path, "name": name, "size_bytes": size]
    } catch {
      NSLog("CritAlarm: incoming_audio_copy_failed %@", error.localizedDescription)
      return ["path": target.path, "name": name, "size_bytes": 0]
    }
  }

  private static func clearInbox() {
    let fm = FileManager.default
    guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return
    }
    let inbox = documents.appendingPathComponent("Inbox", isDirectory: true)
    let items = (try? fm.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
    for item in items { try? fm.removeItem(at: item) }
  }
}
