import Security
import XCTest

@testable import Runner

/// The two items api.md §4.2 describes, and the attribute that keeps them
/// apart. Getting `kSecAttrSynchronizable` wrong here is the one mistake that
/// makes every item already on a phone invisible.
final class DeviceIdentityKeychainTests: XCTestCase {
  private func query(_ service: String, _ sync: Any) -> [String: Any] {
    let built = DeviceIdentityKeychain.itemQuery([
      "service": service,
      "synchronizable": sync,
    ])
    return built ?? [:]
  }

  func testAccountItemSyncsThroughICloud() {
    let built = query("app.critalarm.account", true)
    XCTAssertEqual(built[kSecAttrService as String] as? String, "app.critalarm.account")
    XCTAssertEqual(built[kSecAttrAccount as String] as? String, "identity")
    XCTAssertEqual(built[kSecAttrSynchronizable as String] as? NSNumber, true)
  }

  func testDeviceItemDoesNotSync() {
    let built = query("app.critalarm.device_identity", false)
    XCTAssertEqual(
      built[kSecAttrService as String] as? String, "app.critalarm.device_identity")
    XCTAssertEqual(built[kSecAttrSynchronizable as String] as? NSNumber, false)
  }

  /// The read the migration cannot do without: it finds the old synced copy
  /// and the new unsynced one.
  func testAnyFindsBothCopies() {
    let built = query("app.critalarm.device_identity", "any")
    let sync = built[kSecAttrSynchronizable as String]
    XCTAssertEqual(sync as? String, kSecAttrSynchronizableAny as String)
  }

  func testAnUnnamedItemIsRefused() {
    XCTAssertNil(DeviceIdentityKeychain.itemQuery(nil))
    XCTAssertNil(DeviceIdentityKeychain.itemQuery(["service": "app.critalarm.account"]))
    XCTAssertNil(
      DeviceIdentityKeychain.itemQuery([
        "service": "app.critalarm.account", "synchronizable": "sometimes",
      ]))
  }

  /// Writes the unsynced device item and reads it back, so the query the app
  /// builds is proved against the real Keychain and not only against itself.
  func testTheDeviceItemReadsBackWhatWasWritten() throws {
    var add = query("app.critalarm.device_identity", false)
    SecItemDelete(add as CFDictionary)
    let payload = #"{"device_id":"dev_test"}"#
    add[kSecValueData as String] = Data(payload.utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let added = SecItemAdd(add as CFDictionary, nil)
    // A machine with no keychain entitlement for this bundle cannot answer
    // this one, and that is about the machine, not about the code.
    try XCTSkipIf(added == errSecMissingEntitlement, "no keychain access here")
    XCTAssertEqual(added, errSecSuccess)

    var read = query("app.critalarm.device_identity", false)
    read[kSecReturnData as String] = true
    read[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, &item), errSecSuccess)
    XCTAssertEqual(item as? Data, Data(payload.utf8))

    // The synced item is a different item, so the same read with the flag
    // flipped finds nothing.
    var synced = query("app.critalarm.device_identity", true)
    synced[kSecReturnData as String] = true
    synced[kSecMatchLimit as String] = kSecMatchLimitOne
    var other: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(synced as CFDictionary, &other), errSecItemNotFound)

    SecItemDelete(query("app.critalarm.device_identity", false) as CFDictionary)
  }
}
