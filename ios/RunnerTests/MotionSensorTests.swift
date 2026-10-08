import UIKit
import XCTest

// MotionSensor.swift is compiled into this target, the way the other
// sources under test are.

/// Stands in for the accelerometer and counts what it was asked.
final class FakeAccelerometer: AccelerometerSource {
  var isAvailable = true
  var starts = 0
  var stops = 0
  private var handler: ((Double, Double, Double, Double) -> Void)?

  /// Whether the hardware would be on right now.
  var isOn: Bool { handler != nil }

  func start(onReading: @escaping (Double, Double, Double, Double) -> Void) {
    starts += 1
    handler = onReading
  }

  func stop() {
    stops += 1
    handler = nil
  }

  func read(_ x: Double, _ y: Double, _ z: Double, at seconds: Double) {
    handler?(x, y, z, seconds)
  }
}

final class MotionSensorTests: XCTestCase {
  private var source: FakeAccelerometer!
  private var center: NotificationCenter!
  private var readings: [[Double]] = []

  override func setUp() {
    super.setUp()
    source = FakeAccelerometer()
    center = NotificationCenter()
    readings = []
  }

  private func makeRun(isActiveNow: Bool = true) -> MotionSensorRun {
    let run = MotionSensorRun(
      source: source, isActiveNow: isActiveNow, center: center, deliver: { $0() }
    )
    run.onReading = { [weak self] in self?.readings.append($0) }
    return run
  }

  private func post(_ name: Notification.Name) {
    center.post(name: name, object: nil)
  }

  func testStartTurnsTheSensorOnOnce() {
    let run = makeRun()
    XCTAssertFalse(source.isOn)
    XCTAssertEqual(run.start(), .started)
    XCTAssertEqual(run.start(), .started)
    XCTAssertEqual(source.starts, 1)
    XCTAssertTrue(run.isRunning)
    XCTAssertTrue(source.isOn)
  }

  func testAPhoneWithNoAccelerometerSaysSoAndStartsNothing() {
    source.isAvailable = false
    let run = makeRun()
    XCTAssertEqual(run.start(), .noAccelerometer)
    XCTAssertEqual(source.starts, 0)
    XCTAssertFalse(run.isRunning)
  }

  func testReadingsGoOutAsXYZAndSeconds() {
    let run = makeRun()
    _ = run.start()
    source.read(0.1, -0.2, -1, at: 12.5)
    XCTAssertEqual(readings, [[0.1, -0.2, -1, 12.5]])
  }

  func testStopTurnsTheSensorOff() {
    let run = makeRun()
    _ = run.start()
    run.stop()
    XCTAssertFalse(run.isRunning)
    XCTAssertFalse(source.isOn)
    XCTAssertEqual(source.stops, 1)
  }

  func testStopTellsTheSourceEvenWhenNothingRuns() {
    let run = makeRun()
    run.stop()
    run.stop()
    XCTAssertEqual(source.stops, 2)
    XCTAssertEqual(source.starts, 0)
  }

  func testAReadingOnItsWayWhenTheSensorStoppedIsDropped() {
    var held: [() -> Void] = []
    let run = MotionSensorRun(
      source: source, isActiveNow: true, center: center, deliver: { held.append($0) }
    )
    run.onReading = { [weak self] in self?.readings.append($0) }
    _ = run.start()
    source.read(3, 0, -1, at: 1)
    run.stop()
    held.forEach { $0() }
    XCTAssertTrue(readings.isEmpty)
  }

  func testResigningActiveTurnsTheSensorOffByItself() {
    let run = makeRun()
    _ = run.start()
    post(UIApplication.willResignActiveNotification)
    XCTAssertFalse(run.isRunning)
    XCTAssertFalse(source.isOn)
  }

  func testEnteringTheBackgroundTurnsTheSensorOffByItself() {
    let run = makeRun()
    _ = run.start()
    post(UIApplication.didEnterBackgroundNotification)
    XCTAssertFalse(run.isRunning)
    XCTAssertFalse(source.isOn)
  }

  func testItDoesNotStartWhileTheAppIsNotActive() {
    let run = makeRun()
    post(UIApplication.willResignActiveNotification)
    XCTAssertEqual(run.start(), .notInFront)
    XCTAssertEqual(source.starts, 0)
    XCTAssertFalse(run.isRunning)
  }

  func testItDoesNotStartInAnAppThatWasNeverActive() {
    let run = makeRun(isActiveNow: false)
    XCTAssertEqual(run.start(), .notInFront)
    XCTAssertEqual(source.starts, 0)
  }

  func testComingBackDoesNotTurnItOnUntilAsked() {
    let run = makeRun()
    _ = run.start()
    post(UIApplication.willResignActiveNotification)
    post(UIApplication.didEnterBackgroundNotification)
    post(UIApplication.didBecomeActiveNotification)
    XCTAssertFalse(run.isRunning)
    XCTAssertFalse(source.isOn)
    XCTAssertEqual(source.starts, 1)
    XCTAssertEqual(run.start(), .started)
    XCTAssertEqual(source.starts, 2)
    XCTAssertTrue(source.isOn)
  }

  func testLettingGoOfTheRunTurnsTheSensorOff() {
    var run: MotionSensorRun? = makeRun()
    _ = run?.start()
    XCTAssertTrue(source.isOn)
    run = nil
    XCTAssertFalse(source.isOn)
  }

  func testTheRealSourceAsksForFiftyReadingsASecond() {
    XCTAssertEqual(CoreMotionAccelerometer.interval, 0.02, accuracy: 0.0001)
  }
}
