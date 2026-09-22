import XCTest

final class DebugStateRuleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_757_462_400)

    func testDerivesEveryDocumentedPhoneState() {
        let cases: [(DebugStateRule.Input, String)] = [
            (.init(live: true), "ringing"),
            (.init(closed: true), "closed"),
            (.init(acknowledged: true, inLocalAckedSet: true), "acked here"),
            (.init(acknowledged: true), "acked elsewhere"),
            (.init(active: true, rearmPending: true), "silenced"),
            (.init(ringUntil: now.addingTimeInterval(-1)), "expired"),
            (.init(), "unknown"),
        ]

        for (input, expected) in cases {
            XCTAssertEqual(DebugStateRule.phoneState(input, now: now), expected)
        }
    }

    func testEarlierStateRowsWinOverLaterRows() {
        XCTAssertEqual(
            DebugStateRule.phoneState(
                .init(
                    live: true,
                    closed: true,
                    acknowledged: true,
                    inLocalAckedSet: true,
                    active: true,
                    rearmPending: true,
                    ringUntil: now.addingTimeInterval(-1)
                ),
                now: now
            ),
            "ringing"
        )
    }
}
