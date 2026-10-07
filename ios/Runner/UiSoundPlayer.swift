import AVFoundation
import Flutter

/// Plays one short interface sound at a time, such as the cues of the plans
/// screen. Wired to `app.critalarm/ui_sound`.
///
/// This is not the alarm and not the sound picker's preview. An alarm on
/// iPhone is played by the system (AlarmKit, or a notification sound), never
/// by this app's audio session, so nothing here can reach it.
///
/// A sound plays under the `.ambient` category: it follows the ring switch
/// and the media volume, and it mixes with music instead of stopping it. The
/// session is never activated or deactivated by hand, and no volume is read
/// or set.
final class UiSoundPlayer: NSObject, AVAudioPlayerDelegate {
  static let shared = UiSoundPlayer()

  static let channelName = "app.critalarm/ui_sound"

  /// The only folder a sound may come from. The alarm sounds live elsewhere.
  static let assetFolder = "assets/ui_sounds/"

  private var player: AVAudioPlayer?

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(interrupted(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }

  /// Whether [asset] is one of the interface sounds. Anything else is
  /// refused, so this player can never be handed an alarm sound.
  static func isInterfaceSound(_ asset: String?) -> Bool {
    guard let asset, asset.hasPrefix(assetFolder) else { return false }
    let name = String(asset.dropFirst(assetFolder.count))
    return name.range(of: "^[a-z0-9_]+\\.m4a$", options: .regularExpression) != nil
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: UiSoundPlayer.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "play":
        let asset = (call.arguments as? [String: Any])?["asset"] as? String
        result(self?.play(asset: asset) ?? false)
      case "stop":
        self?.stop()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Plays [asset] once, in place of whatever was playing. Never queues.
  func play(asset: String?) -> Bool {
    stop()
    guard let asset, UiSoundPlayer.isInterfaceSound(asset) else { return false }
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return false }
    do {
      // The sound picker leaves the session on `.playback`, which ignores
      // the ring switch. An interface sound must not, so it asks for
      // `.ambient` whenever the session is on anything else.
      let session = AVAudioSession.sharedInstance()
      if session.category != .ambient {
        try session.setCategory(.ambient)
      }
      let next = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
      next.delegate = self
      next.numberOfLoops = 0
      player = next
      return next.play()
    } catch {
      NSLog("CritAlarmUiSound: ui_sound_failed asset=%@ error=%@", asset, "\(error)")
      player = nil
      return false
    }
  }

  /// Stops whatever is playing. Safe to call when nothing is.
  func stop() {
    player?.stop()
    player = nil
  }

  /// A call, an alarm or another app took the audio. The sound is dropped,
  /// never resumed.
  @objc private func interrupted(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
    DispatchQueue.main.async { self.stop() }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    if self.player === player { self.player = nil }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    if self.player === player { self.player = nil }
  }
}
