import XCTest

/// The `critalarm://` links widgets open, and the tap maps they turn into.
final class WidgetLinkTests: XCTestCase {
    func testPaywallRoundTrip() {
        XCTAssertEqual(WidgetLink.paywallURL.absoluteString, "critalarm://paywall")
        XCTAssertEqual(WidgetLink.tap(from: WidgetLink.paywallURL), ["open": "paywall"])
    }

    func testTopicRoundTrip() {
        let url = WidgetLink.url(topic: "prod")
        XCTAssertEqual(url.absoluteString, "critalarm://topics/prod")
        XCTAssertEqual(WidgetLink.tap(from: url), ["topic": "prod"])
    }

    func testIncidentRoundTrip() {
        let url = WidgetLink.url(incidentId: "inc_9a8b7c")
        XCTAssertEqual(url.absoluteString, "critalarm://incidents/inc_9a8b7c")
        XCTAssertEqual(WidgetLink.tap(from: url), ["incident_id": "inc_9a8b7c"])
    }

    // Done on a widget, while the topic owes a wake-up challenge.

    private func group(owing topics: [String]) -> UserDefaults {
        let name = "widget-link-done-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(topics, forKey: ChallengeFlag.groupKey)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDoneIsALinkToTheIncidentWhileTheFlagIsSet() {
        let url = WidgetLink.doneURL(
            incidentId: "inc_9a8b7c", topic: "prod", shared: group(owing: ["prod"])
        )
        XCTAssertEqual(url?.absoluteString, "critalarm://incidents/inc_9a8b7c")
        XCTAssertEqual(url.flatMap(WidgetLink.tap(from:)), ["incident_id": "inc_9a8b7c"])
    }

    func testDoneIsNoLinkWhileTheFlagIsNotSet() {
        XCTAssertNil(WidgetLink.doneURL(incidentId: "inc_1", topic: "prod", shared: group(owing: [])))
        XCTAssertNil(WidgetLink.doneURL(incidentId: "inc_1", topic: "prod", shared: group(owing: ["nas"])))
        XCTAssertNil(WidgetLink.doneURL(incidentId: "inc_1", topic: "prod", shared: nil))
    }

    func testTheSmallWidgetGoesWhereDoneGoes() {
        let owing = group(owing: ["prod"])
        XCTAssertEqual(
            WidgetLink.smallTopicURL(topic: "prod", ackedIncidentId: "inc_1", shared: owing).absoluteString,
            "critalarm://incidents/inc_1"
        )
        // Nothing acknowledged on it, or nothing owed: the topic, as before.
        XCTAssertEqual(
            WidgetLink.smallTopicURL(topic: "prod", ackedIncidentId: nil, shared: owing).absoluteString,
            "critalarm://topics/prod"
        )
        XCTAssertEqual(
            WidgetLink.smallTopicURL(topic: "prod", ackedIncidentId: "inc_1", shared: group(owing: [])).absoluteString,
            "critalarm://topics/prod"
        )
    }

    func testHomeRoundTrip() {
        XCTAssertEqual(WidgetLink.homeURL.absoluteString, "critalarm://home")
        XCTAssertEqual(WidgetLink.tap(from: WidgetLink.homeURL), ["open": "home"])
    }

    func testNamesWithSpacesAndSlashesSurvive() {
        let url = WidgetLink.url(topic: "my topic/x")
        XCTAssertEqual(url.absoluteString, "critalarm://topics/my%20topic%2Fx")
        XCTAssertEqual(WidgetLink.tap(from: url), ["topic": "my topic/x"])
    }

    func testOtherSchemesAndFilesGiveNothing() {
        XCTAssertNil(WidgetLink.tap(from: URL(string: "https://critalarm.app/topics/prod")!))
        XCTAssertNil(WidgetLink.tap(from: URL(fileURLWithPath: "/tmp/topics/prod")))
    }

    func testOtherShapesGiveNothing() {
        for raw in [
            "critalarm://topics",
            "critalarm://topics/",
            "critalarm://topics/a/b",
            "critalarm://settings/x",
            "critalarm://home/extra",
        ] {
            XCTAssertNil(WidgetLink.tap(from: URL(string: raw)!), raw)
        }
    }
}
