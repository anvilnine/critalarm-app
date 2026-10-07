import Foundation
import Security

/// The relay this device registered with, and the device's own credential.
struct RelayDevice: Equatable {
  let relay: URL
  let deviceId: String
  let deviceToken: String

  /// Where Dart keeps the session: `base|relay|mode|credential`, written by
  /// `SharedPrefsApiSessionStore`. The `flutter.` prefix is what the
  /// shared_preferences plugin puts on every key it owns.
  static let apiSessionKey = "flutter.api_session"

  /// The unsynced Keychain item that holds this handset's `device_id` and
  /// its `dv_` token (api.md §4.2). Dart writes it through
  /// `KeychainDeviceIdentityStore`, as `kSecAttrAccessibleAfterFirstUnlock`,
  /// so it reads while the phone is locked.
  static let identityService = "app.critalarm.device_identity"
  static let identityAccount = "identity"

  /// Built from the saved session and the device item.
  ///
  /// The relay is the second part of the session. The fourth part is the
  /// credential for the user's own server, which on a self-hosted phone is
  /// not the device token, so it is never used here.
  static func parse(apiSession: String?, identityJSON: String?) -> RelayDevice? {
    guard let parts = apiSession?.components(separatedBy: "|"), parts.count == 4,
          let relay = URL(string: parts[1]),
          let scheme = relay.scheme?.lowercased(), scheme == "http" || scheme == "https",
          relay.host != nil,
          let data = identityJSON?.data(using: .utf8),
          let identity = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let deviceId = identity["device_id"] as? String,
          !deviceId.trimmingCharacters(in: .whitespaces).isEmpty,
          let deviceToken = identity["device_token"] as? String,
          !deviceToken.trimmingCharacters(in: .whitespaces).isEmpty
    else { return nil }
    return RelayDevice(relay: relay, deviceId: deviceId, deviceToken: deviceToken)
  }

  static func read(defaults: UserDefaults = .standard) -> RelayDevice? {
    parse(
      apiSession: defaults.string(forKey: apiSessionKey),
      identityJSON: readIdentity(defaults: defaults)
    )
  }

