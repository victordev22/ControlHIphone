import Foundation
import SwiftUI
import Observation
import AuthenticationServices

@MainActor
@Observable
final class AuthViewModel {

    // MARK: Form fields
    var email    = ""
    var password = ""
    var nickname = ""

    // MARK: State
    var isLoginScreen    = true
    var isAuthenticated  = false
    var isLoading        = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: User data
    var currentUser: User?
    var userData: UserFull?

    private let authService  = AuthService.shared
    private let tokenManager = TokenManager.shared
    private var keycloakSession: ASWebAuthenticationSession?

    init() {
        let token = tokenManager.getToken()
        isAuthenticated = token != nil
        if let token { parseTokenAndPopulateUser(token) }
    }

    // MARK: - JWT parsing (Keycloak format)

    private func parseTokenAndPopulateUser(_ token: String) {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count >= 2,
              let payloadData = Data(base64URLEncoded: parts[1]),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { return }

        let email    = json["email"] as? String ?? ""
        let nickname = (json["preferred_username"] as? String) ?? (json["sub"] as? String ?? "")

        var roles: [Role] = []
        if let realmAccess = json["realm_access"] as? [String: Any],
           let rolesArray  = realmAccess["roles"] as? [String] {
            roles = rolesArray.map { Role(erole: $0) }
        }
        let principalRole = roles.first(where: { $0.erole == "ROLE_ADMIN" })?.erole
                         ?? roles.first?.erole

        currentUser = User(nickname: nickname, email: email, roles: roles, role: principalRole)
        userData = UserFull(id: 0, nickname: nickname, email: email,
                            password: nil, on_control: "00:00:00", of_control: "00:00:00",
                            roles: roles, role: principalRole)
    }

    // MARK: - Form actions

    func toggleAuthScreen() {
        isLoginScreen.toggle()
        clearMessages()
        email = ""; password = ""; nickname = ""
    }

    // MARK: - Sign in

    func signIn() {
        isLoading = true
        clearMessages()
        Task {
            defer { isLoading = false }
            do {
                let response = try await authService.login(LoginRequest(email: email, password: password))
                tokenManager.saveToken(response.token)
                isAuthenticated = true
                successMessage  = "\(response.email ?? email) firmó correctamente"
                await fetchCurrentUser()
            } catch {
                errorMessage = errorDescription(error)
            }
        }
    }

    // MARK: - Sign up

    func signUp() {
        isLoading = true
        clearMessages()
        Task {
            defer { isLoading = false }
            do {
                let msg = try await authService.signup(SignupRequest(nickname: nickname, email: email, password: password))
                successMessage = msg.isEmpty ? "Cuenta registrada correctamente." : msg
                isLoginScreen  = true
            } catch {
                errorMessage = errorDescription(error)
            }
        }
    }

    // MARK: - Fetch current user profile

    func fetchCurrentUser() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userMe       = try await authService.getCurrentUser()
            let currentEmail = userMe.email ?? currentUser?.email ?? ""
            let mappedRoles  = (userMe.roles ?? []).map { Role(erole: $0) }
            let principalRole = mappedRoles.first(where: { $0.erole == "ROLE_ADMIN" })?.erole
                              ?? mappedRoles.first?.erole ?? "ROLE_USER"

            currentUser = User(nickname: userMe.nickname ?? "",
                               email: currentEmail,
                               roles: mappedRoles,
                               role: principalRole)

            if let nick = userMe.nickname { tokenManager.saveNickname(nick) }

            // /auth/me never returns of_control — fetch from detail endpoint
            if let ofControl = try? await authService.getUserByEmail(currentEmail).of_control,
               !ofControl.isEmpty {
                tokenManager.saveOfControl(ofControl)
                userData = UserFull(id: 0, nickname: userMe.nickname, email: currentEmail,
                                    password: nil, on_control: "00:00:00", of_control: ofControl,
                                    roles: mappedRoles, role: principalRole)
            } else {
                userData = UserFull(id: 0, nickname: userMe.nickname, email: currentEmail,
                                    password: nil, on_control: "00:00:00",
                                    of_control: userMe.of_control ?? "00:00:00",
                                    roles: mappedRoles, role: principalRole)
            }

            await bindNovu(email: currentEmail)

        } catch APIError.unauthorized {
            clearLocalSession()
        } catch {
            // Non-fatal — user data already partially populated from token
        }
    }

    // MARK: - Keycloak SSO

    func signInWithKeycloak() {
        guard let authURL = buildKeycloakAuthURL() else { return }
        isLoading = true
        clearMessages()

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "meta4bim"
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            Task { @MainActor in
                defer { self.isLoading = false }
                if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return }
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    self.errorMessage = "No se recibió el código de autorización."
                    return
                }
                await self.exchangeKeycloakCode(code)
            }
        }
        session.presentationContextProvider = KeycloakPresentationContext.shared
        session.prefersEphemeralWebBrowserSession = false
        keycloakSession = session
        session.start()
    }

    private func buildKeycloakAuthURL() -> URL? {
        var components = URLComponents(string: Constants.keycloakIssuer + "/protocol/openid-connect/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id",     value: Constants.clientID),
            URLQueryItem(name: "redirect_uri",  value: Constants.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope",         value: "openid profile email"),
        ]
        return components?.url
    }

    private func exchangeKeycloakCode(_ code: String) async {
        guard let tokenURL = URL(string: Constants.keycloakIssuer + "/protocol/openid-connect/token") else { return }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyParams = [
            "grant_type=authorization_code",
            "client_id=\(Constants.clientID)",
            "code=\(code)",
            "redirect_uri=\(Constants.redirectURI)"
        ].joined(separator: "&")
        request.httpBody = bodyParams.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(KeycloakTokenResponse.self, from: data)
            tokenManager.saveToken(tokenResponse.access_token)
            isAuthenticated = true
            await fetchCurrentUser()
        } catch {
            errorMessage = "Error al autenticar con Keycloak: \(error.localizedDescription)"
        }
    }

    // MARK: - Logout

    func logout() {
        clearLocalSession()
        successMessage = "Sesión cerrada."
    }

    // MARK: - Session helpers

    func clearLocalSession() {
        tokenManager.clearToken()
        isAuthenticated = false
        currentUser     = nil
        userData        = nil
        email = ""; password = ""; nickname = ""
        isLoginScreen   = true
    }

    // MARK: - Novu device binding

    private func bindNovu(email: String) async {
        guard let token = AppState.shared.deviceToken else { return }
        await NovuService.shared.vincularDispositivo(email: email, deviceToken: token)
    }

    // MARK: - Helpers

    private func clearMessages() {
        errorMessage   = nil
        successMessage = nil
    }

    private func errorDescription(_ error: Error) -> String {
        (error as? APIError)?.errorDescription ?? error.localizedDescription
    }
}

// MARK: - Keycloak token response

private struct KeycloakTokenResponse: Decodable {
    let access_token: String
}

// MARK: - ASWebAuthenticationSession presentation context

final class KeycloakPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = KeycloakPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

// MARK: - Base64URL decoding helper

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 { base64 += String(repeating: "=", count: 4 - padding) }
        self.init(base64Encoded: base64)
    }
}
