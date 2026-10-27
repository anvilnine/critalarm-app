import AVFoundation
import Flutter

/// Plays short interface sounds, such as the cues of the plans screen. One
/// at a time, except that a sound asked for with more than one voice may
/// overlap itself (a run of quick ticks). Wired to `app.critalarm/ui_sound`.
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

  /// The most copies of one sound that may play at once, whatever is asked.
  static let maxVoices = 4

  /// What is playing, oldest first.
  private var playing: [(asset: String, player: AVAudioPlayer)] = []

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

  /// How many copies the caller may have. Nothing asked means one.
  static func voices(_ asked: Int?) -> Int {
    return min(max(asked ?? 1, 1), maxVoices)
  }

  /// Which of the sounds now `playing`, oldest first, must stop before
  /// `asset` starts with `voices` copies allowed.
  ///
  /// With one voice everything stops: a new sound replaces the old one. With
  /// more, the newest copies of the same sound are left to finish, so that
  /// with the new one there are never more than `voices`. A different sound
  /// always stops. The Android side has the same rule, with its tests.
  static func toStop(playing: [String], asset: String, voices: Int) -> [Int] {
    let same = playing.indices.filter { playing[$0] == asset }
    let kept = Set(same.suffix(UiSoundPlayer.voices(voices) - 1))
    return playing.indices.filter { !kept.contains($0) }
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: UiSoundPlayer.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "play":
        let arguments = call.arguments as? [String: Any]
        let asset = arguments?["asset"] as? String
        let voices = arguments?["voices"] as? Int
        result(self?.play(asset: asset, voices: voices) ?? false)
      case "stop":
        self?.stop()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Plays [asset] once, in place of whatever was playing. Never queues.
  /// With `voices` above one, copies of the same sound are left to finish.
  func play(asset: String?, voices: Int? = nil) -> Bool {
    guard let asset, UiSoundPlayer.isInterfaceSound(asset) else {
      stop()
      return false
    }
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
      stop()
      return false
    }
    let going = UiSoundPlayer.toStop(
      playing: playing.map { $0.asset },
      asset: asset,
      voices: UiSoundPlayer.voices(voices)
    )
    for index in going.reversed() {
      playing[index].player.stop()
      playing.remove(at: index)
    }
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
      playing.append((asset: asset, player: next))
      return next.play()
    } catch {
      NSLog("CritAlarmUiSound: ui_sound_failed asset=%@ error=%@", asset, "\(error)")
      return false
    }
  }

  /// Stops whatever is playing. Safe to call when nothing is.
  func stop() {
    for voice in playing {
      voice.player.stop()
    }
    playing.removeAll()
  }

  /// A call, an alarm or another app took the audio. The sound is dropped,
  /// never resumed.
  @objc private func interrupted(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
    DispatchQueue.main.async { self.stop() }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    playing.removeAll { $0.player === player }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    playing.removeAll { $0.player === player }
  }
}
