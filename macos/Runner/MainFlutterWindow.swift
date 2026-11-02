import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // The app is laid out for a phone held upright, so the window opens at
    // that shape and can grow from there.
    self.setContentSize(NSSize(width: 430, height: 900))
    self.contentMinSize = NSSize(width: 360, height: 640)
    self.title = "Crit Alarm"
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The app's own channels. Only the ones the Mac can answer are here:
    // sound files and notification settings. Every other channel the
    // iPhone has is not registered, and Dart does not call it on a Mac
    // (`OffPlatformChannel` in lib/core/platform).
    let messenger = flutterViewController.engine.binaryMessenger
    SoundChannel.attach(messenger: messenger)
    SettingsChannel.attach(messenger: messenger)

    super.awakeFromNib()
  }
}
