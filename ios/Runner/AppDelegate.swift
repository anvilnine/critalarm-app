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
  private var settingsChannel: FlutterMethodChannel?
  private var alarmUpdatesTask: Task<Void, Never>?

  /// Held until Dart asks for it, which can be after APNs has already
  /// answered.
  private var apnsToken: String?

  /// A tap or an ack can beat Dart to the channel. They wait here until Dart
  /// asks for them with `takePending`.
  ///
  /// A tap is held even once Dart is listening, and sent live as well. Dart
  /// asks for a pending tap every time the app comes back, before it reloads
  /// anything, so the screen the notification asked for is the first one it
  /// paints. Whichever copy reaches Dart first wins; `tap_id` is what makes
  /// the other a no-op.
  private var pendingTap: [String: String]?
  private var pendingAck: String?
  private var dartIsListening = false

  /// Counts taps, so Dart can tell one from the next.
  private var tapSequence = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Anything the extension logged while the app was not running. Moved
    // before the engine starts, or Dart's drain can run first and miss it.
    let moved = PushEventLog.handOverToDart()
    if moved > 0 { NSLog("CritAlarm: push_events_handed_over count=%d", moved) }

    // Sounds live in the app group now, so the notification extension can
    // play the one the user picked. Both calls are cheap and safe every launch.
    SoundLibrary.migrateToGroupContainer()
    SoundLibrary.publishToExtension()

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

    let settings = FlutterMethodChannel(
      name: "app.critalarm/settings", binaryMessenger: messenger
    )
    settings.setMethodCallHandler { call, result in
      AppDelegate.handleSettingsCall(call, result: result)
    }
    settingsChannel = settings

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
    // Nobody is going to tap this: the app is already open. Tell Dart so the
    // screen the user is on reloads. Nothing about the notification is passed
    // over; what changed is on the server and Dart asks it.
    if dartIsListening {
      pushChannel?.invokeMethod("onPushReceived", arguments: nil)
    }
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
        tapSequence += 1
        tap["tap_id"] = "\(tapSequence)"
        // Held and sent. See `pendingTap`.
        pendingTap = tap
        if dartIsListening {
          pushChannel?.invokeMethod("onNotificationTap", arguments: tap)
        }
      }
    }

    completionHandler()
  }

  /// Hands Dart whatever is waiting, once. A cold launch from a tap comes
  /// through here, which is how the app opens on the right screen, and so
  /// does a tap that woke the app: Dart asks again on every resume, before it
  /// reloads anything.
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
      IncidentActivityCoordinator.shared.onTokenCaptured = { [weak self] kind, token, incidentId, activityId in
        var payload: [String: Any] = ["kind": kind.rawValue, "token": token]
        if let incidentId { payload["incident_id"] = incidentId }
        if let activityId { payload["activity_id"] = activityId }
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
        sound: args["sound"] as? String,
        delaySeconds: args["delay_seconds"] as? Int
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

    case "publishQuietHours":
      // Dart owns the window. This copy is here so the notification
      // extension, which cannot read the app's preferences, can see it too.
      QuietHours.write(
        QuietHours(
          isEnabled: args["enabled"] as? Bool ?? QuietHours.defaults.isEnabled,
          startMinutes: args["start_minutes"] as? Int ?? QuietHours.defaults.startMinutes,
          endMinutes: args["end_minutes"] as? Int ?? QuietHours.defaults.endMinutes,
          criticalRingsThrough: args["critical_rings"] as? Bool
            ?? QuietHours.defaults.criticalRingsThrough
        ),
        to: QuietHours.groupDefaults
      )
      result(nil)

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
    // A push-driven alarm keeps the short default; only onboarding's test
    // alarm passes a delay of its own.
    delaySeconds: Int? = nil,
    completion: @escaping (Bool) -> Void
  ) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task {
        let ok = await IncidentAlarmScheduler.schedule(
          incidentId: incidentId, topic: topic, server: server, title: title, sound: sound,
          delay: delaySeconds.map(TimeInterval.init) ?? IncidentAlarmScheduler.leadTime
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

    // Quiet hours holds the ring and nothing else. This is the live gate: it
    // is this handler that schedules the alarm on a real phone, so the same
    // check in Dart and in the extension does nothing until one of those
    // paths is the one in use. The notification has already been delivered by
    // the time iOS calls this, so the page still arrives, the incident still
    // opens and the card still shows; only the schedule call is skipped.
    let quietHours = QuietHours.read(from: QuietHours.groupDefaults)
    if quietHours.holdsRing(
      minuteOfDay: QuietHours.minuteOf(Date()),
      priority: push.priority
    ) {
      NSLog("CritAlarm: background_push_ignored reason=quiet_hours")
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
/// take a file *name* and look for it in the app bundle and in a
/// `Library/Sounds` folder. Flutter assets live inside `App.framework`, which
/// is neither, so every bundled sound is copied out to `Library/Sounds` on
/// launch and referenced by name from then on. The folder is the app group's
/// one (`SharedSounds`), so the notification extension can see the files too.
///
/// `UNNotificationSound` reads caf, wav and aiff only, never mp3, so the copy
/// is also a conversion.
enum SoundLibrary {
  /// Every read and write of a sound file runs here, one at a time and in
  /// the order asked, so none of it blocks the main thread.
  static let workQueue = DispatchQueue(label: "app.critalarm.sound.files", qos: .userInitiated)

  /// Runs [work] on [workQueue] and hands its answer to Flutter on the main
  /// thread.
  static func inBackground(_ result: @escaping FlutterResult, _ work: @escaping () -> Any?) {
    workQueue.async {
      let answer = work()
      DispatchQueue.main.async { result(answer) }
    }
  }

  /// The app's own `Library/Sounds`. Where sounds lived before they moved to
  /// the app group, and the fallback if the group is missing.
  static var appSoundsDirectory: URL? {
    FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Sounds", isDirectory: true)
  }

  /// The app group's `Library/Sounds`, created if it is not there yet.
  static var soundsDirectory: URL? {
    guard let directory = SharedSounds.groupSoundsDirectory ?? appSoundsDirectory else { return nil }
    try? FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true
    )
    return directory
  }

  /// Moves every sound out of the app's own `Library/Sounds` into the app
  /// group's. Safe to run more than once: a file already in the group is kept
  /// and the old copy is dropped.
  static func migrateToGroupContainer() {
    guard let old = appSoundsDirectory,
          let new = soundsDirectory,
          old.standardizedFileURL != new.standardizedFileURL,
          let names = try? FileManager.default.contentsOfDirectory(atPath: old.path)
    else { return }
    var moved = 0
    for name in names {
      let from = old.appendingPathComponent(name)
      let to = new.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: to.path) {
        try? FileManager.default.removeItem(at: from)
      } else if (try? FileManager.default.moveItem(at: from, to: to)) != nil {
        moved += 1
      }
    }
    if moved > 0 { NSLog("CritAlarmSound: sounds_moved_to_group count=%d", moved) }
  }

  /// Dart keeps the absolute path it got at import time. That path goes stale
  /// when the files move to the group, or when iOS moves the app's container
  /// on an update, so a missing file is looked up by name in the sounds folder.
  static func localURL(forStoredPath path: String) -> URL {
    let stored = URL(fileURLWithPath: path)
    if FileManager.default.fileExists(atPath: stored.path) { return stored }
    guard let directory = soundsDirectory else { return stored }
    let byName = directory.appendingPathComponent(stored.lastPathComponent)
    return FileManager.default.fileExists(atPath: byName.path) ? byName : stored
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

  /// Decodes anything AVFoundation can read and writes 16-bit mono PCM at
  /// 44.1 kHz in a caf. With a [range], only that part is written, with a
  /// 50 ms fade at each end so the cut does not click.
  static func convertToCAF(source: URL, destination: URL, range: CMTimeRange? = nil) -> Bool {
    // Exact timing, so a cut in a VBR mp3 lands where the user put it.
    let asset = AVURLAsset(url: source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    guard let track = asset.tracks(withMediaType: .audio).first,
          let reader = try? AVAssetReader(asset: asset),
          let writer = try? AVAssetWriter(outputURL: destination, fileType: .caf)
    else { return false }
    if let range { reader.timeRange = range }

    // The reader hands over mono 44.1 kHz Int16, the same as what is written,
    // so the fade can work on the samples directly.
    let pcm: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: pcm)
    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: pcm)
    input.expectsMediaDataInRealTime = false
    guard reader.canAdd(output), writer.canAdd(input) else { return false }
    reader.add(output)
    writer.add(input)

    guard writer.startWriting() else { return false }
    writer.startSession(atSourceTime: range?.start ?? .zero)
    guard reader.startReading() else {
      writer.cancelWriting()
      try? FileManager.default.removeItem(at: destination)
      return false
    }

    let fade = range.map { ClipFade(range: $0, seconds: 0.05) }
    let queue = DispatchQueue(label: "app.critalarm.sound.convert")
    let done = DispatchSemaphore(value: 0)
    input.requestMediaDataWhenReady(on: queue) {
      while input.isReadyForMoreMediaData {
        if let buffer = output.copyNextSampleBuffer() {
          input.append(fade?.apply(to: buffer) ?? buffer)
        } else {
          input.markAsFinished()
          if let range { writer.endSession(atSourceTime: range.end) }
          writer.finishWriting { done.signal() }
          return
        }
      }
    }
    if done.wait(timeout: .now() + 60) == .timedOut {
      // Stop both first, so a late finishWriting cannot put a partial file
      // back after it is deleted.
      reader.cancelReading()
      writer.cancelWriting()
      NSLog("CritAlarmSound: convert_timed_out path=%@", destination.path)
      try? FileManager.default.removeItem(at: destination)
      return false
    }
    let ok = writer.status == .completed && reader.status == .completed
    if !ok { try? FileManager.default.removeItem(at: destination) }
    return ok
  }

  /// Length in whole milliseconds. Zero when nothing could read the file.
  static func durationMs(of url: URL) -> Int {
    let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
    guard seconds.isFinite, seconds > 0 else { return 0 }
    return Int(seconds * 1000)
  }

  /// How loud [url] is across [count] even slices: RMS per slice, the loudest
  /// at 1. Decoded at 8 kHz mono one buffer at a time, keeping only a running
  /// sum per slice, so a long file never sits in memory. Empty on failure.
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
        NSLog("CritAlarmSound: peaks_cancelled")
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

  /// Tokens of peak reads Dart has asked to stop. Written from the main
  /// thread, read from the work queue.
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

  /// Cuts [startMs] to [endMs] out of a file the user picked and saves it in
  /// `Library/Sounds` as caf, under [id]. With no range the whole file is
  /// kept. The result must be under 30 seconds, or iOS would play the
  /// default sound instead, so anything longer is deleted.
  static func importSound(source: URL, id: String, startMs: Int?, endMs: Int?) -> [String: Any]? {
    guard let directory = soundsDirectory else { return nil }
    let destination = directory.appendingPathComponent("\(id).caf")
    try? FileManager.default.removeItem(at: destination)
    var range: CMTimeRange?
    if startMs != nil || endMs != nil {
      // A range was sent. A bad one fails rather than keeping the whole file.
      guard let startMs, let endMs, endMs > startMs, startMs >= 0 else {
        NSLog("CritAlarmSound: import_bad_range id=%@", id)
        return nil
      }
      range = CMTimeRange(
        start: CMTime(value: CMTimeValue(startMs), timescale: 1000),
        end: CMTime(value: CMTimeValue(endMs), timescale: 1000)
      )
    }
    guard convertToCAF(source: source, destination: destination, range: range) else {
      NSLog("CritAlarmSound: import_failed id=%@", id)
      return nil
    }
    let ms = durationMs(of: destination)
    guard ms > 0, SharedSounds.ringsOnIphone(durationMs: ms) else {
      NSLog("CritAlarmSound: import_rejected id=%@ duration_ms=%d", id, ms)
      try? FileManager.default.removeItem(at: destination)
      return nil
    }
    let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
    NSLog("CritAlarmSound: sound_imported id=%@ path=%@ duration_ms=%d size_bytes=%d", id, destination.path, ms, size)
    return ["path": destination.path, "duration_ms": ms, "size_bytes": size]
  }

  /// The file name the alarm and notification APIs are handed.
  static func fileName(forSoundId id: String) -> String { "\(id).caf" }

  /// The file name for [id], or nil when the id is empty or the file on disk
  /// runs 30 seconds or more. A missing file is still published; the
  /// extension checks that itself when the push arrives.
  static func ringableFileName(forSoundId id: String) -> String? {
    guard !id.isEmpty else { return nil }
    let name = fileName(forSoundId: id)
    if let directory = soundsDirectory {
      let url = directory.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: url.path),
         !SharedSounds.ringsOnIphone(durationMs: durationMs(of: url)) {
        NSLog("CritAlarmSound: not_published_too_long name=%@", name)
        return nil
      }
    }
    return name
  }

  /// Hands the notification extension the current choices. The extension
  /// runs in its own process and cannot read the app's defaults, so it reads
  /// these from the app group instead.
  ///
  /// `shared_preferences` on iOS writes into the standard user defaults with a
  /// `flutter.` prefix, which is where the choices are read from here. No
  /// choice, or a sound too long for iOS to play, publishes nothing, so the
  /// push keeps its own `alarm.caf`.
  @discardableResult
  static func publishToExtension() -> Bool {
    guard let shared = SharedSounds.groupDefaults else { return false }
    let defaults = UserDefaults.standard
    let defaultFile = defaults.string(forKey: "flutter.alarm_sound_default")
      .flatMap(ringableFileName(forSoundId:))
    var perTopic: [String: String] = [:]
    if let raw = defaults.string(forKey: "flutter.alarm_sound_per_topic"),
       let data = raw.data(using: .utf8),
       let map = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
      for (topic, id) in map {
        if let name = ringableFileName(forSoundId: id) { perTopic[topic] = name }
      }
    }
    SharedSounds.publish(defaultFile: defaultFile, perTopicFiles: perTopic, to: shared)
    NSLog("CritAlarmSound: assignments_published topics=%d", perTopic.count)
    return true
  }
}

