import UserNotifications
import XCTest

/// What the app itself sets up at launch.
final class PushDeliveryTests: XCTestCase {
    /// api.md §5.1: category `INCIDENT` registers one action, `ACK` ("I'm up").
    func testIncidentCategoryCarriesTheAckAction() {
        let loaded = expectation(description: "categories")
        var categories: Set<UNNotificationCategory> = []
        UNUserNotificationCenter.current().getNotificationCategories { found in
            categories = found
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)

        let incident = categories.first { $0.identifier == "INCIDENT" }
        XCTAssertNotNil(incident, "the app registers INCIDENT at launch")
        XCTAssertEqual(incident?.actions.count, 1)
        XCTAssertEqual(incident?.actions.first?.identifier, "ACK")
        XCTAssertEqual(incident?.actions.first?.title, "I'm up")
        XCTAssertTrue(
            incident?.actions.first?.options.contains(.foreground) ?? false,
            "tapping I'm up opens the app"
        )
    }

    /// The shape `AckQueue` in Dart reads back.
    func testAckActionWritesTheQueueEntryDartReads() throws {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AckQueueStore.key)

        AckQueueStore.enqueue(action: "ack", incidentId: "inc_alarmed_proddb")

        let raw = try XCTUnwrap(defaults.string(forKey: AckQueueStore.key))
        let rows = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [[String: Any]]
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["action"] as? String, "ack")
        XCTAssertEqual(rows[0]["incident_id"] as? String, "inc_alarmed_proddb")
        XCTAssertEqual(rows[0]["attempts"] as? Int, 1)
        XCTAssertNotNil(rows[0]["next_attempt_at_ms"])
        XCTAssertEqual(AckQueueStore.pendingCount(), 1)

        defaults.removeObject(forKey: AckQueueStore.key)
    }

    /// The extension logs into the App Group; the app moves the rows onto the
    /// list Dart drains.
    func testPushEventsMoveFromTheAppGroupToDart() throws {
        let group = try XCTUnwrap(PushEventLog.groupDefaults, "group.app.critalarm is missing")
        group.removeObject(forKey: PushEventLog.groupKey)
        UserDefaults.standard.removeObject(forKey: PushEventLog.dartKey)

        PushEventLog.record("push_received", ["kind": "open", "priority": 5])
        XCTAssertEqual(PushEventLog.handOverToDart(), 1)

        let raw = try XCTUnwrap(UserDefaults.standard.string(forKey: PushEventLog.dartKey))
        let rows = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [[String: Any]]
        )
        XCTAssertEqual(rows.last?["name"] as? String, "push_received")
        XCTAssertEqual(rows.last?["kind"] as? String, "open")
        XCTAssertNil(group.array(forKey: PushEventLog.groupKey), "the backlog is cleared")

        UserDefaults.standard.removeObject(forKey: PushEventLog.dartKey)
    }

    @available(iOS 16.2, *)
    func testOpenIncidentIntentRequestsForegroundLaunch() {
        XCTAssertTrue(OpenIncidentIntent.openAppWhenRun, "OpenIncidentIntent must request foreground launch")
    }

    @available(iOS 16.2, *)
    func testOpenIncidentIntentCallsCoordinator() async throws {
        let expectation = expectation(description: "openIncident called")
        await MainActor.run {
            IncidentActivityCoordinator.shared.onOpenIncident = { incidentId in
                XCTAssertEqual(incidentId, "inc_test_123")
                expectation.fulfill()
            }
        }
        let intent = OpenIncidentIntent(incidentId: "inc_test_123")
        _ = try await intent.perform()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // Done on the acknowledged card, and the wake-up challenge flag.
    //
    // The keys are spelled the way Dart writes them. A key spelled
    // differently on this side would read as "never owed", and Done would
    // close.

    /// Two defaults of the test's own: the app's, and the app group's.
    private func challengeDefaults() -> (app: UserDefaults, group: UserDefaults) {
        let appName = "challenge-flag-app-\(UUID().uuidString)"
        let groupName = "challenge-flag-group-\(UUID().uuidString)"
        let app = UserDefaults(suiteName: appName)!
        let group = UserDefaults(suiteName: groupName)!
        addTeardownBlock {
            app.removePersistentDomain(forName: appName)
            group.removePersistentDomain(forName: groupName)
        }
        return (app, group)
    }

    func testDoneClosesWhenNothingWasEverPublished() {
        let (_, group) = challengeDefaults()
        XCTAssertEqual(DoneButton.forCard(topic: "prod-db", shared: group), .closes)
        XCTAssertEqual(DoneButton.forCard(topic: "prod-db", shared: nil), .closes)
    }

    func testDoneOpensTheAppWhileTheTopicsFlagIsSet() {
        let (app, group) = challengeDefaults()
        app.set(true, forKey: "flutter.topic_challenge_owed.prod-db")
        ChallengeFlag.publish(from: app, to: group)
        XCTAssertEqual(DoneButton.forCard(topic: "prod-db", shared: group), .opensApp)
        // Another topic on the same phone still closes.
        XCTAssertEqual(DoneButton.forCard(topic: "nas", shared: group), .closes)
    }

    func testDoneClosesAgainOnceTheFlagIsGone() {
        let (app, group) = challengeDefaults()
        app.set(true, forKey: "flutter.topic_challenge_owed.prod-db")
        ChallengeFlag.publish(from: app, to: group)
        app.removeObject(forKey: "flutter.topic_challenge_owed.prod-db")
        ChallengeFlag.publish(from: app, to: group)
        XCTAssertEqual(DoneButton.forCard(topic: "prod-db", shared: group), .closes)
    }

    func testOnlyARealTrueCountsAsAFlag() {
        let (app, group) = challengeDefaults()
        app.set(false, forKey: "flutter.topic_challenge_owed.off")
        app.set("true", forKey: "flutter.topic_challenge_owed.text")
        app.set(1, forKey: "flutter.topic_challenge_owed.number")
        app.set(true, forKey: "flutter.topic_challenge_owed.")
        // The choice itself is not the flag. Without Pro Dart keeps the
        // choice and sets no flag.
        app.set("type_topic_name", forKey: "flutter.topic_challenge.chosen")
        app.set(true, forKey: "flutter.topic_challenge_owed.db.eu.1")
        XCTAssertEqual(ChallengeFlag.owedTopics(in: app), ["db.eu.1"])
        ChallengeFlag.publish(from: app, to: group)
        for topic in ["off", "text", "number", "chosen", ""] {
            XCTAssertEqual(DoneButton.forCard(topic: topic, shared: group), .closes, topic)
        }
        XCTAssertEqual(DoneButton.forCard(topic: "db.eu.1", shared: group), .opensApp)
    }

    func testACardWithNoTopicCloses() {
        let (app, group) = challengeDefaults()
        app.set(true, forKey: "flutter.topic_challenge_owed.prod-db")
        ChallengeFlag.publish(from: app, to: group)
        XCTAssertEqual(DoneButton.forCard(topic: "", shared: group), .closes)
    }

    /// Whatever the flag says, the two buttons that stop a ring never open
    /// the app first.
    @available(iOS 16.2, *)
    func testStoppingTheRingNeverOpensTheApp() {
        XCTAssertFalse(StopAlarmIntent.openAppWhenRun)
        XCTAssertFalse(AckAlarmIntent.openAppWhenRun)
        XCTAssertFalse(CloseIncidentIntent.openAppWhenRun)
    }
}
