import XCTest

@testable import Runner

private final class MemoryBrightnessStore: BrightnessStore {
    var saved: Float?
}

final class RingScreenRuleTests: XCTestCase {
    // MARK: What to do

    private func plan(
        ringing: Bool = true,
        active: Bool = true,
        bright: Bool = true,
        vibrate: Bool = true,
        supported: Bool = true
    ) -> RingScreenRule.Plan {
        RingScreenRule.plan(
            isRinging: ringing,
            isActive: active,
            brightSwitchOn: bright,
            vibrateSwitchOn: vibrate,
            hapticsSupported: supported
        )
    }

    func testBothSwitchesOnAndRingingBrightensAndVibrates() {
        XCTAssertEqual(plan(), .init(brighten: true, haptics: true))
    }

    func testNothingRingingDoesNothing() {
        XCTAssertEqual(plan(ringing: false), .init(brighten: false, haptics: false))
    }

    func testAnAppNotInFrontDoesNothing() {
        XCTAssertEqual(plan(active: false), .init(brighten: false, haptics: false))
    }

    func testEachSwitchOnlyTurnsOffItsOwnEffect() {
        XCTAssertEqual(plan(bright: false), .init(brighten: false, haptics: true))
        XCTAssertEqual(plan(vibrate: false), .init(brighten: true, haptics: false))
    }

    func testAPhoneWithoutHapticsStillBrightens() {
        XCTAssertEqual(plan(supported: false), .init(brighten: true, haptics: false))
    }

    func testASwitchNeverSetReadsAsOn() {
        XCTAssertTrue(RingScreenRule.switchIsOn(nil))
        XCTAssertTrue(RingScreenRule.switchIsOn(true))
        XCTAssertFalse(RingScreenRule.switchIsOn(false))
        XCTAssertTrue(RingScreenRule.switchIsOn("off"))
    }

    func testTheKeysAreTheOnesDartWrites() {
        XCTAssertEqual(RingScreenRule.brightScreenKey, "flutter.ring_bright_screen")
        XCTAssertEqual(RingScreenRule.vibrateKey, "flutter.ring_vibrate")
    }

    // MARK: Which pattern

    func testASoundWithAPatternUsesIt() {
        let name = RingScreenRule.patternName(soundFile: "classic_siren.caf") { $0 == "classic_siren" }
        XCTAssertEqual(name, "classic_siren")
    }

    func testNoChoiceRingsTheDefaultSoundAndUsesItsPattern() {
        XCTAssertEqual(RingScreenRule.patternName(soundFile: nil) { $0 == "alarm" }, "alarm")
        XCTAssertEqual(RingScreenRule.patternName(soundFile: "") { $0 == "alarm" }, "alarm")
    }

    func testAPackOrOwnSoundGetsTheSteadyPattern() {
        XCTAssertEqual(
            RingScreenRule.patternName(soundFile: "pack_library_buzzer_1.caf") { $0 == "classic_siren" },
            RingScreenRule.steadyPattern
        )
        XCTAssertEqual(
            RingScreenRule.patternName(soundFile: "own_3f2a.caf") { _ in false },
            RingScreenRule.steadyPattern
        )
    }

    func testPatternLengthIsTheEndOfTheLastEvent() {
        let ahap: [String: Any] = [
            "Pattern": [
                ["Event": ["Time": 0.5, "EventDuration": 1.0]],
                ["Event": ["Time": 3.0, "EventDuration": 0.25]],
                ["Event": ["Time": 2.0, "EventDuration": 0.5]],
            ]
        ]
        XCTAssertEqual(RingScreenRule.patternLength(ahap: ahap) ?? 0, 3.25, accuracy: 0.0001)
        XCTAssertNil(RingScreenRule.patternLength(ahap: ["Pattern": []]))
    }

    // MARK: Brightness comes back

    func testTheScreenGoesToFullAndTheOldValueIsSavedFirst() {
        let store = MemoryBrightnessStore()
        let ledger = BrightnessLedger(store: store)
        XCTAssertEqual(ledger.raise(current: 0.2), 1)
        XCTAssertEqual(store.saved, 0.2)
        XCTAssertTrue(ledger.isRaised)
    }

    func testBrightnessIsRestoredWhenTheScreenCloses() {
        let ledger = BrightnessLedger(store: MemoryBrightnessStore())
        _ = ledger.raise(current: 0.35)
        XCTAssertEqual(ledger.restore(current: 1), 0.35)
        XCTAssertFalse(ledger.isRaised)
    }

    func testBrightnessIsRestoredWhenTheAppGoesToTheBackground() {
        let ledger = BrightnessLedger(store: MemoryBrightnessStore())
        let store = RingScreenRule.plan(
            isRinging: true, isActive: true, brightSwitchOn: true, vibrateSwitchOn: true,
            hapticsSupported: true
        )
        XCTAssertTrue(store.brighten)
        _ = ledger.raise(current: 0.1)
        let inBackground = RingScreenRule.plan(
            isRinging: true, isActive: false, brightSwitchOn: true, vibrateSwitchOn: true,
            hapticsSupported: true
        )
        XCTAssertFalse(inBackground.brighten)
        XCTAssertEqual(ledger.restore(current: 1), 0.1)
    }

    func testRaisingTwiceKeepsThePersonsOwnValue() {
        let ledger = BrightnessLedger(store: MemoryBrightnessStore())
        _ = ledger.raise(current: 0.4)
        _ = ledger.raise(current: 1)
        XCTAssertEqual(ledger.restore(current: 1), 0.4)
    }

    func testRestoreWithNothingRaisedChangesNothing() {
        XCTAssertNil(BrightnessLedger(store: MemoryBrightnessStore()).restore(current: 0.5))
    }

    func testAPersonWhoTurnedItDownMeanwhileIsLeftAlone() {
        let ledger = BrightnessLedger(store: MemoryBrightnessStore())
        _ = ledger.raise(current: 0.8)
        XCTAssertNil(ledger.restore(current: 0.3))
        XCTAssertFalse(ledger.isRaised)
    }

    func testAProcessThatDiedMidRingPutsItBackOnTheNextStart() {
        let store = MemoryBrightnessStore()
        _ = BrightnessLedger(store: store).raise(current: 0.25)
        // A new process: a new ledger over the same saved value, the screen still at full.
        let next = BrightnessLedger(store: store)
        XCTAssertEqual(next.recoverAtLaunch(current: 1), 0.25)
        XCTAssertFalse(next.isRaised)
        XCTAssertNil(next.recoverAtLaunch(current: 1))
    }

    func testRecoveryLeavesAScreenThePersonTurnedDown() {
        let store = MemoryBrightnessStore()
        _ = BrightnessLedger(store: store).raise(current: 0.25)
        let next = BrightnessLedger(store: store)
        XCTAssertNil(next.recoverAtLaunch(current: 0.6))
        XCTAssertNil(store.saved)
    }

    func testTheSavedValueSurvivesInUserDefaults() throws {
        let suite = "ring-screen-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        _ = BrightnessLedger(store: DefaultsBrightnessStore(defaults: defaults)).raise(current: 0.5)
        let next = BrightnessLedger(store: DefaultsBrightnessStore(defaults: defaults))
        XCTAssertEqual(next.recoverAtLaunch(current: 1), 0.5)
        XCTAssertNil(defaults.object(forKey: DefaultsBrightnessStore.key))
    }
}