/// Ramps the first and last part of a cut from silence and back, so the clip
/// starts and stops without a click. Expects mono Int16 buffers, which is what
/// `convertToCAF` asks the reader for.
struct ClipFade {
  let start: Double
  let end: Double
  let seconds: Double

  init(range: CMTimeRange, seconds: Double) {
    start = CMTimeGetSeconds(range.start)
    end = CMTimeGetSeconds(range.end)
    self.seconds = seconds
  }

  func gain(at time: Double) -> Double {
    min(1, max(0, (time - start) / seconds), max(0, (end - time) / seconds))
  }

  /// A copy of [buffer] with the gain applied, or [buffer] itself when none
  /// of it falls inside a fade.
  func apply(to buffer: CMSampleBuffer) -> CMSampleBuffer {
    let startTime = CMSampleBufferGetPresentationTimeStamp(buffer)
    let frames = CMSampleBufferGetNumSamples(buffer)
    guard frames > 0,
          let format = CMSampleBufferGetFormatDescription(buffer),
          let stream = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
          stream.mChannelsPerFrame == 1, stream.mBitsPerChannel == 16,
          let block = CMSampleBufferGetDataBuffer(buffer)
    else { return buffer }
    let rate = stream.mSampleRate
    let first = CMTimeGetSeconds(startTime)
    let last = first + Double(frames) / rate
    if first >= start + seconds && last <= end - seconds { return buffer }

    let byteCount = CMBlockBufferGetDataLength(block)
    var samples = [Int16](repeating: 0, count: byteCount / 2)
    let copied = samples.withUnsafeMutableBytes { raw in
      CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: byteCount, destination: raw.baseAddress!)
    }
    guard copied == kCMBlockBufferNoErr else { return buffer }
    for i in samples.indices {
      let g = gain(at: first + Double(i) / rate)
      if g < 1 { samples[i] = Int16(Double(samples[i]) * g) }
    }

