import AVFoundation
import Flutter
import Security
import UIKit
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The `INCIDENT` category in api.md §5.1, with its single `ACK` action.
  static let incidentCategory = "INCIDENT"
  static let ackAction = "ACK"

  private var pushChannel: FlutterMethodChannel?
  private var alarmChannel: FlutterMethodChannel?
  private var soundChannel: FlutterMethodChannel?
  private var alarmUpdatesTask: Task<Void, Never>?

  /// Held until Dart asks for it, which can be after APNs has already
  /// answered.
  private var apnsToken: String?

  /// A tap or an ack can beat Dart to the channel. They wait here until Dart
  /// asks for them with `takePending`, and after that they go over live.
  private var pendingTap: [String: String]?
  private var pendingAck: String?
  private var dartIsListening = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Anything the extension logged while the app was not running. Moved
    // before the engine starts, or Dart's drain can run first and miss it.
    let moved = PushEventLog.handOverToDart()
    if moved > 0 { NSLog("CritAlarm: push_events_handed_over count=%d", moved) }

    let started = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    #if DEBUG
    // SPIKE ONLY. Removed once the onboarding permissions screen owns this.
    if #available(iOS 26.0, *) { Task { await IncidentAlarmScheduler.requestAuthorization() } }
    #endif
    startAlarmAndActivityStreams()
    registerIncidentCategory()
    // The engine owns the delegate by default. Take it back so the ACK action
    // and the in-app banner land here.
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    return started
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "CritAlarmPush")?.messenger() else { return }

    let push = FlutterMethodChannel(name: "app.critalarm/push", binaryMessenger: messenger)
    push.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getApnsToken":
        result(self?.apnsToken)
      case "takePending":
        result(self?.takePending())
      case "setBadgeCount":
        let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 0
        UNUserNotificationCenter.current().setBadgeCount(count)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = push

    soundChannel = attachSoundChannel(messenger: messenger)

    let alarm = FlutterMethodChannel(name: "app.critalarm/alarm", binaryMessenger: messenger)
    alarm.setMethodCallHandler { [weak self] call, result in
      self?.handleAlarmCall(call, result: result)
    }
    alarmChannel = alarm

    let identity = FlutterMethodChannel(
      name: "app.critalarm/device_identity", binaryMessenger: messenger
    )
    identity.setMethodCallHandler { call, result in
      DeviceIdentityKeychain.handle(call, result: result)
    }

    let credentials = FlutterMethodChannel(
      name: "app.critalarm/nse_credentials",
      binaryMessenger: messenger
    )
    credentials.setMethodCallHandler { call, result in
      switch call.method {
      case "write":
        guard let args = call.arguments as? [String: Any],
              let server = args["server"] as? String,
              let token = args["token"] as? String else {
          result(FlutterError(code: "bad_args", message: "server and token required", details: nil))
          return
        }
        NseCredentials.write(server: server, token: token)
        result(nil)
      case "clear":
        NseCredentials.clear()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - APNs registration

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    NSLog("CritAlarm: apns_token_registered length=%d", token.count)
    #if DEBUG
    // Needed to aim a real push at this handset. Debug only: the token is
    // what lets anyone with the relay's key ring this device.
    NSLog("CritAlarm: apns_token=%@", token)
    #endif
    apnsToken = token
    pushChannel?.invokeMethod("onApnsToken", arguments: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    NSLog("CritAlarm: apns_registration_failed reason=%@", "\(error)")
  }

  // MARK: - Notifications

  /// api.md §5.1: one category, one action. `foreground: false` keeps the ack
  /// off the main path, so tapping "I'm up" stops the alarm without opening
  /// the app.
  private func registerIncidentCategory() {
    let ack = UNNotificationAction(
      identifier: Self.ackAction,
      title: "I'm up",
      options: []
    )
    let category = UNNotificationCategory(
      identifier: Self.incidentCategory,
      actions: [ack],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  /// Banners stay visible while the app is open. A critical alert that only
  /// showed up in the notification list would be missed.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    NSLog("CritAlarm: push_presented_foreground title=%@", notification.request.content.title)
    completionHandler([.banner, .list, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    let incidentId = info["incident_id"] as? String

    if response.actionIdentifier == Self.ackAction, let incidentId {
      // No engine is guaranteed here, so the ack goes straight on the queue
      // Dart drains. A running app is told so it can send it now.
      AckQueueStore.enqueue(action: "ack", incidentId: incidentId)
      if dartIsListening {
        pushChannel?.invokeMethod("onAckQueued", arguments: incidentId)
      } else {
        pendingAck = incidentId
      }
      completionHandler()
      return
    }

    if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      var tap: [String: String] = [:]
      if let incidentId { tap["incident_id"] = incidentId }
      if let topic = info["topic"] as? String { tap["topic"] = topic }
      if !tap.isEmpty {
        if dartIsListening {
          pushChannel?.invokeMethod("onNotificationTap", arguments: tap)
        } else {
          pendingTap = tap
        }
      }
    }

    completionHandler()
  }

  /// Hands Dart whatever arrived before it was listening, once. A cold launch
  /// from a tap comes through here, which is how the app opens on the right
  /// screen.
  private func takePending() -> [String: Any] {
    dartIsListening = true
    var pending: [String: Any] = [:]
    if let tap = pendingTap { pending["tap"] = tap }
    if let ack = pendingAck { pending["ack"] = ack }
    pendingTap = nil
    pendingAck = nil
    return pending
  }

  // MARK: - Alarm and Live Activity

  /// Both streams start on every launch: `alarmUpdates` keeps the coordinator's
  /// idea of a live alarm honest, and the activity streams pick up the
  /// push-to-start token and any card the relay started while the app was away.
  private func startAlarmAndActivityStreams() {
    if #available(iOS 16.2, *) {
      IncidentActivityCoordinator.shared.start()
      IncidentActivityCoordinator.shared.onTokenCaptured = { [weak self] kind, token, incidentId in
        var payload: [String: Any] = ["kind": kind.rawValue, "token": token]
        if let incidentId { payload["incident_id"] = incidentId }
        self?.alarmChannel?.invokeMethod("onActivityToken", arguments: payload)
      }
    }
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      alarmUpdatesTask?.cancel()
      alarmUpdatesTask = IncidentAlarmScheduler.observeAlarmUpdates()
    }
    #endif
  }

  private func handleAlarmCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "authorizationStatus":
      result(alarmAuthorizationName())

    case "requestAuthorization":
      #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        Task {
          _ = await IncidentAlarmScheduler.requestAuthorization()
          await MainActor.run { result(self.alarmAuthorizationName()) }
        }
        return
      }
      #endif
      result("unsupported")

    case "scheduleAlarm":
      guard let incidentId = args["incident_id"] as? String else {
        result(FlutterError(code: "bad_args", message: "incident_id required", details: nil))
        return
      }
      scheduleAlarm(
        incidentId: incidentId,
        topic: args["topic"] as? String ?? "",
        server: args["server"] as? String ?? "",
        title: args["title"] as? String ?? "Crit Alarm",
        sound: args["sound"] as? String
      ) { ok in result(ok) }

    case "cancelAlarm":
      guard let incidentId = args["incident_id"] as? String else {
        result(FlutterError(code: "bad_args", message: "incident_id required", details: nil))
        return
      }
      #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        Task {
          await IncidentAlarmScheduler.cancel(incidentId: incidentId)
          if #available(iOS 16.2, *) {
            await IncidentActivityCoordinator.shared.end(incidentId: incidentId, finalState: .closed)
          }
          await MainActor.run { result(true) }
        }
        return
      }
      #endif
      result(false)

    case "startLocalActivity":
      guard #available(iOS 16.2, *), let incidentId = args["incident_id"] as? String else {
        result(false)
        return
      }
      let started = IncidentActivityCoordinator.shared.startLocalActivity(
        incidentId: incidentId,
        topic: args["topic"] as? String ?? "",
        server: args["server"] as? String ?? "",
        title: args["title"] as? String ?? "Crit Alarm",
        state: IncidentActivityState(rawValue: args["state"] as? String ?? "open") ?? .open
      )
      result(started)

    case "endActivity":
      guard #available(iOS 16.2, *), let incidentId = args["incident_id"] as? String else {
        result(false)
        return
      }
      let state = IncidentActivityState(rawValue: args["state"] as? String ?? "closed") ?? .closed
      IncidentActivityCoordinator.shared.end(incidentId: incidentId, finalState: state)
      result(true)

    case "showingIncidentIds":
      guard #available(iOS 16.2, *) else { result([String]()); return }
      result(IncidentActivityCoordinator.shared.showingIncidentIds())

    case "takePendingActivityTokens":
      guard #available(iOS 16.2, *) else { result([[String: Any]]()); return }
      result(IncidentActivityCoordinator.shared.takePendingTokens())

    case "pushToStartReady":
      result(UserDefaults.standard.bool(forKey: "flutter.live_activity_push_to_start_ready"))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func alarmAuthorizationName() -> String {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      switch IncidentAlarmScheduler.authorization {
      case .authorized: return "authorized"
      case .denied: return "denied"
      case .notDetermined: return "notDetermined"
      @unknown default: return "notDetermined"
      }
    }
    #endif
    return "unsupported"
  }

  private func scheduleAlarm(
    incidentId: String,
    topic: String,
    server: String,
    title: String,
    sound: String?,
    completion: @escaping (Bool) -> Void
  ) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task {
        let ok = await IncidentAlarmScheduler.schedule(
          incidentId: incidentId, topic: topic, server: server, title: title, sound: sound
        )
        await MainActor.run {
          if ok {
            self.alarmChannel?.invokeMethod("onAlarmScheduled", arguments: incidentId)
          }
          completion(ok)
        }
      }
      return
    }
    #endif
    NSLog("CritAlarmAlarm: alarm_not_scheduled reason=alarmkit_unavailable incident_id=%@", incidentId)
    completion(false)
  }

  /// The path-2 trigger. A push with `content-available: 1` wakes the app here
  /// with no UI, and the alarm is scheduled from the main process.
  ///
  /// Which of this and the extension actually does the scheduling is decided by
  /// `AlarmTriggerPath` (docs/specs/remote-alarm-ios-spike.md). Both are wired;
  /// the losing one logs and returns.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard let push = IncidentPush(payload: userInfo) else {
      completionHandler(.noData)
      return
    }
    NSLog(
      "CritAlarm: background_push kind=%@ priority=%d incident_id=%@",
      push.kind.rawValue, push.priority, push.incidentId ?? "-"
    )

    guard let incidentId = push.incidentId else {
      completionHandler(.noData)
      return
    }

    // A push that says the incident is done cancels the alarm and ends the card.
    if push.kind == .p4 {
      completionHandler(.noData)
      return
    }

    guard AlarmTriggerPath.chosen == .appBackgroundPush else {
      NSLog("CritAlarm: background_push_ignored reason=extension_owns_scheduling")
      completionHandler(.noData)
      return
    }

    scheduleAlarm(
      incidentId: incidentId,
      topic: userInfo["topic"] as? String ?? "",
      server: push.server.absoluteString,
      title: push.title ?? "Crit Alarm",
      sound: userInfo["sound"] as? String
    ) { ok in
      completionHandler(ok ? .newData : .noData)
    }
  }
}

