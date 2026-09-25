import XCTest

/// The `critalarm://` links widgets open, and the tap maps they turn into.
final class WidgetLinkTests: XCTestCase {
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
