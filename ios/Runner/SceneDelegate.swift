import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// A cold start. A file shared from Voice Memos or Files arrives here when
  /// the app was not running, and so does a link that started the app.
  ///
  /// The connection options cannot be changed, so Flutter still sees a link
  /// that is in them. With Flutter's deep linking off it reads no URL out of
  /// them, and of the plugins here only two look at the options: one for the
  /// tapped notification, one for the quick action.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    IncomingAudioInbox.receive(connectionOptions.urlContexts)
    openLinks(connectionOptions.urlContexts)
    for activity in connectionOptions.userActivities { openUniversalLink(activity) }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    forgetLinkActivity(on: scene)
  }

  /// A warm open: the app was already running when the file was shared.
  ///
  /// An app link stops here. Flutter would hand the URL to every plugin, and
  /// a connect link carries a token. Files and widget links go on as before.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    IncomingAudioInbox.receive(URLContexts)
    let taken = openLinks(URLContexts)
    let rest = URLContexts.subtracting(taken)
    if !rest.isEmpty { super.scene(scene, openURLContexts: rest) }
  }

  /// A warm open from an `https://critalarm.app` universal link.
  ///
  /// The activity holds the whole link, token included, so one this app took
  /// is not passed on to Flutter and its plugins, and is not left on the
  /// scene, where state restoration would save it.
  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if openUniversalLink(userActivity) {
      forgetLinkActivity(on: scene)
      return
    }
    super.scene(scene, continue: userActivity)
  }

  /// iOS asks for this when it saves the scene. Flutter starts from
  /// `scene.userActivity` when there is one, so a link must not be on it.
  override func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    forgetLinkActivity(on: scene)
    return super.stateRestorationActivity(for: scene)
  }

  /// A `critalarm://` link. One from a widget becomes a tap as before. One
  /// that is the custom-scheme form of an app link goes to Dart whole. Files
  /// keep going to the inbox above. Returns the contexts that were app links.
  @discardableResult
  private func openLinks(_ contexts: Set<UIOpenURLContext>) -> Set<UIOpenURLContext> {
    let links = contexts.filter { !$0.url.isFileURL && $0.url.scheme == WidgetLink.scheme }
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return [] }
    var taken: Set<UIOpenURLContext> = []
    for context in links {
      let url = context.url
      if WidgetLink.tap(from: url) == nil, let tap = AppLinkRule.tap(from: url) {
        app.openAppLink(tap)
        taken.insert(context)
      } else {
        app.openWidgetLink(url)
      }
    }
    return taken
  }

  /// Flutter's deep linking is off, so a universal link becomes a tap and
  /// Dart picks the screen. True when the activity was such a link. Any
  /// other activity is left to Flutter.
  @discardableResult
  private func openUniversalLink(_ activity: NSUserActivity) -> Bool {
    guard let tap = AppLinkRule.tap(from: activity) else { return false }
    (UIApplication.shared.delegate as? AppDelegate)?.openAppLink(tap)
    return true
  }

  /// Takes a link activity off the scene once it has been handed over.
  private func forgetLinkActivity(on scene: UIScene) {
    if AppLinkRule.holdsLink(scene.userActivity) { scene.userActivity = nil }
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
