import Security
import XCTest

@testable import Runner

/// The own photo folder and the own sounds carry the flag that keeps them
/// out of a backup. Each check reads the resource value back from disk.
final class BackupExclusionTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("backup-exclusion-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: root)
  }

  private func write(_ name: String, in folder: URL) throws -> URL {
    let file = folder.appendingPathComponent(name)
    try Data("x".utf8).write(to: file)
    return file
  }

  func testAFolderStartsInTheBackup() throws {
    let look = root.appendingPathComponent("alarm_look", isDirectory: true)
    try FileManager.default.createDirectory(at: look, withIntermediateDirectories: true)
    XCTAssertFalse(BackupExclusion.isExcluded(look))
  }

  func testThePhotoFolderCarriesTheFlagOnceExcluded() throws {
    let look = root.appendingPathComponent("alarm_look", isDirectory: true)
    try FileManager.default.createDirectory(at: look, withIntermediateDirectories: true)
    XCTAssertTrue(BackupExclusion.exclude(look))
    XCTAssertTrue(BackupExclusion.isExcluded(look))
    // A photo saved later changes nothing about the folder's flag.
    _ = try write("own_abc.png", in: look)
    XCTAssertTrue(BackupExclusion.isExcluded(look))
  }

  func testExcludingTwiceIsTheSameAsOnce() throws {
    let look = root.appendingPathComponent("alarm_look", isDirectory: true)
    try FileManager.default.createDirectory(at: look, withIntermediateDirectories: true)
    XCTAssertTrue(BackupExclusion.exclude(look))
    XCTAssertTrue(BackupExclusion.exclude(look))
    XCTAssertTrue(BackupExclusion.isExcluded(look))
  }

  func testNothingThereIsNotFlagged() {
    let gone = root.appendingPathComponent("alarm_look", isDirectory: true)
    XCTAssertFalse(BackupExclusion.exclude(gone))
    XCTAssertFalse(BackupExclusion.isExcluded(gone))
  }

  func testEveryOwnSoundIsFlaggedAndNoOtherSound() throws {
    let sounds = root.appendingPathComponent("Sounds", isDirectory: true)
    try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
    let own = try write("user_1a2b.caf", in: sounds)
    let recorded = try write("user_rec_9.caf", in: sounds)
    let bundled = try write("classic_siren.caf", in: sounds)
    let pack = try write("pack_soft_bells.caf", in: sounds)

    XCTAssertEqual(BackupExclusion.excludeOwnSounds(in: sounds), 2)

    XCTAssertTrue(BackupExclusion.isExcluded(own))
    XCTAssertTrue(BackupExclusion.isExcluded(recorded))
    XCTAssertFalse(BackupExclusion.isExcluded(bundled))
    XCTAssertFalse(BackupExclusion.isExcluded(pack))
    // The folder holds sounds that are not the person's own, so it stays in.
    XCTAssertFalse(BackupExclusion.isExcluded(sounds))
  }

  func testAnOwnSoundWrittenAgainIsFlaggedByTheNextPass() throws {
    let sounds = root.appendingPathComponent("Sounds", isDirectory: true)
    try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
    let own = try write("user_1a2b.caf", in: sounds)
    BackupExclusion.excludeOwnSounds(in: sounds)
    // An import deletes the old file and converts into a new one.
    try FileManager.default.removeItem(at: own)
    _ = try write("user_1a2b.caf", in: sounds)
    XCTAssertFalse(BackupExclusion.isExcluded(own))
    BackupExclusion.excludeOwnSounds(in: sounds)
    XCTAssertTrue(BackupExclusion.isExcluded(own))
  }

  func testAMissingSoundsFolderFlagsNothing() {
    let gone = root.appendingPathComponent("Sounds", isDirectory: true)
    XCTAssertEqual(BackupExclusion.excludeOwnSounds(in: gone), 0)
  }

  func testTheOwnSoundPrefixIsTheOneTheLockUses() {
    XCTAssertEqual(BackupExclusion.ownSoundPrefix, OwnSoundLock.ownPrefix)
  }
}

/// The rule that knows an install was restored onto another phone.
final class InstallMarkerRuleTests: XCTestCase {
  private typealias Rule = InstallMarkerRule

  func testNoMarkerAnywhereIsAFirstLaunch() {
    XCTAssertEqual(Rule.verdict(saved: nil, keychain: .missing), .first)
    XCTAssertEqual(Rule.verdict(saved: "", keychain: .missing), .first)
  }

