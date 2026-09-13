import Flutter
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

    let alarm = FlutterMethodChannel(name: "app.critalarm/alarm", binaryMessenger: messenger)
    alarm.setMethodCallHandler { [weak self] call, result in
      self?.handleAlarmCall(call, result: result)
    }
    alarmChannel = alarm

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
