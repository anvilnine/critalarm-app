import Foundation

/// What the open incident screen does with the screen and the Taptic Engine
/// while it rings, apart from UIKit and Core Haptics so it is tested on its
/// own.
///
/// The AlarmKit alert is system UI: no app sets its brightness or its
/// vibration. This covers only the app's own incident screen, while it is
/// open, in front and ringing. `RingScreenEffects` is the thin part that
/// makes the platform calls.
enum RingScreenRule {
    /// The two switches in Settings. Dart keeps them with the
    /// `shared_preferences` plugin, which writes `flutter.` in front of each
    /// key in the standard user defaults. Rename a key on both sides or not
    /// at all.
    static let brightScreenKey = "flutter.ring_bright_screen"
    static let vibrateKey = "flutter.ring_vibrate"

    /// The pattern for a sound with no pattern of its own: a store sound
    /// pack, a sound the user made, or a sound added without one.
    static let steadyPattern = "steady"

    /// A switch that was never set, or holds something else, reads as on.
    static func switchIsOn(_ stored: Any?) -> Bool {
        (stored as? Bool) ?? true
    }

    struct Plan: Equatable {
        var brighten: Bool
        var haptics: Bool
    }

    /// What to do right now.
    ///
    /// - [isRinging]: the incident screen is open, rings, and has nothing on
    ///   top of it. Dart says so.
    /// - [isActive]: the app is in front. Brightness and haptics stop the
    ///   moment it is not, and start again when it is back.
    static func plan(
        isRinging: Bool,
        isActive: Bool,
        brightSwitchOn: Bool,
        vibrateSwitchOn: Bool,
        hapticsSupported: Bool
    ) -> Plan {
        guard isRinging, isActive else { return Plan(brighten: false, haptics: false) }
        return Plan(brighten: brightSwitchOn, haptics: vibrateSwitchOn && hapticsSupported)
    }

    /// Which pattern goes with the sound that rings for a topic.
    ///
    /// [soundFile] is the file name the alarm rings, such as
    /// `classic_siren.caf`, or nil when the topic has no choice and the ring
    /// is the `alarm.caf` that ships in the app. [hasPattern] says whether the
    /// app holds a pattern by that name. Anything else gets the steady one.
    static func patternName(soundFile: String?, hasPattern: (String) -> Bool) -> String {
        let file = (soundFile?.isEmpty ?? true) ? "alarm.caf" : soundFile!
        let name = (file as NSString).deletingPathExtension
        return hasPattern(name) ? name : steadyPattern
    }

    /// How long a pattern is, in seconds: the end of its last event. The
    /// pattern files end on the last moment of their sound, so this is also
    /// the length of the sound and the point the loop wraps at. Nil for a
    /// pattern with no event.
    static func patternLength(ahap: [String: Any]) -> TimeInterval? {
        guard let events = ahap["Pattern"] as? [[String: Any]] else { return nil }
        var end: TimeInterval?
        for entry in events {
            guard let event = entry["Event"] as? [String: Any],
                  let time = (event["Time"] as? NSNumber)?.doubleValue else { continue }
            let length = (event["EventDuration"] as? NSNumber)?.doubleValue ?? 0
            end = max(end ?? 0, time + length)
        }
        return end
    }
}

/// Where the brightness the phone had before the ring is kept.
protocol BrightnessStore: AnyObject {
    var saved: Float? { get set }
}

/// The saved brightness on disk, so a process that dies mid-ring can put it
/// back on its next start.
final class DefaultsBrightnessStore: BrightnessStore {
    static let key = "ring_screen_saved_brightness"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var saved: Float? {
        get { defaults.object(forKey: Self.key) == nil ? nil : defaults.float(forKey: Self.key) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}

/// Keeps the brightness the person had, while the screen is at full.
///
/// The value is written to the store before the screen goes to full, so a
/// crash leaves it behind. A second raise while one is still open keeps the
/// first value: that one is the person's own, the current one is ours.
final class BrightnessLedger {
    /// What the screen is set to while it rings.
    static let full: Float = 1

    /// Below this, a screen is not at the full we set.
    private static let atFull: Float = 0.99

    private let store: BrightnessStore

    init(store: BrightnessStore) {
        self.store = store
    }

    /// The screen is at [current] and is about to go to full. Answers the
    /// brightness to set.
    func raise(current: Float) -> Float {
        if store.saved == nil { store.saved = current }
        return Self.full
    }

    /// The screen stops ringing, or the app leaves the front. [current] is
    /// the brightness now. Answers the brightness to put back, or nil when
    /// nothing was raised or the person turned it down meanwhile and has
    /// already chosen.
    func restore(current: Float) -> Float? {
        guard let saved = store.saved else { return nil }
        store.saved = nil
        return current >= Self.atFull ? saved : nil
    }

    /// The app started and a value is still saved: the last process died with
    /// the screen raised. Answers the brightness to put back, but only while
    /// the screen still sits at full. A person who turned it down since has
    /// already chosen, and the saved value is dropped without a change.
    func recoverAtLaunch(current: Float) -> Float? {
        guard let saved = store.saved else { return nil }
        store.saved = nil
        return current >= Self.atFull && saved < Self.atFull ? saved : nil
    }

    var isRaised: Bool { store.saved != nil }
}