    var faded: CMBlockBuffer?
    guard CMBlockBufferCreateWithMemoryBlock(
      allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount,
      blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
      dataLength: byteCount, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &faded
    ) == kCMBlockBufferNoErr, let faded else { return buffer }
    let written = samples.withUnsafeBytes { raw in
      CMBlockBufferReplaceDataBytes(
        with: raw.baseAddress!, blockBuffer: faded, offsetIntoDestination: 0, dataLength: byteCount
      )
    }
    guard written == kCMBlockBufferNoErr else { return buffer }
    var out: CMSampleBuffer?
    let status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
      allocator: kCFAllocatorDefault, dataBuffer: faded, formatDescription: format,
      sampleCount: frames, presentationTimeStamp: startTime, packetDescriptions: nil,
      sampleBufferOut: &out
    )
    guard status == noErr, let out else { return buffer }
    return out
  }
}

/// Plays one sound in the picker.
///
/// `.playback` rather than `.ambient`, so a preview is audible with the ring
/// switch on silent, which is the point of an alarm sound.
final class SoundPreviewPlayer: NSObject, AVAudioPlayerDelegate {
  static let shared = SoundPreviewPlayer()

  private var player: AVAudioPlayer?

  /// Stops a clip preview at the end of its range. Invalidated in [stop].
  private var stopTimer: Timer?

