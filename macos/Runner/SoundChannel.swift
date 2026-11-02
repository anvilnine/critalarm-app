import AVFoundation
import CoreMedia
import FlutterMacOS
import Foundation

/// The Mac half of `app.critalarm/sound`, Dart's `SoundHost`.
///
/// It answers the same calls as the iPhone's `attachSoundChannel` in
/// `ios/Runner/AppDelegate.swift`, and writes the same files: 16-bit mono caf
/// through `GaplessCaf` (shared with the iPhone), in the sandbox container's
/// `Application Support/Sounds`. A macOS notification sound is looked up in
/// the bundle and `~/Library/Sounds`, so the alert sound needs its own answer
/// once the Mac gets push.
/// `ios/Shared/SharedSounds.swift` is not shared: it needs the iPhone's own
/// sound lock and app group code.
///
/// Left out on purpose: the app group copy for the notification extension
/// (the Mac has no extension), store-hosted packs and shared-in audio.
enum SoundChannel {
  private static var channel: FlutterMethodChannel?

  static func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.critalarm/sound", binaryMessenger: messenger)
    MacSoundPreviewPlayer.shared.onEnded = { [weak channel] path in
      channel?.invokeMethod("previewEnded", arguments: ["path": path])
    }
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "capabilities":
        // The Mac plays the alarm sound itself, from the file, so a picked
        // sound rings the same as a bundled one.
        result([
          "user_sounds_ring_alarm": true,
          "bundled_sounds_ring_alarm": true,
          "can_import_sounds": true,
        ])
      case "prepareBundledSounds":
        let assets = args["assets"] as? [String] ?? []
        MacSoundLibrary.inBackground(result) { MacSoundLibrary.prepare(assets: assets) }
      case "startPreview":
        guard let path = args["path"] as? String else { result(false); return }
        let isAsset = args["is_asset"] as? Bool ?? false
        let url = isAsset
          ? MacSoundLibrary.bundleURL(forFlutterAsset: path)
          : MacSoundLibrary.localURL(forStoredPath: path)
        guard let url else { result(false); return }
        let from = (args["start_ms"] as? Int).map { TimeInterval($0) / 1000 }
        let to = (args["end_ms"] as? Int).map { TimeInterval($0) / 1000 }
        result(MacSoundPreviewPlayer.shared.start(url: url, path: path, from: from, to: to))
      case "stopPreview":
        MacSoundPreviewPlayer.shared.stop()
        result(true)
      case "probeDuration":
        guard let path = args["path"] as? String else { result(0); return }
        MacSoundLibrary.inBackground(result) {
          MacSoundLibrary.durationMs(of: URL(fileURLWithPath: path))
        }
      case "importSound":
        guard let source = args["source_path"] as? String,
              let id = args["id"] as? String else { result(nil); return }
        let startMs = args["start_ms"] as? Int
        let endMs = args["end_ms"] as? Int
        MacSoundLibrary.inBackground(result) {
          MacSoundLibrary.importSound(
            source: URL(fileURLWithPath: source), id: id, startMs: startMs, endMs: endMs
          )
        }
      case "readPeaks":
        guard let path = args["path"] as? String else { result([Double]()); return }
        let isAsset = args["is_asset"] as? Bool ?? false
        let count = args["count"] as? Int ?? 0
        let token = args["token"] as? String
        MacSoundLibrary.inBackground(result) {
          let url = isAsset
            ? MacSoundLibrary.bundleURL(forFlutterAsset: path)
            : MacSoundLibrary.localURL(forStoredPath: path)
          guard let url else { return [Double]() }
          return MacSoundLibrary.readPeaks(url: url, count: count, token: token)
        }
      case "cancelPeaks":
        if let token = args["token"] as? String { MacSoundLibrary.cancelPeaks(token: token) }
        result(nil)
      case "deleteSound":
        guard let path = args["path"] as? String else { result(false); return }
        MacSoundLibrary.inBackground(result) {
          (try? FileManager.default.removeItem(at: MacSoundLibrary.localURL(forStoredPath: path))) != nil
        }
      case "publishSoundAssignments":
        // Nothing reads the choices outside the app on a Mac.
        result(true)
      case "takeIncomingAudio":
        // No "Share to Crit Alarm" on the Mac yet.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }
}

/// The sound files on disk. A port of the iPhone's `SoundLibrary` without the
/// app group, the pack bridge and the extension publish.
enum MacSoundLibrary {
  /// A notification sound of 30 seconds or more plays the default sound
  /// instead, on macOS as on the iPhone (`SharedSounds.maxRingMs`).
  static let maxRingMs = 30_000