  private static func readIdentity(defaults: UserDefaults) -> String? {
    #if DEBUG && targetEnvironment(simulator)
    // Debug builds on the simulator only, never on a phone and never in a
    // release build: lets `xcrun simctl push` be answered by an install
    // that has not been through setup, by writing the device item's JSON
    // into the app's preferences.
    if let seeded = defaults.string(forKey: "flutter.dev.weekly_check_identity") {
      return seeded
    }
    #endif
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: identityService,
      kSecAttrAccount as String: identityAccount,
      kSecAttrSynchronizable as String: false as NSNumber,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    if let group = NseCredentials.accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

/// Answers a weekly check push (api.md §5.4) from the background handler,
/// with no Dart running.
///
/// It records when the push arrived and sends the receipt (api.md §4.5):
///
/// ```
/// POST /relay/v1/devices/{device_id}/checks/{check_id}/receipt
/// Authorization: Bearer dv_...
/// { "attempt":1, "received_at":1759800004 }
/// ```
///
/// That is all. It shows nothing, plays nothing, starts no Live Activity and
/// schedules no alarm, and it shares no state with incident pushes: its one
/// preference key is read by the weekly check in Dart and by nothing else.
/// A receipt that does not get out is tried a small number of times and then
/// dropped. Nothing is kept for later.
///
/// `answer` does no work on the caller's thread. The caller is the app
/// delegate, on the main thread, where an alarm push is handled too. The
/// Keychain read, the record and the request all run on `queue`, a serial
/// queue of this type's own that nothing on the incident path uses. Every
/// change to the record goes through it, so two of them never overwrite
/// each other's fields.
enum WeeklyCheckResponder {
  struct Answer: Equatable {
    let counted: Bool
    let nextDueAt: Int?
    let noticeAfter: Int?
  }

  /// Read by `SharedPrefsWeeklyCheckStore` in Dart.
  static let arrivalKey = "flutter.weekly_check.native"

  /// The wait before each try. Three tries, then the receipt is dropped.
  /// iOS gives a background push about thirty seconds, and the worst case
  /// here is the waits plus three timeouts, which stays inside it.
  static let tryDelays: [TimeInterval] = [0, 2, 4]
  static let timeout: TimeInterval = 6

  /// The longest the caller waits to hear back. The tries end before this
  /// by themselves. It is here so iOS always gets its answer.
  static let bound: TimeInterval = 26

  /// Everything the weekly check does natively runs here, one thing at a
  /// time. A wait between tries does not hold it: the wait is scheduled.
  static let queue = DispatchQueue(label: "app.critalarm.weekly-check", qos: .utility)

  /// Hosts a receipt may reach over plain http. Debug builds only: this
  /// machine, and the Android emulator's name for it, so a relay run on
  /// localhost can be answered. A release build has none, so it never sends
  /// the device token over http.
  static var plainHttpHosts: Set<String> {
    #if DEBUG
    return ["127.0.0.1", "localhost", "10.0.2.2"]
    #else
    return []
    #endif
  }

  /// Whether a receipt may go to `relay`. The receipt carries the device
  /// token, so it only ever goes out over https, with the one exception
  /// above.
  static func maySend(to relay: URL, plainHttpHosts: Set<String> = plainHttpHosts) -> Bool {
    switch relay.scheme?.lowercased() {
    case "https":
      return true
    case "http":
      guard let host = relay.host?.lowercased() else { return false }
      return plainHttpHosts.contains(host)
    default:
      return false
    }
  }

  static func makeSession(timeout: TimeInterval = timeout) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    return URLSession(configuration: configuration)
  }

  static func request(device: RelayDevice, push: CheckPush, receivedAt: Int) -> URLRequest {
    let url = device.relay
      .appendingPathComponent("relay")
      .appendingPathComponent("v1")
      .appendingPathComponent("devices")
      .appendingPathComponent(device.deviceId)
      .appendingPathComponent("checks")
      .appendingPathComponent(push.checkId)
      .appendingPathComponent("receipt")
    var body: [String: Any] = ["received_at": receivedAt]
    // `attempt` is a note. It is sent only when the push carried one.
    if let attempt = push.attempt { body["attempt"] = attempt }

    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.httpMethod = "POST"
    request.setValue("Bearer \(device.deviceToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    return request
  }

  /// Whether a try that ended this way is worth another. No answer at all
  /// and a server error are. Any other answer is final: 200 is done, 404
  /// means the relay knows no such check for this device, 401 means the
  /// credential is dead, and asking again changes none of them.
  static func shouldRetry(status: Int?) -> Bool {
    guard let status else { return true }
    return status == 429 || status >= 500
  }

  /// Reads `counted`, `next_due_at` and `notice_after`. Nil when the body is
  /// not that.
  static func parseAnswer(_ data: Data?) -> Answer? {
    guard let data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let counted = json["counted"] as? Bool
    else { return nil }
    func seconds(_ key: String) -> Int? {
      guard let value = (json[key] as? NSNumber)?.intValue, value > 0 else { return nil }
      return value
    }
    return Answer(
      counted: counted,
      nextDueAt: seconds("next_due_at"),
      noticeAfter: seconds("notice_after")
    )
  }

  /// The record Dart reads, with the arrival written into it. What an
  /// earlier receipt answer left there stays until a newer answer replaces
  /// it. The check id is never part of it.
  static func withArrival(existing: String?, receivedAt: Int) -> String {
    var record = decode(existing)
    record["received_at"] = receivedAt
    return encode(record)
  }

  /// The record with a receipt answer written into it. `notice_after` is the
  /// second at which this device will have missed two rounds in a row, and
  /// the phone raises its own notice when its clock passes it (api.md §4.5).
  static func withAnswer(existing: String?, answer: Answer, now: Int) -> String {
    var record = decode(existing)
    if let noticeAfter = answer.noticeAfter {
      record["notice_after"] = noticeAfter
      record["notice_after_seen_at"] = now
    }
    if let nextDueAt = answer.nextDueAt { record["next_due_at"] = nextDueAt }
    return encode(record)
  }

  private static func decode(_ raw: String?) -> [String: Any] {
    guard let data = raw?.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return json
  }

  private static func encode(_ record: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
          let text = String(data: data, encoding: .utf8)
    else { return "{}" }
    return text
  }

  /// Calls `completion` at most once. Only ever touched on `queue`.
  private final class Once {
    private var completion: ((Bool) -> Void)?
    init(_ completion: @escaping (Bool) -> Void) { self.completion = completion }
    func finish(_ sent: Bool) {
      completion?(sent)
      completion = nil
    }
  }

  /// Hands the check to `queue` and returns. There the arrival is recorded
  /// and the receipt sent. `completion` is called exactly once, on `queue`:
  /// true when the relay answered 200, false when the receipt was dropped,
  /// could not be sent, or `bound` passed first. The caller is the background
  /// push handler, and iOS is waiting on its completion handler.
  static func answer(
    _ push: CheckPush,
    readDevice: @escaping () -> RelayDevice? = { RelayDevice.read() },
    makeURLSession: @escaping () -> URLSession = { makeSession() },
    defaults: UserDefaults = .standard,
    delays: [TimeInterval] = tryDelays,
    bound: TimeInterval = bound,
    plainHttpHosts: Set<String> = plainHttpHosts,
    now: @escaping () -> Date = Date.init,
    completion: @escaping (Bool) -> Void
  ) {
    let receivedAt = Int(now().timeIntervalSince1970)
    queue.async {
      let once = Once(completion)
      // The id of the check is never logged.
      NSLog("CritAlarmCheck: check_received attempt=%@", push.attempt.map(String.init) ?? "-")
      defaults.set(
        withArrival(existing: defaults.string(forKey: arrivalKey), receivedAt: receivedAt),
        forKey: arrivalKey
      )

      // Before the first unlock after a restart the Keychain item cannot be
      // read. The arrival above stands, no receipt is sent, and nothing in
      // the record says one was.
      guard let device = readDevice() else {
        NSLog("CritAlarmCheck: check_receipt_skipped reason=no_credentials")
        once.finish(false)
        return
      }
      guard maySend(to: device.relay, plainHttpHosts: plainHttpHosts) else {
        // The token never goes out over plain http. No host is named here.
        NSLog("CritAlarmCheck: check_receipt_skipped reason=relay_not_https")
        once.finish(false)
        return
      }
      queue.asyncAfter(deadline: .now() + bound) { once.finish(false) }
      let request = request(device: device, push: push, receivedAt: receivedAt)
      send(request, try: 0, delays: delays, urlSession: makeURLSession()) { answer, sent in
        if let answer {
          defaults.set(
            withAnswer(
              existing: defaults.string(forKey: arrivalKey),
              answer: answer,
              now: Int(now().timeIntervalSince1970)
            ),
            forKey: arrivalKey
          )
        }
        once.finish(sent)
      }
    }
  }

  /// One try after its wait, then the next. `completion` is called on
  /// `queue`.
  private static func send(
    _ request: URLRequest,
    try index: Int,
    delays: [TimeInterval],
    urlSession: URLSession,
    completion: @escaping (Answer?, Bool) -> Void
  ) {
    guard index < delays.count else {
      NSLog("CritAlarmCheck: check_receipt_dropped")
      completion(nil, false)
      return
    }
    queue.asyncAfter(deadline: .now() + delays[index]) {
      urlSession.dataTask(with: request) { data, response, error in
        let status = error == nil ? (response as? HTTPURLResponse)?.statusCode : nil
        queue.async {
          if status == 200 {
            let answer = parseAnswer(data)
            NSLog(
              "CritAlarmCheck: check_receipt_sent counted=%@ try=%d",
              answer.map { $0.counted ? "yes" : "no" } ?? "-", index + 1
            )
            completion(answer, true)
            return
          }
          if !shouldRetry(status: status) {
            NSLog("CritAlarmCheck: check_receipt_refused status=%d", status ?? 0)
            completion(nil, false)
            return
          }
          // The status alone: an error's text can hold the url, and the url
          // holds the id of the check.
          NSLog("CritAlarmCheck: check_receipt_failed status=%d try=%d", status ?? 0, index + 1)
          send(
            request, try: index + 1, delays: delays, urlSession: urlSession, completion: completion
          )
        }
      }.resume()
    }
  }
}