  /// The path Dart asked to play, handed back when it ends so Dart can tell
  /// a late event for an old preview from one for the current preview.
  private var playingPath: String?

  /// Called on the main thread with the playing path when a preview stops
  /// without Dart asking: it played to the end, or a call or another app took
  /// the audio.
  var onEnded: ((String) -> Void)?

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(interrupted(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }

  @objc private func interrupted(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
    DispatchQueue.main.async { self.end() }
  }

  private func end() {
    guard player != nil else { return }
    let path = playingPath ?? ""
    stop()
    onEnded?(path)
  }

  /// Plays [url] once. With [from] and [to] (seconds), plays only that part,
  /// for a file open in the cropper.
  func start(url: URL, path: String, from: TimeInterval? = nil, to: TimeInterval? = nil) -> Bool {
    stop()
    playingPath = path
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      let player = try AVAudioPlayer(contentsOf: url)
      player.delegate = self
      // One pass. The picker is not the alarm.
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
      NSLog("CritAlarmSound: preview_failed url=%@ error=%@", url.path, "\(error)")
      return false
    }
  }

  func stop() {
    stopTimer?.invalidate()
    stopTimer = nil
    player?.stop()
    player = nil
    playingPath = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    end()
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    end()
  }
}

extension AppDelegate {
  /// Wires `app.critalarm/sound`. Called from the engine setup.
  func attachSoundChannel(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: "app.critalarm/sound", binaryMessenger: messenger)
    SoundPreviewPlayer.shared.onEnded = { [weak channel] path in
      channel?.invokeMethod("previewEnded", arguments: ["path": path])
    }
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "capabilities":
        result([
          // Answered by the measurement in
          // docs/specs/remote-alarm-ios-spike.md.
          "user_sounds_ring_alarm": AlarmSoundPolicy.librarySoundsRingAlarm,
          "bundled_sounds_ring_alarm": AlarmSoundPolicy.librarySoundsRingAlarm,
          "can_import_sounds": true,
        ])
      case "prepareBundledSounds":
        let assets = args["assets"] as? [String] ?? []
        SoundLibrary.inBackground(result) { SoundLibrary.prepare(assets: assets) }
      case "startPreview":
        guard let path = args["path"] as? String else { result(false); return }
        let isAsset = args["is_asset"] as? Bool ?? false
        let url = isAsset
          ? SoundLibrary.bundleURL(forFlutterAsset: path)
          : SoundLibrary.localURL(forStoredPath: path)
        guard let url else { result(false); return }
        let from = (args["start_ms"] as? Int).map { TimeInterval($0) / 1000 }
        let to = (args["end_ms"] as? Int).map { TimeInterval($0) / 1000 }
        result(SoundPreviewPlayer.shared.start(url: url, path: path, from: from, to: to))
      case "stopPreview":
        SoundPreviewPlayer.shared.stop()
        result(true)
      case "probeDuration":
        guard let path = args["path"] as? String else { result(0); return }
        SoundLibrary.inBackground(result) {
          SoundLibrary.durationMs(of: URL(fileURLWithPath: path))
        }
      case "importSound":
        guard let source = args["source_path"] as? String,
              let id = args["id"] as? String else { result(nil); return }
        let startMs = args["start_ms"] as? Int
        let endMs = args["end_ms"] as? Int
        SoundLibrary.inBackground(result) {
          SoundLibrary.importSound(
            source: URL(fileURLWithPath: source), id: id, startMs: startMs, endMs: endMs
          )
        }
      case "readPeaks":
        guard let path = args["path"] as? String else { result([Double]()); return }
        let isAsset = args["is_asset"] as? Bool ?? false
        let count = args["count"] as? Int ?? 0
        let token = args["token"] as? String
        SoundLibrary.inBackground(result) {
          // Dart's stored path can point at an old container, so user sounds
          // are found by file name, the same way the preview finds them.
          let url = isAsset
            ? SoundLibrary.bundleURL(forFlutterAsset: path)
            : SoundLibrary.localURL(forStoredPath: path)
          guard let url else { return [Double]() }
          return SoundLibrary.readPeaks(url: url, count: count, token: token)
        }
      case "cancelPeaks":
        // Answered at once, not queued: the read it stops is what holds the
        // queue.
        if let token = args["token"] as? String { SoundLibrary.cancelPeaks(token: token) }
        result(nil)
      case "deleteSound":
        guard let path = args["path"] as? String else { result(false); return }
        SoundLibrary.inBackground(result) {
          (try? FileManager.default.removeItem(at: SoundLibrary.localURL(forStoredPath: path))) != nil
        }
      case "publishSoundAssignments":
        SoundLibrary.inBackground(result) { SoundLibrary.publishToExtension() }
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

/// Two items, not one (api.md §4.2). Dart names the item it wants on every
/// call: the service, and whether that item syncs through iCloud. The account
/// item syncs so every handset on one Apple ID lands on the same account; the
/// device item does not, so each handset keeps its own device id.
///
/// `kSecAttrSynchronizable` is part of the lookup, so an item written when the
/// flag was true is invisible to a read asking for false. Dart passes "any" to
/// find both, which is how the old single item is still reachable after the
/// split. Updates never delete the old secret.
enum DeviceIdentityKeychain {
  /// What `synchronizable` may be on a call from Dart: true, false, or the
  /// string "any", which reads a synced and an unsynced copy at once.
  static func syncAttribute(_ value: Any?) -> Any? {
    if let flag = value as? Bool { return flag as NSNumber }
    if let name = value as? String, name == "any" { return kSecAttrSynchronizableAny }
    return nil
  }

