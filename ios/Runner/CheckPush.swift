import Foundation

/// One weekly check push, api.md §5.4.
///
/// `aps` holds `content-available` and nothing else. Beside it sit `kind`,
/// which is `check`, the `check_id` the receipt names, and the `attempt` of
/// the round, 1 to 3. There is no server, no incident, no title and no body,
/// and the push shows nothing.
///
/// `check_id` is in the push and nowhere else, so it never goes in a log
/// line. `description` leaves it out for that reason.
struct CheckPush: CustomStringConvertible {
  static let kind = "check"

  let checkId: String
  let attempt: Int?

  init(checkId: String, attempt: Int?) {
    self.checkId = checkId
    self.attempt = attempt
  }

  /// Nil for every push that is not a weekly check, which is every incident
  /// push. A check with no `check_id` cannot be answered, so it is nil too
  /// and falls through to where an unknown push is ignored.
  init?(payload: [AnyHashable: Any]) {
    guard payload["kind"] as? String == Self.kind,
          let id = payload["check_id"] as? String, !id.isEmpty
    else { return nil }
    checkId = id
    attempt = (payload["attempt"] as? NSNumber)?.intValue
      ?? Int(payload["attempt"] as? String ?? "")
  }

  var description: String {
    "CheckPush(attempt: \(attempt.map(String.init) ?? "-"))"
  }
}
