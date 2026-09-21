import Foundation

/// Where alarm sounds live so both the app and the notification extension can
/// reach them, and which one each topic uses.
///
/// `UNNotificationSound(named:)` looks in the app's `Library/Sounds`, in the
/// app group's `Library/Sounds`, and in the main bundle. The extension runs in
/// its own sandbox and cannot see the app's own container, so it could never
/// check a file there. The group container is the one folder both processes
/// can read, so the sounds go there.
enum SharedSounds {
    static let appGroup = "group.app.critalarm"

    /// File name ("classic_siren.caf") used when a topic has no choice of its own.
    static let defaultFileKey = "sound_default_file"

    /// Topic name to file name, written by the app on every change.
    static let perTopicFilesKey = "sound_per_topic_files"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// `Library/Sounds` inside the app group container. Nil when the
    /// entitlement is missing.
    static var groupSoundsDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    /// iOS swaps any notification sound of 30 seconds or more for the system
    /// default, so those are never published and `alarm.caf` plays instead.
    static let maxRingMs = 30_000

    static func ringsOnIphone(durationMs: Int) -> Bool { durationMs < maxRingMs }

    /// Writes the current choices where the extension reads them. A nil
    /// default clears it, so the payload's own sound plays.
    static func publish(defaultFile: String?, perTopicFiles: [String: String], to defaults: UserDefaults) {
        if let defaultFile {
            defaults.set(defaultFile, forKey: defaultFileKey)
        } else {
            defaults.removeObject(forKey: defaultFileKey)
        }
        defaults.set(perTopicFiles, forKey: perTopicFilesKey)
    }

    /// The file name to play for [topic], or nil when nothing was published
    /// or the file is not on disk. Nil means leave the payload's sound alone.
    static func fileName(
        forTopic topic: String?,
        defaults: UserDefaults?,
        fileExists: (String) -> Bool
    ) -> String? {
        guard let defaults else { return nil }
        let perTopic = defaults.dictionary(forKey: perTopicFilesKey) as? [String: String] ?? [:]
        let picked = topic.flatMap { perTopic[$0] } ?? defaults.string(forKey: defaultFileKey)
        guard let name = picked, !name.isEmpty, fileExists(name) else { return nil }
        return name
    }

    /// True when [name] is in the group's `Library/Sounds`.
    static func existsInGroup(_ name: String) -> Bool {
        guard let directory = groupSoundsDirectory else { return false }
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
    }
}
