import XCTest

/// The window check the notification extension runs, over plain values.
///
/// No device and no clock: `holdsRing(minuteOfDay:priority:)` takes the minute
/// as a number, so every case here is arithmetic. Keep these in step with
/// `test/core/alarm/quiet_hours_test.dart`, which asserts the same rules on
/// the Dart side.
final class QuietHoursTests: XCTestCase {
    /// 22:00 to 07:00, the window that wraps past midnight.
    private let night = QuietHours(
        isEnabled: true,
        startMinutes: 22 * 60,
        endMinutes: 7 * 60,
        criticalRingsThrough: false
    )

    private func minute(_ hour: Int, _ minute: Int = 0) -> Int {
        hour * 60 + minute
    }

    func testAWrappingWindowHoldsBothSidesOfMidnight() {
        XCTAssertTrue(night.contains(minuteOfDay: minute(23, 30)))
        XCTAssertTrue(night.contains(minuteOfDay: minute(2)))
    }

    func testAWrappingWindowLetsTheDayThrough() {
        XCTAssertFalse(night.contains(minuteOfDay: minute(9)))
        XCTAssertFalse(night.contains(minuteOfDay: minute(21, 59)))
    }

    func testTheStartIsInsideAndTheEndIsOutside() {
        XCTAssertTrue(night.contains(minuteOfDay: minute(22)))
        XCTAssertFalse(night.contains(minuteOfDay: minute(7)))
    }

    func testAWindowInsideOneDayDoesNotWrap() {
        let lunch = QuietHours(
            isEnabled: true,
            startMinutes: minute(12),
            endMinutes: minute(13),
            criticalRingsThrough: false
        )
        XCTAssertTrue(lunch.contains(minuteOfDay: minute(12, 30)))
        XCTAssertFalse(lunch.contains(minuteOfDay: minute(11, 59)))
        XCTAssertFalse(lunch.contains(minuteOfDay: minute(13)))
    }

    func testStartEqualToEndIsAnEmptyWindow() {
        let empty = QuietHours(
            isEnabled: true,
            startMinutes: minute(9),
            endMinutes: minute(9),
            criticalRingsThrough: false
        )
        XCTAssertFalse(empty.contains(minuteOfDay: minute(9)))
        XCTAssertFalse(empty.contains(minuteOfDay: minute(3)))
        XCTAssertFalse(
            empty.holdsRing(minuteOfDay: minute(9), priority: 4)
        )
    }

    func testANonCriticalPageIsHeldInsideTheWindow() {
        XCTAssertTrue(
            night.holdsRing(minuteOfDay: minute(23, 30), priority: 4)
        )
    }

    func testANonCriticalPageRingsOutsideTheWindow() {
        XCTAssertFalse(night.holdsRing(minuteOfDay: minute(9), priority: 4))
    }

    func testQuietHoursOffNeverHoldsAnything() {
        let off = QuietHours(
            isEnabled: false,
            startMinutes: minute(22),
            endMinutes: minute(7),
            criticalRingsThrough: false
        )
        XCTAssertFalse(off.holdsRing(minuteOfDay: minute(23, 30), priority: 4))
    }

    func testACriticalPageRingsThroughWhenTheSwitchIsOn() {
        let ringsThrough = QuietHours(
            isEnabled: true,
            startMinutes: minute(22),
            endMinutes: minute(7),
            criticalRingsThrough: true
        )
        XCTAssertFalse(
            ringsThrough.holdsRing(minuteOfDay: minute(23, 30), priority: 5)
        )
    }

    func testACriticalPageIsHeldWhenTheSwitchIsOff() {
        XCTAssertTrue(
            night.holdsRing(minuteOfDay: minute(23, 30), priority: 5)
        )
    }

    func testNothingStoredFallsBackToTheSameDefaultsAsDart() {
        let empty = UserDefaults(suiteName: "quiet-hours-tests-empty")!
        for key in [
            QuietHours.enabledKey, QuietHours.startKey,
            QuietHours.endKey, QuietHours.criticalRingsKey,
        ] {
            empty.removeObject(forKey: key)
        }

        let window = QuietHours.read(from: empty)

        XCTAssertTrue(window.isEnabled)
        XCTAssertEqual(window.startMinutes, 22 * 60)
        XCTAssertEqual(window.endMinutes, 7 * 60)
        XCTAssertTrue(window.criticalRingsThrough)
    }

    func testWhatIsWrittenIsWhatIsRead() {
        let store = UserDefaults(suiteName: "quiet-hours-tests-round-trip")!
        let written = QuietHours(
            isEnabled: true,
            startMinutes: minute(1, 15),
            endMinutes: minute(6, 45),
            criticalRingsThrough: false
        )

        QuietHours.write(written, to: store)
        let read = QuietHours.read(from: store)

        XCTAssertEqual(read.isEnabled, written.isEnabled)
        XCTAssertEqual(read.startMinutes, written.startMinutes)
        XCTAssertEqual(read.endMinutes, written.endMinutes)
        XCTAssertEqual(read.criticalRingsThrough, written.criticalRingsThrough)
    }
}
