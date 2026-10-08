import CoreMotion
import Foundation
import UIKit

/// What the shake challenge needs from the phone: the accelerometer, and
/// nothing else of its motion hardware.
///
/// A protocol so the rules in `MotionSensorRun` are tested with a made-up
/// source, with no phone.
protocol AccelerometerSource: AnyObject {
  /// Whether this device has an accelerometer. The Simulator has none.
  var isAvailable: Bool { get }

  /// Starts readings. Each is x, y and z in g with gravity included, and
  /// the sensor's own time in seconds. They may arrive on any queue.
  func start(onReading: @escaping (Double, Double, Double, Double) -> Void)

  /// Stops readings. Safe to call when none are running.
  func stop()
}

/// The accelerometer through `CMMotionManager`.
///
/// Only `startAccelerometerUpdates` and `stopAccelerometerUpdates` are
/// used. Raw accelerometer readings need no permission and no usage string
/// in `Info.plist`. Nothing here may touch the parts of Core Motion that do
/// (the pedometer, the activity manager, the altimeter, headphone motion),
/// because one reference to any of them makes the store ask for
/// `NSMotionUsageDescription`.
final class CoreMotionAccelerometer: AccelerometerSource {
  /// Fifty readings a second: a hand shakes a phone three to five times a
  /// second, so that is ten or more readings for each swing.
  static let interval: TimeInterval = 1.0 / 50.0

  /// Made the first time the challenge asks for the sensor, so an install
  /// that never opens it never has one. `stop` runs at every resign
  /// active and must not be what makes it.
  private var manager: CMMotionManager?

  /// Whether a `CMMotionManager` exists yet.
  var hasManager: Bool { manager != nil }

  private func madeManager() -> CMMotionManager {
    if let manager { return manager }
    let made = CMMotionManager()
    manager = made
    return made
  }

  private lazy var queue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "app.critalarm.motion"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  var isAvailable: Bool { madeManager().isAccelerometerAvailable }

  func start(onReading: @escaping (Double, Double, Double, Double) -> Void) {
    let manager = madeManager()
    manager.accelerometerUpdateInterval = CoreMotionAccelerometer.interval
    manager.startAccelerometerUpdates(to: queue) { data, _ in
      guard let data else { return }
      onReading(
        data.acceleration.x, data.acceleration.y, data.acceleration.z, data.timestamp
      )
    }
  }

  /// Nothing to stop when nothing was ever started.
  func stop() {
    manager?.stopAccelerometerUpdates()
  }
}

/// When the accelerometer runs, and when it does not.
///
/// It runs between a `start` and the first of: a `stop`, the app resigning
/// active, the app entering the background. It never starts while the app
/// is not active, and it never starts again by itself: Dart asks when it
/// wants it back. So a mistake on the Dart side cannot leave the sensor on
/// behind a locked screen.
///
/// Each Dart stream has a number, sent with its `start` and its `stop`.
/// The newest start owns the sensor, and a stop with any other number is
/// ignored. So when one listener goes as the next arrives (start new, stop
/// old), the old one's stop cannot turn off what the new one started.
///
/// Everything here is called on the main thread. `deliver` moves a reading
/// from the sensor's queue to it.
final class MotionSensorRun {
  enum StartAnswer: Equatable {
    case started
    case noAccelerometer
    case notInFront
  }

  private let source: AccelerometerSource
  private let center: NotificationCenter
  private let deliver: (@escaping () -> Void) -> Void
  private var observers: [NSObjectProtocol] = []
  private var isInFront: Bool

  private(set) var isRunning = false

  /// The number of the stream that last started the sensor.
  private(set) var owner: Int?

  /// Where a reading goes: x, y, z and the time in seconds.
  var onReading: (([Double]) -> Void)?

  init(
    source: AccelerometerSource,
    isActiveNow: Bool,
    center: NotificationCenter = .default,
    deliver: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
  ) {
    self.source = source
    self.center = center
    self.deliver = deliver
    self.isInFront = isActiveNow
    let leaving = [
      UIApplication.willResignActiveNotification,
      UIApplication.didEnterBackgroundNotification,
    ]
    for name in leaving {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
          self?.isInFront = false
          self?.stop()
        }
      )
    }
    observers.append(
      center.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil
      ) { [weak self] _ in
        // Back in front. The sensor stays off until it is asked for.
        self?.isInFront = true
      }
    )
  }

  deinit {
    observers.forEach(center.removeObserver)
    source.stop()
  }

  func start(owner: Int? = nil) -> StartAnswer {
    guard source.isAvailable else { return .noAccelerometer }
    guard isInFront else { return .notInFront }
    self.owner = owner
    guard !isRunning else { return .started }
    isRunning = true
    source.start { [weak self] x, y, z, seconds in
      self?.deliver {
        // A reading that was on its way when the sensor stopped is dropped.
        guard let self, self.isRunning else { return }
        self.onReading?([x, y, z, seconds])
      }
    }
    return .started
  }

  /// Stops the sensor. The source is told every time, running or not, so
  /// nothing depends on this class having kept count.
  func stop() {
    isRunning = false
    owner = nil
    source.stop()
  }

  /// A stop from the stream numbered `owner`. It counts only when that
  /// stream is the one that last started the sensor.
  func stop(owner: Int?) {
    guard owner == self.owner else { return }
    stop()
  }
}
