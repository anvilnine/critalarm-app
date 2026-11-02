import XCTest

/// The native strings lookup: the language picked in the app, else the
/// phone's, else the English compiled in. The pick is written to the app
/// group by `setAppLocale` (AppDelegate), and every extension reads it.
final class NativeL10nTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "NativeL10nTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        NativeL10n.write(tag: nil, to: NativeL10n.groupDefaults)
        super.tearDown()
    }

    /// A bundle with no `Native` table, like an extension built without it.
    private var bare: Bundle { Bundle(for: NativeL10nTests.self) }

    func testNoPickIsEnglishOnEveryString() {
        for id in NativeText.allCases {
            XCTAssertEqual(NativeL10n.text(id, [:], tag: nil, bundle: .main), id.english, id.rawValue)
        }
    }

    func testABundleWithoutTheTableStillShowsEnglishNeverAKey() {
        for id in NativeText.allCases {
            XCTAssertEqual(NativeL10n.text(id, [:], tag: "de", bundle: bare), id.english, id.rawValue)
        }
    }

    func testALanguageThatIsNotShippedFallsBackToThePhone() {
        XCTAssertEqual(NativeL10n.text(.alarmStop, [:], tag: "fr", bundle: .main), "Stop")
        XCTAssertEqual(NativeL10n.text(.alarmStop, [:], tag: "en", bundle: .main), "Stop")
    }

    func testAShippedLanguageUsesItsOwnWords() {
        XCTAssertEqual(NativeL10n.text(.alarmStop, [:], tag: "de", bundle: .main), "Stopp")
    }

    func testPlaceholdersAreFilledByName() {
        XCTAssertEqual(
            NativeL10n.text(.cardSilenced, ["seconds": "30"], tag: nil, bundle: .main),
            "Stopped. Rings again in 30 s. Tap I'm up to end it."
        )
        XCTAssertEqual(
            NativeL10n.text(.contentCriticalAlertOn, ["topic": "prod"], tag: nil, bundle: .main),
            "Critical alert on prod"
        )
    }

    func testAroundSplitsTheWordsAroundTheTimer() {
        let (before, after) = NativeL10n.around("Opened {time} ago", placeholder: "time")
        XCTAssertEqual(before, "Opened ")
        XCTAssertEqual(after, " ago")
        let open = NativeL10n.around(NativeText.cardOpenFor.english, placeholder: "time")
        XCTAssertEqual(open.before, "Open for ")
        XCTAssertEqual(open.after, "")
    }

    func testThePseudoLocaleMatchesTheDartGenerator() {
        // tool/l10n_pseudo.dart gives these for the same English.
        XCTAssertEqual(NativeL10n.text(.alarmOpenApp, [:], tag: "en-XA", bundle: .main), "[Öþéñ Crit Alarm~~~~]")
        XCTAssertEqual(NativeL10n.text(.alarmStop, [:], tag: "en-XA", bundle: .main), "[Šţöþ]")
        XCTAssertEqual(NativeL10n.text(.actionImUp, [:], tag: "en-XA", bundle: .main), "[Î'ḿ ûþ~]")
        XCTAssertEqual(
            NativeL10n.text(.cardSilencedShort, ["seconds": "30"], tag: "en-XA", bundle: .main),
            "[Šţöþþéð. Ŕîñĝš åĝåîñ îñ 30 š.~~~~~~~~~~~~~]"
        )
    }

    func testSystemDefaultAfterAPickGoesBackToThePhone() {
        NativeL10n.write(tag: "en-XA", to: defaults)
        XCTAssertEqual(NativeL10n.pickedTag(in: defaults), "en-XA")
        XCTAssertEqual(
            NativeL10n.text(.alarmStop, [:], tag: NativeL10n.pickedTag(in: defaults), bundle: .main),
            "[Šţöþ]"
        )
        NativeL10n.write(tag: nil, to: defaults)
        XCTAssertNil(NativeL10n.pickedTag(in: defaults))
        XCTAssertEqual(
            NativeL10n.text(.alarmStop, [:], tag: NativeL10n.pickedTag(in: defaults), bundle: .main),
            "Stop"
        )
        NativeL10n.write(tag: "", to: defaults)
        XCTAssertNil(NativeL10n.pickedTag(in: defaults))
    }

    func testTheServerPlaceholderIsRebuiltAndAnyOtherBodyIsLeftAlone() {
        let server = "Critical alert on prod-db \u{2014} open to see details"
        XCTAssertEqual(server, IncidentContentFetcher.serverPlaceholder.replacingOccurrences(of: "{topic}", with: "prod-db"))
        XCTAssertEqual(IncidentContentFetcher.localizedPlaceholder(server), "Critical alert on prod-db. Open to see details.")
        XCTAssertEqual(
            IncidentContentFetcher.localizedPlaceholder("Critical alert on prod-db. Open to see details."),
            "Critical alert on prod-db. Open to see details."
        )
        XCTAssertEqual(
            IncidentContentFetcher.localizedPlaceholder("Critical alert on prod-db, open to see details"),
            "Critical alert on prod-db, open to see details"
        )
        XCTAssertEqual(IncidentContentFetcher.localizedPlaceholder("db01 is down"), "db01 is down")

        NativeL10n.write(tag: "en-XA", to: NativeL10n.groupDefaults)
        let pseudo = IncidentContentFetcher.localizedPlaceholder(server)
        XCTAssertTrue(pseudo.hasPrefix("[Çŕîţîçåļ åļéŕţ öñ prod-db"), pseudo)
        XCTAssertEqual(IncidentContentFetcher.localizedPlaceholder("db01 is down"), "db01 is down")
    }
}
