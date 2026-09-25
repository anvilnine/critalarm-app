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
}
