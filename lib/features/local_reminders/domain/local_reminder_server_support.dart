/// What the server can do for reminders that the app cannot ask it about.
abstract final class LocalReminderServerSupport {
  /// `POST /v1/test` answers 409 on a topic that is not critical (api.md
  /// 3.3), and `/v1/info` has no field that says otherwise. The confirm
  /// screen lists critical topics only until `server-test-normal-topics.md`
  /// ships a field for it; then read that field here instead.
  static const bool testsNormalTopics = false;
}
