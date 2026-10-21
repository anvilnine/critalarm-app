import CoreHaptics
import Flutter
import UIKit

/// Full brightness and a vibration on the beat of the sound, for as long as
/// the app's own incident screen is open and ringing.
///
/// Dart says when the screen starts and stops ringing (`start` and `stop` on
/// `app.critalarm/ring_screen`); `RingScreenRule` decides what that means and
/// this class makes the platform calls. The two switches in Settings are read
/// from the standard user defaults at every start, so a change applies to the
/// next ring. The AlarmKit alert itself is system UI and is not touched.
///
/// The app leaving the front puts the brightness back and stops the pattern;
/// coming back, while the screen still rings, starts both again. The
/// brightness the person had is saved to disk first (`BrightnessLedger`), so
/// a process that dies mid-ring puts it back on its next start.
final class RingScreenEffects {
    static let shared = RingScreenEffects()

    static let channelName = "app.critalarm/ring_screen"

    private let ledger = BrightnessLedger(store: DefaultsBrightnessStore())
    private let haptics = RingHapticsPlayer()

    private var isRinging = false
    private var isActive = true
    private var topic: String?

    /// Registers the channel and the lifecycle listeners, and puts back a
    /// brightness the last process left raised.
    func attach(messenger: FlutterBinaryMessenger) {
        isActive = UIApplication.shared.applicationState != .background
        if let back = ledger.recoverAtLaunch(current: Float(screen.brightness)) {
            screen.brightness = CGFloat(back)
        }
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification, object: nil
        )
        let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "start":
                self?.start(topic: (call.arguments as? [String: Any])?["topic"] as? String)
                result(nil)
            case "stop":
                self?.stop()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func start(topic: String?) {
        isRinging = true
        self.topic = topic
        apply()
    }

    func stop() {
        isRinging = false
        apply()
    }

    @objc private func appWillResignActive() {
        isActive = false
        apply()
    }

    @objc private func appDidBecomeActive() {
        isActive = true
        apply()
    }

    @objc private func appWillTerminate() {
        isRinging = false
        apply()
    }

    private var screen: UIScreen {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen ?? UIScreen.main
    }

    /// Makes the screen and the pattern match what the rule asks for now.
    private func apply() {
        let defaults = UserDefaults.standard
        let plan = RingScreenRule.plan(
            isRinging: isRinging,
            isActive: isActive,
            brightSwitchOn: RingScreenRule.switchIsOn(
                defaults.object(forKey: RingScreenRule.brightScreenKey)
            ),
            vibrateSwitchOn: RingScreenRule.switchIsOn(
                defaults.object(forKey: RingScreenRule.vibrateKey)
            ),
            hapticsSupported: CHHapticEngine.capabilitiesForHardware().supportsHaptics
        )
        if plan.brighten {
            screen.brightness = CGFloat(ledger.raise(current: Float(screen.brightness)))
        } else if let back = ledger.restore(current: Float(screen.brightness)) {
            screen.brightness = CGFloat(back)
        }
        if plan.haptics {
            haptics.start(pattern: patternForTopic())
        } else {
            haptics.stop()
        }
    }

    /// The pattern for the sound that rings for [topic].
    private func patternForTopic() -> String {
        let file = SharedSounds.fileName(
            forTopic: topic,
            defaults: SharedSounds.groupDefaults,
            fileExists: SharedSounds.existsInGroup
        )
        return RingScreenRule.patternName(soundFile: file) { name in
            RingHapticsPlayer.url(for: name) != nil
        }
    }
}

/// Plays one AHAP pattern in a loop. The patterns are made by
/// `tools/sounds/haptics.mjs`, one per bundled sound, each exactly as long as
/// its sound, so the loop wraps where the sound does.
final class RingHapticsPlayer {
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var playing: String?

    /// The engine stopping on its own (an audio interruption, the system
    /// reclaiming it) is answered with a restart, a few times.
    private var restarts = 0
    private static let maxRestarts = 5

    static func url(for pattern: String) -> URL? {
        Bundle.main.url(forResource: pattern, withExtension: "ahap", subdirectory: "Haptics")
    }

    func start(pattern name: String) {
        if playing == name, player != nil { return }
        stop()
        guard let url = Self.url(for: name),
              let data = try? Data(contentsOf: url),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return }
        do {
            let pattern = try CHHapticPattern(contentsOf: url)
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = false
            engine.stoppedHandler = { [weak self] _ in
                DispatchQueue.main.async { self?.engineStopped(pattern: name) }
            }
            engine.resetHandler = { [weak self] in
                DispatchQueue.main.async { self?.engineStopped(pattern: name) }
            }
            try engine.start()
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            if let length = RingScreenRule.patternLength(ahap: json), length > 0 {
                player.loopEnd = length
            }
            try player.start(atTime: CHHapticTimeImmediate)
            self.engine = engine
            self.player = player
            self.playing = name
        } catch {
            NSLog("CritAlarmHaptics: start_failed pattern=%@ error=%@", name, String(describing: error))
        }
    }

    func stop() {
        let engine = self.engine
        let player = self.player
        self.engine = nil
        self.player = nil
        self.playing = nil
        engine?.stoppedHandler = { _ in }
        engine?.resetHandler = {}
        try? player?.stop(atTime: CHHapticTimeImmediate)
        engine?.stop(completionHandler: nil)
        restarts = 0
    }

    private func engineStopped(pattern name: String) {
        guard playing == name else { return }
        guard restarts < Self.maxRestarts else {
            NSLog("CritAlarmHaptics: gave_up pattern=%@", name)
            stop()
            return
        }
        let used = restarts + 1
        engine = nil
        player = nil
        playing = nil
        start(pattern: name)
        restarts = used
    }
}