  static let workQueue = DispatchQueue(label: "app.critalarm.sound.files", qos: .userInitiated)

  static func inBackground(_ result: @escaping FlutterResult, _ work: @escaping () -> Any?) {
    workQueue.async {
      let answer = work()
      DispatchQueue.main.async { result(answer) }
    }
  }

  /// `Application Support/Sounds` inside the sandbox container, created if
  /// missing. Not `Library/Sounds`: in a sandbox container that folder is a
  /// symlink to the person's own `~/Library/Sounds`, which is not ours.
  static var soundsDirectory: URL? {
    guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?.appendingPathComponent("Sounds", isDirectory: true)
    else { return nil }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// A stored path that no longer exists is looked up by name in the sounds
  /// folder, the same rule as the iPhone.
  static func localURL(forStoredPath path: String) -> URL {
    let stored = URL(fileURLWithPath: path)
    if FileManager.default.fileExists(atPath: stored.path) { return stored }
    guard let directory = soundsDirectory else { return stored }
    let byName = directory.appendingPathComponent(stored.lastPathComponent)
    return FileManager.default.fileExists(atPath: byName.path) ? byName : stored
  }

  /// Turns `assets/sounds/pager_beep.mp3` into the file inside
  /// `App.framework/Resources/flutter_assets`.
  static func bundleURL(forFlutterAsset asset: String) -> URL? {
    if let frameworks = Bundle.main.privateFrameworksURL,
       let app = Bundle(url: frameworks.appendingPathComponent("App.framework")),
       let resources = app.resourceURL {
      let url = resources.appendingPathComponent("flutter_assets").appendingPathComponent(asset)
      if FileManager.default.fileExists(atPath: url.path) { return url }
    }
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
    return URL(fileURLWithPath: path)
  }

  /// Copies the bundled sounds into the sounds folder as caf. A file already
  /// there is left alone, so this is cheap on every launch.
  @discardableResult
  static func prepare(assets: [String]) -> Bool {
    guard let directory = soundsDirectory else { return false }
    var allDone = true
    for asset in assets {
      let name = (asset as NSString).lastPathComponent
      let id = (name as NSString).deletingPathExtension
      let destination = directory.appendingPathComponent("\(id).caf")
      if FileManager.default.fileExists(atPath: destination.path) { continue }
      guard let source = bundleURL(forFlutterAsset: asset),
            GaplessCaf.convert(source: source, destination: destination) else {
        NSLog("CritAlarmSound: prepare_failed asset=%@", asset)
        allDone = false
        continue
      }
    }
    NSLog("CritAlarmSound: prepared count=%d ok=%@", assets.count, "\(allDone)")
    return allDone
  }

  /// Length in whole milliseconds. Zero when nothing could read the file.
  static func durationMs(of url: URL) -> Int {
    let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
    guard seconds.isFinite, seconds > 0 else { return 0 }
    return Int(seconds * 1000)
  }

  /// Cuts [startMs] to [endMs] out of a picked file and saves it as caf under
  /// [id]. Over 30 seconds is refused, the limit a macOS notification sound
  /// shares with the iPhone.
  static func importSound(source: URL, id: String, startMs: Int?, endMs: Int?) -> [String: Any]? {
    guard let directory = soundsDirectory else { return nil }
    let destination = directory.appendingPathComponent("\(id).caf")
    try? FileManager.default.removeItem(at: destination)
    var start: Double?
    var end: Double?
    if startMs != nil || endMs != nil {
      guard let startMs, let endMs, endMs > startMs, startMs >= 0 else {
        NSLog("CritAlarmSound: import_bad_range id=%@", id)
        return nil
      }
      start = Double(startMs) / 1000
      end = Double(endMs) / 1000
    }
    // The picked file is outside the sandbox. The open panel granted read
    // access to it for as long as the app runs.
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
    guard GaplessCaf.convert(source: source, destination: destination, start: start, end: end) else {
      NSLog("CritAlarmSound: import_failed id=%@", id)
      return nil
    }
    let ms = durationMs(of: destination)
    guard ms > 0, ms < maxRingMs else {
      NSLog("CritAlarmSound: import_rejected id=%@ duration_ms=%d", id, ms)
      try? FileManager.default.removeItem(at: destination)
      return nil
    }
    let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
    NSLog("CritAlarmSound: sound_imported id=%@ duration_ms=%d size_bytes=%d", id, ms, size)
    return ["path": destination.path, "duration_ms": ms, "size_bytes": size]
  }

  /// How loud [url] is across [count] even slices: RMS per slice, the loudest
  /// at 1. Decoded at 8 kHz mono one buffer at a time. Empty on failure.
  static func readPeaks(url: URL, count: Int, token: String? = nil) -> [Double] {
    guard count > 0 else { return [] }
    defer { forgetToken(token) }
    let asset = AVURLAsset(url: url)
    let seconds = CMTimeGetSeconds(asset.duration)
    guard seconds.isFinite, seconds > 0,
          let track = asset.tracks(withMediaType: .audio).first,
          let reader = try? AVAssetReader(asset: asset)
    else { return [] }

    let rate = 8000.0
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: rate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { return [] }
    reader.add(output)
    guard reader.startReading() else { return [] }

    let totalFrames = max(1.0, seconds * rate)
    var sums = [Double](repeating: 0, count: count)
    var frames = [Int](repeating: 0, count: count)
    var frameIndex = 0
    var samples = [Int16]()
    while true {
      if isCancelled(token) {
        reader.cancelReading()
        return []
      }
      let more: Bool = autoreleasepool {
        guard let buffer = output.copyNextSampleBuffer() else { return false }
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return true }
        let sampleCount = CMBlockBufferGetDataLength(block) / 2
        guard sampleCount > 0 else { return true }
        if samples.count < sampleCount {
          samples = [Int16](repeating: 0, count: sampleCount)
        }
        let copied = samples.withUnsafeMutableBytes { raw in
          CMBlockBufferCopyDataBytes(
            block, atOffset: 0, dataLength: sampleCount * 2, destination: raw.baseAddress!
          )
        }
        guard copied == kCMBlockBufferNoErr else { return true }
        for i in 0..<sampleCount {
          let value = Double(samples[i]) / 32768
          let slice = min(count - 1, Int(Double(frameIndex) * Double(count) / totalFrames))
          sums[slice] += value * value
          frames[slice] += 1
          frameIndex += 1
        }
        return true
      }
      if !more { break }
    }
    guard reader.status == .completed else { return [] }

    let rms = (0..<count).map { frames[$0] > 0 ? (sums[$0] / Double(frames[$0])).squareRoot() : 0 }
    let loudest = rms.max() ?? 0
    return loudest > 0 ? rms.map { $0 / loudest } : rms
  }

