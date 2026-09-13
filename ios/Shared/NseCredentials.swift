import Foundation

/// The server URL and the `dv_` management token, in the keychain both the app
/// and the Notification Service Extension can read.
///
/// The extension runs in its own process with its own container, so the app's
/// preferences are out of reach. api.md §5.1 gives it ten seconds to turn a
/// `relay_content: none` push into real text, and the call in §3.2 needs both
/// of these. Dart writes them through `NseCredentialStore`.
enum NseCredentials {
    struct Session {
        let server: URL
        let token: String
    }

    static let service = "app.critalarm.nse"
    static let account = "session"

    /// The shared group both targets carry in `keychain-access-groups`.
    ///
    /// The simulator has no signed entitlements and keeps one keychain for
    /// everything on it, and asking for a group there fails with -34018. So
    /// the group is only named on a device, where it is the thing that lets
    /// the extension read what the app wrote.
    static var accessGroup: String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        return Bundle.main.object(forInfoDictionaryKey: "CritAlarmKeychainGroup") as? String
        #endif
    }

    private static func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    static func write(server: String, token: String) {
        let payload = ["server": server, "token": token]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var query = baseQuery()
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        // The extension has to read this while the phone is locked, which is
        // the whole point of the alarm.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    static func read() -> Session? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let server = json["server"].flatMap(URL.init(string:)),
              let token = json["token"], !token.isEmpty
        else { return nil }

        return Session(server: server, token: token)
    }
}