// MARK: - Sound library

/// The native half of the sound picker.
///
/// iOS has no alarm audio stream. Both the alarm API and the notification API
/// take a file *name* and look for it in two places: the app bundle, and
/// `Library/Sounds`. Flutter assets live inside `App.framework`, which is
/// neither, so every bundled sound is copied out to `Library/Sounds` on launch
/// and referenced by name from then on.
///
/// `UNNotificationSound` reads caf, wav and aiff only, never mp3, so the copy
/// is also a conversion.
enum SoundLibrary {
  static let group = "group.app.critalarm"
  static let selectedSoundKey = "selected_sound_name"

  /// `Library/Sounds`, created if it is not there yet.
  static var soundsDirectory: URL? {
    guard let library = FileManager.default.urls(
      for: .libraryDirectory, in: .userDomainMask
    ).first else { return nil }
    let directory = library.appendingPathComponent("Sounds", isDirectory: true)
    try? FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true
    )
    return directory
  }

  /// Turns `assets/sounds/pager_beep.mp3` into a real file inside the bundle.
  static func bundleURL(forFlutterAsset asset: String) -> URL? {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
    return URL(fileURLWithPath: path)
  }

  /// Copies the eight bundled sounds into `Library/Sounds` as caf.
  ///
  /// Cheap to call on every launch: a file already there is left alone.
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
            convertToCAF(source: source, destination: destination) else {
        NSLog("CritAlarmSound: prepare_failed asset=%@", asset)
        allDone = false
        continue
      }
    }
    NSLog("CritAlarmSound: prepared count=%d ok=%@", assets.count, "\(allDone)")
    return allDone
  }

  /// Decodes anything AVFoundation can read and writes 16-bit PCM in a caf.
  static func convertToCAF(source: URL, destination: URL) -> Bool {
    let asset = AVURLAsset(url: source)
    guard let track = asset.tracks(withMediaType: .audio).first,
          let reader = try? AVAssetReader(asset: asset),
          let writer = try? AVAssetWriter(outputURL: destination, fileType: .caf)
    else { return false }

    let readSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: readSettings)
    let writeSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: writeSettings)
    input.expectsMediaDataInRealTime = false
    guard reader.canAdd(output), writer.canAdd(input) else { return false }
    reader.add(output)
    writer.add(input)

    guard writer.startWriting() else { return false }
    writer.startSession(atSourceTime: .zero)
    reader.startReading()

    let queue = DispatchQueue(label: "app.critalarm.sound.convert")
    let done = DispatchSemaphore(value: 0)
    input.requestMediaDataWhenReady(on: queue) {
      while input.isReadyForMoreMediaData {
        if let buffer = output.copyNextSampleBuffer() {
          input.append(buffer)
        } else {
          input.markAsFinished()
          writer.finishWriting { done.signal() }
          return
        }
      }
    }
    _ = done.wait(timeout: .now() + 30)
    let ok = writer.status == .completed
    if !ok { try? FileManager.default.removeItem(at: destination) }
    return ok
  }

  /// Length in whole milliseconds. Zero when nothing could read the file.
  static func durationMs(of url: URL) -> Int {
    let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
    guard seconds.isFinite, seconds > 0 else { return 0 }
    return Int(seconds * 1000)
  }

  /// Copies a file the user picked into `Library/Sounds` as caf, under [id].
  static func importSound(source: URL, id: String) -> [String: Any]? {
    guard let directory = soundsDirectory else { return nil }
    let destination = directory.appendingPathComponent("\(id).caf")
    try? FileManager.default.removeItem(at: destination)
    guard convertToCAF(source: source, destination: destination) else {
      NSLog("CritAlarmSound: import_failed id=%@", id)
      return nil
    }
    let ms = durationMs(of: destination)
    guard ms > 0 else {
      try? FileManager.default.removeItem(at: destination)
      return nil
    }
    NSLog("CritAlarmSound: sound_imported id=%@ path=%@ duration_ms=%d", id, destination.path, ms)
    return ["path": destination.path, "duration_ms": ms]
  }

  /// The file name the alarm and notification APIs are handed.
  static func fileName(forSoundId id: String) -> String { "\(id).caf" }

  /// Whether a name resolves to a file this app can point an API at.
  static func exists(fileName: String) -> Bool {
    guard let directory = soundsDirectory else { return false }
    return FileManager.default.fileExists(
      atPath: directory.appendingPathComponent(fileName).path
    )
  }

  /// Which sound rings, read the same way Dart wrote it.
  ///
  /// `shared_preferences` on iOS writes into the standard user defaults with a
  /// `flutter.` prefix.
  static func soundId(forTopic topic: String?) -> String {
    let defaults = UserDefaults.standard
    let fallback = defaults.string(forKey: "flutter.alarm_sound_default") ?? "classic_siren"
    guard let topic, !topic.isEmpty,
          let raw = defaults.string(forKey: "flutter.alarm_sound_per_topic"),
          let data = raw.data(using: .utf8),
          let map = try? JSONSerialization.jsonObject(with: data) as? [String: String],
          let picked = map[topic], !picked.isEmpty
    else { return fallback }
    return picked
  }

  /// The name for the alarm and for `UNNotificationSound`, or nil to leave the
  /// system default alone because the file is not there.
  static func resolvedFileName(forTopic topic: String?) -> String? {
    let name = fileName(forSoundId: soundId(forTopic: topic))
    return exists(fileName: name) ? name : nil
  }

  /// Hands the notification extension the current choice. The extension runs
  /// in its own process and cannot read the app's defaults, so it reads this.
  static func publishToExtension(topic: String?) {
    guard let shared = UserDefaults(suiteName: group) else { return }
    shared.set(resolvedFileName(forTopic: topic), forKey: selectedSoundKey)
  }
}

