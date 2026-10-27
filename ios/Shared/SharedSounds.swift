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

    /// What to publish for the saved choices.
    ///
    /// [ringableFileName] turns a sound id into the file name to publish, or
    /// nil for one that cannot ring (no id, or too long for iOS).
    ///
    /// While own sounds are locked no own file is published:
    /// - a topic on an own sound is left out, so it rings the default;
    /// - a default that is an own sound becomes the bundled classic siren.
    ///
    /// The same rule as `OwnSoundRule` in lib/core/sound/own_sound_rule.dart
    /// and `AlarmSoundStore.resolveChain` on Android. The ids handed in are
    /// the saved ones and are not changed.
    static func choicesToPublish(
        defaultId: String?,
        perTopicIds: [String: String],
        ownLocked: Bool,
        ringableFileName: (String) -> String?
    ) -> (defaultFile: String?, perTopicFiles: [String: String]) {
        var defaultFile = defaultId.flatMap(ringableFileName)
        if ownLocked, let id = defaultId, OwnSoundLock.isOwn(id) {
            defaultFile = packFallbackFile
        }
        var perTopic: [String: String] = [:]
        for (topic, id) in perTopicIds {
            if ownLocked && OwnSoundLock.isOwn(id) { continue }
            if let name = ringableFileName(id) { perTopic[topic] = name }
        }
        return (defaultFile, perTopic)
    }

    /// Writes the current choices where the extension reads them. A nil
    /// default clears it, so the payload's own sound plays. [ownLocked] goes
    /// with them, so the extension and the alarm scheduler can tell. Left
    /// out, the flag already there stays as it is.
    static func publish(
        defaultFile: String?,
        perTopicFiles: [String: String],
        ownLocked: Bool? = nil,
        to defaults: UserDefaults
    ) {
        if let ownLocked { defaults.set(ownLocked, forKey: OwnSoundLock.groupKey) }
        if let defaultFile {
            defaults.set(defaultFile, forKey: defaultFileKey)
        } else {
            defaults.removeObject(forKey: defaultFileKey)
        }
        defaults.set(perTopicFiles, forKey: perTopicFilesKey)
    }

    /// The file name a sound id is stored under in `Library/Sounds`.
    static func fileNameFor(soundID: String) -> String { "\(soundID).caf" }

    /// Every sound from a downloaded sound pack has an id, and so a file
    /// name, starting with this.
    static let packSoundPrefix = "pack_"

    /// What a pack sound whose file has gone rings instead: the bundled
    /// default, which the app copies into the group on every launch.
    static let packFallbackFile = "classic_siren.caf"

    /// The file name to play for [topic], or nil when nothing was published
    /// or no file is on disk. Nil means leave the payload's sound alone.
    ///
    /// The topic's own choice comes first, then the default, the same order
    /// as the Android alarm and the picker. When the choices that are left
    /// include a pack sound whose file is gone, [packFallbackFile] plays.
    ///
    /// While own sounds are locked an own file is never the answer, even if
    /// one is still published from before the lock and still on disk. The
    /// next choice plays, then [packFallbackFile], then the payload's own
    /// `alarm.caf`, which ships in the app.
    static func fileName(
        forTopic topic: String?,
        defaults: UserDefaults?,
        fileExists: (String) -> Bool
    ) -> String? {
        guard let defaults else { return nil }
        let perTopic = defaults.dictionary(forKey: perTopicFilesKey) as? [String: String] ?? [:]
        let saved = [
            topic.flatMap { perTopic[$0] },
            defaults.string(forKey: defaultFileKey),
        ].compactMap { $0 }.filter { !$0.isEmpty }
        let ownLocked = OwnSoundLock.isLocked(in: defaults)
        let picks = ownLocked ? saved.filter { !OwnSoundLock.isOwn($0) } : saved
        if let found = picks.first(where: fileExists) { return found }
        let skippedOwn = picks.count != saved.count
        if skippedOwn || picks.contains(where: { $0.hasPrefix(packSoundPrefix) }),
           fileExists(packFallbackFile) {
            return packFallbackFile
        }
        return nil
    }

    /// True when [name] is in the group's `Library/Sounds`.
    static func existsInGroup(_ name: String) -> Bool {
        guard let directory = groupSoundsDirectory else { return false }
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
    }
}
