import Flutter
import UIKit

/// The accelerometer for the shake challenge, on two channels of its own.
///
/// `app.critalarm/motion` has `start` and `stop`, each with `run`, the
/// number of the Dart stream it belongs to.
/// `app.critalarm/motion/readings` carries each reading as a list of x, y,
/// z in g and the time in seconds, and its listen and cancel carry the same
/// number. A stop or a cancel from a stream that is not the newest is
/// ignored. `MotionSensorRun` decides when the
/// sensor runs. The Dart half is `lib/core/motion/motion_sensor.dart`.
///
/// A `start` on a device with no accelerometer answers the error
/// `no_accelerometer`, which Dart turns into the tap fallback. A `start`
/// while the app is not active answers false and starts nothing.
final class MotionSensorChannel: NSObject, FlutterStreamHandler {
  static let shared = MotionSensorChannel()

  static let methodsName = "app.critalarm/motion"
  static let readingsName = "app.critalarm/motion/readings"

  private var run: MotionSensorRun?
  private var sink: FlutterEventSink?

  /// The number of the stream the sink belongs to.
  private var listener: Int?

  func attach(messenger: FlutterBinaryMessenger) {
    let run = MotionSensorRun(
      source: CoreMotionAccelerometer(),
      isActiveNow: UIApplication.shared.applicationState == .active
    )
    run.onReading = { [weak self] reading in self?.sink?(reading) }
    self.run = run

    let methods = FlutterMethodChannel(
      name: MotionSensorChannel.methodsName, binaryMessenger: messenger
    )
    methods.setMethodCallHandler { [weak self] call, result in
      let owner = (call.arguments as? [String: Any])?["run"] as? Int
      switch call.method {
      case "start":
        switch self?.run?.start(owner: owner) {
        case .started:
          result(true)
        case .notInFront, nil:
          result(false)
        case .noAccelerometer:
          result(FlutterError(
            code: "no_accelerometer", message: "This device has no accelerometer", details: nil
          ))
        }
      case "stop":
        self?.run?.stop(owner: owner)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(name: MotionSensorChannel.readingsName, binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    listener = arguments as? Int
    return nil
  }

  /// A Dart stream stopped listening. If it is the one that owns the
  /// sensor, that alone turns the sensor off, whether or not a `stop`
  /// follows. An older stream going away changes nothing.
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    let from = arguments as? Int
    if from == listener {
      sink = nil
      listener = nil
    }
    run?.stop(owner: from)
    return nil
  }
}
