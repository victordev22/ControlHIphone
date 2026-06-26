import Foundation
import Security

// Replaces Android EncryptedSharedPreferences with iOS Keychain
final class TokenManager {
    static let shared = TokenManager()
    private init() {}

    private enum Key: String, CaseIterable {
        case jwtToken    = "controlh_jwt_token"
        case ofControl   = "controlh_of_control"
        case nickname    = "controlh_nickname"
        case novuEmail   = "controlh_novu_email"
    }

    // MARK: JWT

    func saveToken(_ token: String) { save(.jwtToken, value: token) }
    func getToken() -> String?      { load(.jwtToken) }
    func clearToken()               { delete(.jwtToken) }

    // MARK: of_control

    func saveOfControl(_ time: String) { save(.ofControl, value: time) }
    func getOfControl() -> String?     { load(.ofControl) }

    // MARK: Nickname

    func saveNickname(_ nickname: String) { save(.nickname, value: nickname) }
    func getNickname() -> String?         { load(.nickname) }

    // MARK: Novu email

    func saveNovuEmail(_ email: String) { save(.novuEmail, value: email) }
    func getNovuEmail() -> String?      { load(.novuEmail) }

    // MARK: Full clear

    func clearAll() {
        Key.allCases.forEach { delete($0) }
    }

    // MARK: - Keychain primitives

    private func save(_ key: Key, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var ref: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(_ key: Key) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}

