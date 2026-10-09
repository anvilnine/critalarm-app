import Foundation
import Security

/// Keeps a person's own photo and own sounds out of every backup.
///
/// An iPhone backup (iCloud, or a computer) copies the app's whole
/// container except caches, the tmp folder and whatever carries
/// `isExcludedFromBackup`. A flagged folder takes everything in it along.
///
/// The flag belongs to the file, not to its name. A file that is deleted and
/// written again has lost it, so the flag is set again after every write and
/// once at launch.
enum BackupExclusion {
  /// Flags [url]. False when there is nothing at [url] or the flag would not
  /// stick.
  @discardableResult
  static func exclude(_ url: URL) -> Bool {
    guard FileManager.default.fileExists(atPath: url.path) else { return false }
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try target.setResourceValues(values)
      return true
    } catch {
      return false
    }
  }

  /// Whether [url] carries the flag. Read from disk, never from a cache.
  static func isExcluded(_ url: URL) -> Bool {
    var fresh = url
    fresh.removeAllCachedResourceValues()
    return (try? fresh.resourceValues(forKeys: [.isExcludedFromBackupKey]))?
      .isExcludedFromBackup ?? false
  }

  /// Flags every own sound in [directory] and answers how many it flagged.
  ///
  /// The sounds folder also holds the bundled sounds and the downloaded
  /// packs, which are not the person's own and are copied or downloaded
  /// again when they are gone. So the flag goes on each own file and the
  /// folder is left alone.
  @discardableResult
  static func excludeOwnSounds(in directory: URL) -> Int {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    var flagged = 0
    for name in names where isOwnSound(name) {
      if exclude(directory.appendingPathComponent(name)) { flagged += 1 }
    }
    return flagged
  }

  /// Every own sound has an id, and so a file name, starting with this.
  /// `ownSoundIdPrefix` in lib/core/sound/own_sound_rule.dart.
  static let ownSoundPrefix = "user_"

  static func isOwnSound(_ fileName: String) -> Bool { fileName.hasPrefix(ownSoundPrefix) }
}

/// Tells an install that was restored onto another iPhone from one that has
/// stayed where it was.
///
/// Two copies of one random id. One is in the app's preferences, which every
/// backup carries to the next phone. The other is a Keychain item that never
/// leaves the phone it was written on. On the phone that wrote them the two
/// agree. On a phone that got them from a backup the Keychain copy is
/// missing, or is the one that phone made for itself.
///
/// The id means nothing outside this phone. It is never sent anywhere and
/// never logged.
enum InstallMarkerRule {
  /// What the Keychain said.
  enum KeychainCopy: Equatable {
    case value(String)
    /// The Keychain answered: there is no such item.
    case missing
    /// The Keychain could not be asked, for example before the first unlock
    /// after a restart. This says nothing about where the install is.
    case unreadable
  }

  enum Verdict: String {
    /// No marker anywhere: a first launch, or the first launch of a version
    /// that has one.
    case first
    /// The install is where it was.
    case same
    /// The preferences came from another phone.
    case moved
    /// Not known this launch. Nothing is dropped on a guess.
    case unknown
  }

  static func verdict(saved: String?, keychain: KeychainCopy) -> Verdict {
    let kept = saved.flatMap { $0.isEmpty ? nil : $0 }
    switch keychain {
    case .unreadable:
      return .unknown
    case .missing:
      return kept == nil ? .first : .moved
    case .value(let own):
      // The app was deleted and installed again on this phone: the
      // Keychain outlives a delete and the preferences do not.
      guard let kept else { return .same }
      return kept == own ? .same : .moved
    }
  }
}

/// The two copies [InstallMarkerRule] compares, on this phone.
struct InstallMarker {
  static let service = "app.critalarm.install_marker"
  static let account = "marker"
  static let defaultsKey = "critalarm.install_marker"

  var defaults: UserDefaults = .standard
  var service: String = InstallMarker.service

  /// The Keychain item. `ThisDeviceOnly` is the whole point: an item of that
  /// class is in no backup another phone can open and is never synced.
  func query() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: InstallMarker.account,
      kSecAttrSynchronizable as String: false as NSNumber,
    ]
  }

  static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

  func readKeychain() -> InstallMarkerRule.KeychainCopy {
    var read = query()
    read[kSecReturnData as String] = true
    read[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(read as CFDictionary, &item)
    if status == errSecItemNotFound { return .missing }
    guard status == errSecSuccess, let data = item as? Data,
          let value = String(data: data, encoding: .utf8), !value.isEmpty
    else { return .unreadable }
    return .value(value)
  }

  private func writeKeychain(_ value: String) -> Bool {
    SecItemDelete(query() as CFDictionary)
    var add = query()
    add[kSecValueData as String] = Data(value.utf8)
    add[kSecAttrAccessible as String] = InstallMarker.accessibility
    return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
  }

  /// Where this install stands. Finishes the pair itself when nothing has to
  /// be dropped first: a first launch gets both copies, and a reinstall on
  /// the same phone gets its preferences copy back.
  ///
  /// A moved install is left as found. The caller drops what came from the
  /// other phone and then calls [settle]. If the app dies in between, the
  /// next launch answers moved again and the drop runs again.
  func check() -> InstallMarkerRule.Verdict {
    let saved = defaults.string(forKey: InstallMarker.defaultsKey)
    let keychain = readKeychain()
    let verdict = InstallMarkerRule.verdict(saved: saved, keychain: keychain)
    switch verdict {
    case .first:
      settle()
    case .same:
      if case .value(let own) = keychain, saved != own {
        defaults.set(own, forKey: InstallMarker.defaultsKey)
      }
    case .moved, .unknown:
      break
    }
    return verdict
  }

  /// Makes this phone the marker's home: a new id, in both places.
  ///
  /// The Keychain copy goes first. If it cannot be written the preferences
  /// copy is taken away, so the next launch reads "no marker" and starts
  /// over. Left in place it would read as moved on every launch.
  @discardableResult
  func settle() -> Bool {
    let id = UUID().uuidString
    guard writeKeychain(id) else {
      defaults.removeObject(forKey: InstallMarker.defaultsKey)
      return false
    }
    defaults.set(id, forKey: InstallMarker.defaultsKey)
    return true
  }

  /// Removes both copies. For tests.
  func removeAll() {
    SecItemDelete(query() as CFDictionary)
    defaults.removeObject(forKey: InstallMarker.defaultsKey)
  }
}