/// Plays one sound in the picker.
///
/// `.playback` rather than `.ambient`, so a preview is audible with the ring
/// switch on silent, which is the point of an alarm sound.
final class SoundPreviewPlayer: NSObject, AVAudioPlayerDelegate {
  static let shared = SoundPreviewPlayer()

  private var player: AVAudioPlayer?

  func start(url: URL) -> Bool {
    stop()
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      let player = try AVAudioPlayer(contentsOf: url)
      player.delegate = self
      // One pass. The picker is not the alarm.
      player.numberOfLoops = 0
      player.prepareToPlay()
      self.player = player
      return player.play()
    } catch {
      NSLog("CritAlarmSound: preview_failed url=%@ error=%@", url.path, "\(error)")
      return false
    }
  }

  func stop() {
    player?.stop()
    player = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    stop()
  }
}

extension AppDelegate {
  /// Wires `app.critalarm/sound`. Called from the engine setup.
  func attachSoundChannel(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: "app.critalarm/sound", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "capabilities":
        result([
          // Answered by the measurement in
          // docs/specs/remote-alarm-ios-spike.md.
          "user_sounds_ring_alarm": AlarmSoundPolicy.librarySoundsRingAlarm,
          "bundled_sounds_ring_alarm": AlarmSoundPolicy.librarySoundsRingAlarm,
        ])
      case "prepareBundledSounds":
        let assets = args["assets"] as? [String] ?? []
        result(SoundLibrary.prepare(assets: assets))
      case "startPreview":
        guard let path = args["path"] as? String else { result(false); return }
        let isAsset = args["is_asset"] as? Bool ?? false
        let url = isAsset
          ? SoundLibrary.bundleURL(forFlutterAsset: path)
          : URL(fileURLWithPath: path)
        guard let url else { result(false); return }
        result(SoundPreviewPlayer.shared.start(url: url))
      case "stopPreview":
        SoundPreviewPlayer.shared.stop()
        result(true)
      case "probeDuration":
        guard let path = args["path"] as? String else { result(0); return }
        result(SoundLibrary.durationMs(of: URL(fileURLWithPath: path)))
      case "importSound":
        guard let source = args["source_path"] as? String,
              let id = args["id"] as? String else { result(nil); return }
        result(SoundLibrary.importSound(source: URL(fileURLWithPath: source), id: id))
      case "deleteSound":
        guard let path = args["path"] as? String else { result(false); return }
        result((try? FileManager.default.removeItem(atPath: path)) != nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return channel
  }
}

/// What the spike found out about where AlarmKit will read a sound from.
///
/// One flag, one place, so flipping the answer flips the picker, the alarm and
/// the "notifications only" line together.
enum AlarmSoundPolicy {
  /// True when `AlertConfiguration.AlertSound.named(_:)` resolves a file in
  /// `Library/Sounds`. False means only a compiled-in bundle resource rings,
  /// and every picked sound is a notification sound only.
  ///
  /// Measured on device. See docs/specs/remote-alarm-ios-spike.md.
  static let librarySoundsRingAlarm = false
}

/// Identity is synchronized as one item; updates never delete the old secret.
enum DeviceIdentityKeychain {
  static func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "app.critalarm.device_identity",
      kSecAttrAccount as String: "identity",
      kSecAttrSynchronizable as String: true,
    ]
    if let group = NseCredentials.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }
    switch call.method {
    case "read":
      query[kSecReturnData as String] = true
      query[kSecMatchLimit as String] = kSecMatchLimitOne
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      if status == errSecItemNotFound { result(nil); return }
      guard status == errSecSuccess, let data = item as? Data,
            let value = String(data: data, encoding: .utf8) else {
        result(FlutterError(code: "keychain_read", message: "Identity read failed", details: status))
        return
      }
      result(value)
    case "write":
      guard let value = call.arguments as? String,
            let data = value.data(using: .utf8) else {
        result(FlutterError(code: "bad_args", message: "Identity required", details: nil))
        return
      }
      let attributes: [String: Any] = [
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
      ]
      var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
      if status == errSecItemNotFound {
        query.merge(attributes) { _, new in new }
        status = SecItemAdd(query as CFDictionary, nil)
      }
      guard status == errSecSuccess else {
        result(FlutterError(code: "keychain_write", message: "Identity write failed", details: status))
        return
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