  private static let cancelLock = NSLock()
  private static var cancelledTokens = Set<String>()

  static func cancelPeaks(token: String) {
    cancelLock.lock()
    cancelledTokens.insert(token)
    cancelLock.unlock()
  }

  private static func isCancelled(_ token: String?) -> Bool {
    guard let token else { return false }
    cancelLock.lock()
    defer { cancelLock.unlock() }
    return cancelledTokens.contains(token)
  }

  private static func forgetToken(_ token: String?) {
    guard let token else { return }
    cancelLock.lock()
    cancelledTokens.remove(token)
    cancelLock.unlock()
  }
}

/// Plays one sound in the picker, once. macOS has no audio session, so this
/// plays on the default output at the system volume.
final class MacSoundPreviewPlayer: NSObject, AVAudioPlayerDelegate {
  static let shared = MacSoundPreviewPlayer()

  private var player: AVAudioPlayer?
  private var stopTimer: Timer?
  private var playingPath: String?

  /// Called on the main thread with the playing path when a preview stops
  /// without Dart asking.
  var onEnded: ((String) -> Void)?

  private func end() {
    guard player != nil else { return }
    let path = playingPath ?? ""
    stop()
    onEnded?(path)
  }

  func start(url: URL, path: String, from: TimeInterval? = nil, to: TimeInterval? = nil) -> Bool {
    stop()
    playingPath = path
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.delegate = self
      player.numberOfLoops = 0
      player.prepareToPlay()
      if let from { player.currentTime = from }
      self.player = player
      let playing = player.play()
      if playing, let from, let to, to > from {
        stopTimer = Timer.scheduledTimer(withTimeInterval: to - from, repeats: false) { [weak self] _ in
          self?.end()
        }
      }
      return playing
    } catch {
      NSLog("CritAlarmSound: preview_failed error=%@", "\(error)")
      return false
    }
  }

  func stop() {
    stopTimer?.invalidate()
    stopTimer = nil
    player?.stop()
    player = nil
    playingPath = nil
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    DispatchQueue.main.async { self.end() }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    DispatchQueue.main.async { self.end() }
  }
}