  /// The query that names one Keychain item. Nil when Dart asked for an item
  /// this build does not know how to address.
  static func itemQuery(_ arguments: Any?) -> [String: Any]? {
    guard let args = arguments as? [String: Any],
          let service = args["service"] as? String,
          let sync = syncAttribute(args["synchronizable"]) else { return nil }
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "identity",
      kSecAttrSynchronizable as String: sync,
    ]
    if let group = NseCredentials.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }
    return query
  }

  static func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    guard var query = itemQuery(call.arguments) else {
      result(FlutterError(code: "bad_args", message: "Keychain item required", details: nil))
      return
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
      guard let args = call.arguments as? [String: Any],
            let value = args["value"] as? String,
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
    case "delete":
      let status = SecItemDelete(query as CFDictionary)
      // Nothing there is the outcome the caller wanted anyway.
      guard status == errSecSuccess || status == errSecItemNotFound else {
        result(FlutterError(code: "keychain_delete", message: "Identity delete failed", details: status))
        return
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - Settings channel

/// What the app can read back about how iOS will deliver its notifications,
/// and how to send the user to the switch that changes it.
///
/// Full-screen intent and battery optimisation are Android ideas. They answer
/// true here so one shared Dart repository can ask about them either way.
extension AppDelegate {
  static func handleSettingsCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkNotificationPermission":
      readSettings(result) { settings in
        settings.authorizationStatus == .authorized
          || settings.authorizationStatus == .provisional
      }

    case "checkTimeSensitive":
      // The one switch that quietly breaks an alarm app: with it off, iOS
      // holds a time-sensitive page for the next Scheduled Summary.
      readSettings(result) { settings in
        switch settings.timeSensitiveSetting {
        case .enabled: return true
        case .disabled: return false
        // .notSupported means this iOS has no such switch, so nothing is wrong.
        default: return true
        }
      }

    case "checkScheduledSummary":
      readSettings(result) { $0.scheduledDeliverySetting == .enabled }

    case "checkFullScreenIntent", "checkBatteryOptimization":
      result(true)

    case "openNotificationSettings":
      openNotificationSettings(result)

    case "openFullScreenIntentSettings", "openBatteryOptimizationSettings",
         "openAppSettings":
      openAppSettings(result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func readSettings(
    _ result: @escaping FlutterResult,
    _ read: @escaping (UNNotificationSettings) -> Bool
  ) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let value = read(settings)
      DispatchQueue.main.async { result(value) }
    }
  }

  /// iOS 16 and up opens this app's own notification page. Older versions only
  /// reach the app's settings page, which is one tap away from the same thing.
  private static func openNotificationSettings(_ result: @escaping FlutterResult) {
    if #available(iOS 16.0, *),
       let url = URL(string: UIApplication.openNotificationSettingsURLString) {
      open(url, result)
      return
    }
    openAppSettings(result)
  }

  private static func openAppSettings(_ result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    open(url, result)
  }

  private static func open(_ url: URL, _ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }
  }
}
