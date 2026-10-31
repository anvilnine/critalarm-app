import Flutter
import UIKit

/// The fold of a folding iPhone (iPhone Duo), for Dart. Flutter reports no
/// display features on iOS, so `MediaQuery.displayFeatures` never holds the
/// fold without this.
///
/// `app.critalarm/display` has `current`, which answers the fold now.
/// `app.critalarm/display/fold` sends the fold once on listen and again each
/// time it changes. The fold is a map, or null when the view has none:
///
/// - `left`, `top`, `width`, `height`: the reserved rect without its
///   margins, in points of the Flutter view, which are Flutter's logical
///   pixels for that view.
/// - `marginLeft`, `marginTop`, `marginRight`, `marginBottom`: the room UIKit
///   asks interactive content to keep from the rect.
/// - `active`: whether the division is in force right now.
///
/// The fold is the view's `.division` reserved region
/// (`UIView.reservedRegions(kind:options:)`, iOS 27.1). Older iOS and every
/// iPhone that does not fold answer null. Nothing polls: the view's layout,
/// its size class traits and a hinge interaction each read the region
/// again, and only a change is sent. The Dart half is
/// `lib/core/device/native_fold.dart`.
final class DisplayFoldChannel: NSObject, FlutterStreamHandler {
  static let shared = DisplayFoldChannel()

  static let methodsName = "app.critalarm/display"
  static let eventsName = "app.critalarm/display/fold"

  /// Where the Flutter view comes from. Its view controller is not there
  /// yet when the engine starts, so the view is looked up when Dart asks.
  private var registrar: FlutterPluginRegistrar?
  private var sink: FlutterEventSink?

  /// Watches the Flutter view's layout. Only on iOS 27.1 or later.
  private var observer: UIView?

  /// The last fold sent, and whether anything has been sent yet.
  private var lastSent: DisplayFoldReading?
  private var hasSent = false

  func attach(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    let methods = FlutterMethodChannel(
      name: DisplayFoldChannel.methodsName, binaryMessenger: registrar.messenger()
    )
    methods.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "current":
        self?.installIfNeeded()
        result(self?.read()?.asMap)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(name: DisplayFoldChannel.eventsName, binaryMessenger: registrar.messenger())
      .setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    hasSent = false
    installIfNeeded()
    send()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  /// Sends the fold when it differs from the last one sent.
  private func send() {
    guard let sink else { return }
    let reading = read()
    if hasSent && reading == lastSent { return }
    hasSent = true
    lastSent = reading
    sink(reading?.asMap ?? NSNull())
  }

  private func flutterView() -> UIView? {
    if let view = registrar?.viewController?.view { return view }
    // A fallback for a start where the registrar has no view controller yet.
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    let root = windows.first(where: \.isKeyWindow)?.rootViewController
      ?? windows.first?.rootViewController
    return (root as? FlutterViewController)?.view
  }

  /// Puts the observer in the Flutter view, once, on iOS 27.1 or later.
  private func installIfNeeded() {
    guard #available(iOS 27.1, *) else { return }
    guard let view = flutterView() else { return }
    if let observer, observer.superview === view { return }
    observer?.removeFromSuperview()
    let watcher = DisplayFoldObserverView(frame: view.bounds)
    watcher.onChange = { [weak self] in self?.send() }
    // Behind any platform view, the full size of the Flutter view, and
    // invisible to touch and to VoiceOver.
    view.insertSubview(watcher, at: 0)
    observer = watcher
  }

  /// The view's division region, or nil.
  private func read() -> DisplayFoldReading? {
    guard #available(iOS 27.1, *) else { return nil }
    guard let view = flutterView() else { return nil }
    // Every caller is on the main thread: a channel handler, a layout pass,
    // a trait change or the hinge interaction.
    return MainActor.assumeIsolated { () -> DisplayFoldReading? in
      let regions = view.reservedRegions(kind: .division, options: [.includeInactive])
      guard let region = regions.first else { return nil }
      let margins = region.margins
      let rect = region.frame.inset(by: margins)
      return DisplayFoldReading(
        left: rect.minX,
        top: rect.minY,
        width: max(0, rect.width),
        height: max(0, rect.height),
        margins: margins,
        isActive: region.isActive
      )
    }
  }
}

/// One reading of the fold, in points of the Flutter view.
struct DisplayFoldReading: Equatable, Sendable {
  let left: CGFloat
  let top: CGFloat
  let width: CGFloat
  let height: CGFloat
  let margins: UIEdgeInsets
  let isActive: Bool

  var asMap: [String: Any] {
    [
      "left": Double(left),
      "top": Double(top),
      "width": Double(width),
      "height": Double(height),
      "marginLeft": Double(margins.left),
      "marginTop": Double(margins.top),
      "marginRight": Double(margins.right),
      "marginBottom": Double(margins.bottom),
      "active": isActive,
    ]
  }
}

/// A clear view the size of the Flutter view that says when the fold may
/// have changed: the view was laid out (it opened, closed, rotated or was
/// resized), its size classes changed, or the hinge moved.
@available(iOS 27.1, *)
final class DisplayFoldObserverView: UIView {
  var onChange: (() -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    accessibilityElementsHidden = true
    backgroundColor = .clear
    isOpaque = false
    _ = registerForTraitChanges(
      [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
    ) { (view: DisplayFoldObserverView, _: UITraitCollection) in
      view.onChange?()
    }
    addInteraction(UIHingeInteraction { [weak self] _, _ in self?.onChange?() })
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    onChange?()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onChange?()
  }
}
