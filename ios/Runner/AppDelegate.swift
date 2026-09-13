import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The `INCIDENT` category in api.md §5.1, with its single `ACK` action.
  static let incidentCategory = "INCIDENT"
  static let ackAction = "ACK"

  private var pushChannel: FlutterMethodChannel?

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
}
