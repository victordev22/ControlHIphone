import Foundation

final class AuthService {
    static let shared = AuthService()
    private let client = APIClient.shared
    private let base = Constants.baseAuthURL

    private init() {}

    // MARK: Auth

    func login(_ req: LoginRequest) async throws -> JwtResponse {
        try await client.post(base, path: "auth/signin", body: req)
    }

    func signup(_ req: SignupRequest) async throws -> String {
        try await client.postRaw(base, path: "auth/signup", body: req)
    }

    // MARK: Current user

    func getCurrentUser() async throws -> UserMe {
        try await client.get(base, path: "auth/me")
    }

    // MARK: Admin

    func getAllUsers() async throws -> [UserFull] {
        try await client.get(base, path: "auth/admin/users")
    }

    func getUserByEmail(_ email: String) async throws -> UserFull {
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        return try await client.get(base, path: "auth/admin/user/\(encoded)")
    }

    func updateUserByEmail(_ email: String, request: UpdateUserRequest) async throws -> UserFull {
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        return try await client.patch(base, path: "auth/admin/user/\(encoded)", body: request)
    }

    func assignRole(email: String, roleName: String) async throws -> UserFull {
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        let encodedRole  = roleName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? roleName
        // POST with empty body
        struct Empty: Encodable {}
        return try await client.post(base, path: "auth/admin/user/\(encodedEmail)/role/\(encodedRole)", body: Empty())
    }

    func deleteUserByEmail(_ email: String) async throws {
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        try await client.delete(base, path: "auth/admin/user/\(encoded)")
    }

    // MARK: SSH

    func sendCommand(_ command: String) async throws {
        try await client.getVoid(Constants.baseSSHURL,
                                 path: "api/ssh/execute",
                                 queryItems: [URLQueryItem(name: "command", value: command)])
    }
}