  func testBothCopiesAgreeingIsTheSamePhone() {
    XCTAssertEqual(Rule.verdict(saved: "a", keychain: .value("a")), .same)
  }

  /// A backup carries the preferences to the next phone and not the item.
  func testPreferencesWithNoKeychainItemHaveMoved() {
    XCTAssertEqual(Rule.verdict(saved: "a", keychain: .missing), .moved)
  }

  /// The next phone had the app before and made a marker of its own.
  func testPreferencesThatDisagreeWithTheKeychainHaveMoved() {
    XCTAssertEqual(Rule.verdict(saved: "a", keychain: .value("b")), .moved)
  }

  /// The Keychain outlives a delete of the app and the preferences do not.
  func testAReinstallOnTheSamePhoneHasNotMoved() {
    XCTAssertEqual(Rule.verdict(saved: nil, keychain: .value("b")), .same)
    XCTAssertEqual(Rule.verdict(saved: "", keychain: .value("b")), .same)
  }

  /// Before the first unlock after a restart the Keychain cannot be asked.
  /// That must never read as a missing item, or a restart would wipe.
  func testAKeychainThatCannotBeAskedDecidesNothing() {
    XCTAssertEqual(Rule.verdict(saved: "a", keychain: .unreadable), .unknown)
    XCTAssertEqual(Rule.verdict(saved: nil, keychain: .unreadable), .unknown)
  }
}

/// The marker against the real Keychain and a preferences suite of its own.
final class InstallMarkerTests: XCTestCase {
  private let suite = "install-marker-tests"
  private var defaults: UserDefaults!
  private var marker: InstallMarker!

  override func setUpWithError() throws {
    defaults = UserDefaults(suiteName: suite)
    defaults.removePersistentDomain(forName: suite)
    marker = InstallMarker(defaults: defaults, service: "app.critalarm.install_marker.tests")
    marker.removeAll()
    // A machine with no keychain entitlement for this bundle cannot answer
    // these, and that is about the machine, not about the code.
    try XCTSkipIf(!marker.settle(), "no keychain access here")
    marker.removeAll()
  }

  override func tearDown() {
    marker?.removeAll()
    defaults?.removePersistentDomain(forName: suite)
  }

  private var saved: String? { defaults.string(forKey: InstallMarker.defaultsKey) }

  func testTheItemNeverLeavesThisPhone() {
    XCTAssertEqual(
      InstallMarker.accessibility as String,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
    XCTAssertEqual(marker.query()[kSecAttrSynchronizable as String] as? NSNumber, false)

    XCTAssertTrue(marker.settle())
    var read = marker.query()
    read[kSecReturnAttributes as String] = true
    read[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, &item), errSecSuccess)
    let attributes = item as? [String: Any]
    XCTAssertEqual(
      attributes?[kSecAttrAccessible as String] as? String,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
  }

  func testAFirstLaunchWritesBothCopies() {
    XCTAssertEqual(marker.check(), .first)
    let id = saved
    XCTAssertNotNil(id)
    XCTAssertEqual(marker.readKeychain(), .value(id ?? ""))
    XCTAssertEqual(marker.check(), .same)
    XCTAssertEqual(saved, id)
  }

  func testRestoredPreferencesReadAsMovedUntilSettled() {
    // What a backup from another phone leaves: the preferences copy alone.
    defaults.set("from-the-old-phone", forKey: InstallMarker.defaultsKey)

    XCTAssertEqual(marker.check(), .moved)
    // Nothing is settled by the check, so a launch that died halfway
    // through the drop answers moved again.
    XCTAssertEqual(saved, "from-the-old-phone")
    XCTAssertEqual(marker.check(), .moved)

    XCTAssertTrue(marker.settle())
    XCTAssertNotEqual(saved, "from-the-old-phone")
    XCTAssertEqual(marker.check(), .same)
  }

  func testAPhoneWithItsOwnMarkerStillSeesRestoredPreferencesAsMoved() {
    XCTAssertTrue(marker.settle())
    defaults.set("from-the-old-phone", forKey: InstallMarker.defaultsKey)
    XCTAssertEqual(marker.check(), .moved)
  }

  func testAReinstallGetsItsPreferencesCopyBack() {
    XCTAssertTrue(marker.settle())
    let id = saved
    defaults.removeObject(forKey: InstallMarker.defaultsKey)

    XCTAssertEqual(marker.check(), .same)
    XCTAssertEqual(saved, id)
  }
}
