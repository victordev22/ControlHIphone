import Foundation

enum Constants {
    static let baseControlURL  = "https://control.meta4bim.com/"
    static let baseAuthURL     = "https://auth.meta4bim.com/"
    static let baseNovuURL     = "http://4.245.229.134:3000/v1/"
    static let baseSSHURL      = "http://4.245.225.143:8087/"

    static let pathHoras       = "control/listhoras"
    static let pathUsers       = "auth/admin/users"

    // Keycloak / AppAuth
    static let keycloakIssuer  = "https://keycloak.meta4bim.com/auth/realms/bim6d"
    static let clientID        = "client-movil"
    static let redirectURI     = "meta4bim://oauth"

    // Novu workflow
    static let novuWorkflow    = "horas-notification"

    // NOVU_API_KEY: add your key in Secrets.xcconfig or replace this placeholder
    static let novuAPIKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "NOVU_API_KEY") as? String ?? ""
    }()
}
