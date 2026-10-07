import XCTest

/// Which outside links are handed to Dart, and that they go over whole.
final class AppLinkRuleTests: XCTestCase {
    private func tap(_ raw: String) -> [String: String]? {
        AppLinkRule.tap(from: URL(string: raw)!)
    }

    func testConnectLinkGoesOverWholeFragmentIncluded() {
        let raw = "https://critalarm.app/connect#url=https%3A%2F%2Fa.example&token=tk_x"
        XCTAssertEqual(tap(raw), ["link": raw])
    }

    func testCustomSchemeConnectLinkGoesOverWholeQueryIncluded() {
        let raw = "critalarm://connect?url=https%3A%2F%2Fa.example&token=tk_x"
        XCTAssertEqual(tap(raw), ["link": raw])
    }

    func testOpenLinksGoOverWhole() {
        for raw in [
            "https://critalarm.app/open/topics/prod",
            "https://critalarm.app/open/incidents/inc_1",
            "https://critalarm.app/open/settings/reliability",
            "https://critalarm.app/open/anything/else",
            "https://critalarm.app:443/open/topics/prod",
            "critalarm://open/topics/prod",
            "critalarm://settings/reliability",
        ] {
            XCTAssertEqual(tap(raw), ["link": raw], raw)
        }
    }

    func testTheRestOfTheSiteIsNotTheApps() {
        for raw in [
            "https://critalarm.app/",
            "https://critalarm.app/pricing",
            "https://critalarm.app/open",
            "https://critalarm.app/connect/extra",
            "https://critalarm.app/connected",
            "https://critalarm.app/topics/prod",
        ] {
            XCTAssertNil(tap(raw), raw)
        }
    }

    func testOtherHostsSchemesAndPortsGiveNothing() {
        for raw in [
            "http://critalarm.app/open/topics/prod",
            "https://www.critalarm.app/open/topics/prod",
            "https://critalarm.app.evil.example/open/topics/prod",
            "https://example.com/connect#url=https%3A%2F%2Fa.example&token=tk_x",
            "https://critalarm.app:8443/open/topics/prod",
            "other://connect?url=x&token=y",
        ] {
            XCTAssertNil(tap(raw), raw)
        }
        XCTAssertNil(AppLinkRule.tap(from: URL(fileURLWithPath: "/tmp/connect")))
    }

    /// Widget links never come through this rule, so they route as before.
    func testWidgetLinksAreLeftToWidgetLink() {
        for url in [
            WidgetLink.homeURL,
            WidgetLink.paywallURL,
            WidgetLink.url(topic: "prod"),
            WidgetLink.url(incidentId: "inc_9a8b7c"),
        ] {
            XCTAssertNil(AppLinkRule.tap(from: url), url.absoluteString)
            XCTAssertNotNil(WidgetLink.tap(from: url), url.absoluteString)
        }
        XCTAssertNil(tap("critalarm://topics/a/b"))
    }

    /// A link this rule takes is never also a widget link.
    func testAppLinksAreNotWidgetLinks() {
        for raw in [
            "critalarm://connect?url=https%3A%2F%2Fa.example&token=tk_x",
            "critalarm://open/topics/prod",
            "critalarm://settings/reliability",
            "https://critalarm.app/open/topics/prod",
        ] {
            XCTAssertNil(WidgetLink.tap(from: URL(string: raw)!), raw)
        }
    }

    func testUniversalLinkActivityCarriesItsLink() {
        let raw = "https://critalarm.app/open/topics/prod"
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: raw)
        XCTAssertEqual(AppLinkRule.tap(from: activity), ["link": raw])
    }

    func testOnlyALinkActivityCountsAsHoldingALink() {
        XCTAssertFalse(AppLinkRule.holdsLink(nil))
        let link = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        link.webpageURL = URL(
            string: "https://critalarm.app/connect#url=https%3A%2F%2Fa.example&token=tk_x")
        XCTAssertTrue(AppLinkRule.holdsLink(link))
        let site = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        site.webpageURL = URL(string: "https://critalarm.app/pricing")
        XCTAssertFalse(AppLinkRule.holdsLink(site))
        XCTAssertFalse(AppLinkRule.holdsLink(NSUserActivity(activityType: "app.critalarm.restore")))
    }

    func testOddShapesAreNotForwardedOrAreLeftForDartToRefuse() {
        // Not forwarded at all.
        for raw in [
            "https://critalarm.app./open/topics/prod",
            "https://critalarm.app//open/topics/prod",
            "https://critalarm.app@evil.example/open/topics/prod",
            "https://critalarm.app:8443/connect#url=https%3A%2F%2Fa.example&token=tk_x",
        ] {
            XCTAssertNil(tap(raw), raw)
        }
        // Forwarded whole. The Dart parser opens Home for these.
        for raw in [
            "HTTPS://CritAlarm.APP/open/topics/prod",
            "https://user:pw@critalarm.app/open/topics/prod",
            "https://critalarm.app/open/../connect#url=https%3A%2F%2Fa.example&token=tk_x",
            "https://critalarm.app/open/topics/new",
            "https://critalarm.app/connect?url=https%3A%2F%2Fa.example&token=tk_x",
        ] {
            XCTAssertEqual(tap(raw), ["link": raw], raw)
        }
    }

    func testOtherActivitiesGiveNothing() {
        let handoff = NSUserActivity(activityType: "app.critalarm.something")
        XCTAssertNil(AppLinkRule.tap(from: handoff))
        let empty = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        XCTAssertNil(AppLinkRule.tap(from: empty))
        let elsewhere = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        elsewhere.webpageURL = URL(string: "https://example.com/open/topics/prod")
        XCTAssertNil(AppLinkRule.tap(from: elsewhere))
    }
}
