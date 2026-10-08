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

    // The gate in front of a close the app asks for on behalf of Done.

    private func mayClose(
        acked: Bool = true,
        alarmUnderWay: Bool = false,
        card: IncidentActivityState? = nil,
        widget: String? = nil
    ) -> Bool {
        DoneHandOffRule.mayClose(
            acked: acked, alarmUnderWay: alarmUnderWay, cardState: card, widgetState: widget
        )
    }

    func testAnAckedLiveActivityMayBeClosed() {
        XCTAssertTrue(mayClose(card: .acked))
        XCTAssertTrue(mayClose(card: .acked, widget: WidgetIncident.acked))
    }

    func testTheSnapshotSayingAckedWithNoCardMayBeClosed() {
        XCTAssertTrue(mayClose(card: nil, widget: WidgetIncident.acked))
    }

    func testTheAckedSetAloneWithNoCardAndNoSnapshotEntryIsRefused() {
        // The mark can be stale: nothing that draws Done says acknowledged.
        XCTAssertFalse(mayClose(card: nil, widget: nil))
    }

    func testTheSnapshotSayingOpenIsRefused() {
        XCTAssertFalse(mayClose(card: nil, widget: WidgetIncident.open))
        // Even under a card that still says acked: the extension turned the
        // snapshot on a reopen push the card has not caught up with.
        XCTAssertFalse(mayClose(card: .acked, widget: WidgetIncident.open))
    }

    func testAnIdThisPhoneHasNeverSeenIsRefused() {
        XCTAssertFalse(mayClose(acked: false))
    }

    func testNotInTheAckedSetIsRefusedWhateverTheSurfacesSay() {
        XCTAssertFalse(mayClose(acked: false, card: .acked))
        XCTAssertFalse(mayClose(acked: false, widget: WidgetIncident.acked))
        XCTAssertFalse(mayClose(acked: false, card: .acked, widget: WidgetIncident.acked))
    }

    func testOpenAndRingingAreRefused() {
        XCTAssertFalse(mayClose(acked: false, alarmUnderWay: true))
        XCTAssertFalse(mayClose(acked: false, alarmUnderWay: true, card: .open))
        // Even if every mark says acknowledged.
        XCTAssertFalse(mayClose(alarmUnderWay: true, card: .acked, widget: WidgetIncident.acked))
    }

    func testSilencedButNotAcknowledgedIsRefused() {
        // The card Stop leaves: open, with "I'm up" on it.
        XCTAssertFalse(mayClose(acked: false, alarmUnderWay: true, card: .open))
        XCTAssertFalse(mayClose(acked: false, card: .open, widget: WidgetIncident.open))
        XCTAssertFalse(mayClose(card: .open, widget: WidgetIncident.acked))
    }

    func testRungAgainAfterAnAcknowledgeIsRefused() {
        // With the app force-quit the acked mark survives a reopen. Each
        // of the other signals refuses on its own.
        XCTAssertFalse(mayClose(alarmUnderWay: true, card: .acked))
        XCTAssertFalse(mayClose(card: .open))
        XCTAssertFalse(mayClose(card: nil, widget: WidgetIncident.open))
        XCTAssertFalse(mayClose(card: nil, widget: nil))
    }

    func testAClosedOrExpiredCardIsRefused() {
        XCTAssertFalse(mayClose(card: .closed, widget: WidgetIncident.acked))
        XCTAssertFalse(mayClose(card: .expired))
    }

    func testAStateTheSnapshotDoesNotKnowIsNotAcknowledged() {
        XCTAssertFalse(mayClose(card: nil, widget: "closed"))
        XCTAssertFalse(mayClose(card: nil, widget: ""))
    }

    /// The acked set under the key the app writes, read the way the gate
    /// reads it: marked passes, cleared does not.
    func testTheGateReadsTheAckedSet() {
        let name = "done-gate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        func passes(_ id: String) -> Bool {
            mayClose(
                acked: AckedIncidentStore.contains(incidentId: id, in: defaults), card: .acked
            )
        }
        XCTAssertFalse(passes("inc_1"))
        AckedIncidentStore.mark(incidentId: "inc_1", in: defaults)
        XCTAssertTrue(passes("inc_1"))
        XCTAssertFalse(passes("inc_other"))
        AckedIncidentStore.clear(incidentId: "inc_1", in: defaults)
        XCTAssertFalse(passes("inc_1"))
    }

    /// The snapshot read the way the gate reads it, and turned by the
    /// patch the notification extension applies on a reopen push.
    func testTheGateReadsTheWidgetSnapshot() {
        func topic(_ name: String, _ incident: WidgetIncident?) -> WidgetTopic {
            WidgetTopic(name: name, critical: true, count: incident == nil ? 0 : 1, incident: incident)
        }
        let acked = WidgetIncident(
            id: "inc_1", state: WidgetIncident.acked, title: "Disk full", openedAt: 100, ackedAt: 160
        )
        let ringing = WidgetIncident(
            id: "inc_2", state: WidgetIncident.open, title: "Down", openedAt: 200, ackedAt: nil
        )
        let snapshot = WidgetSnapshot(
            updatedAt: 300, connected: true, openCount: 2,
            topics: [topic("prod", acked), topic("nas", ringing), topic("quiet", nil)]
        )
        XCTAssertEqual(DoneHandOffRule.widgetState(incidentId: "inc_1", in: snapshot), WidgetIncident.acked)
        XCTAssertEqual(DoneHandOffRule.widgetState(incidentId: "inc_2", in: snapshot), WidgetIncident.open)
        XCTAssertNil(DoneHandOffRule.widgetState(incidentId: "inc_unknown", in: snapshot))
        XCTAssertNil(DoneHandOffRule.widgetState(incidentId: "inc_1", in: nil))

        guard case let .changed(reopened) = WidgetPatch.reopened("inc_1").apply(
            to: snapshot, now: Date(timeIntervalSince1970: 400)
        ) else {
            return XCTFail("a reopen changes the snapshot")
        }
        let state = DoneHandOffRule.widgetState(incidentId: "inc_1", in: reopened)
        XCTAssertEqual(state, WidgetIncident.open)
        XCTAssertFalse(mayClose(card: nil, widget: state))
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
