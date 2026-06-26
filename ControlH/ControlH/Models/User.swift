import Foundation

// MARK: - Role

struct Role: Codable, Identifiable {
    let erole: String
    var id: String { erole }
}

// MARK: - User (in-memory session, no of_control)

struct User: Codable {
    let nickname: String
    let email: String
    let roles: [Role]
    let role: String?

    var isAdmin: Bool {
        role == "ROLE_ADMIN" || roles.contains(where: { $0.erole == "ROLE_ADMIN" })
    }
}

// MARK: - UserMe  (/auth/me — of_control is never returned here)

struct UserMe: Codable {
    let token: String?
    let email: String?
    let nickname: String?
    let roles: [String]?
    let of_control: String?
}

// MARK: - UserFull  (/auth/admin/user/{email} — has of_control)

struct UserFull: Codable, Identifiable {
    let id: Int
    var nickname: String?
    var email: String?
    var password: String?
    var on_control: String?
    var of_control: String?
    var roles: [Role]
    var role: String?

    // Extra PC info fields
    var version_windows: String?
    var password_pc: String?
    var password_nas1: String?
    var password_2: String?
    var memoria_ram: String?
    var cpu: String?
    var tarjeta_grafica: String?
    var puerto_escritorio_remoto: String?
    var direccion_ip: String?
    var mac: String?
    var procesador: String?
    var tipo_de_estacion: String?
    var nombre_user: String?
    var localizacion: String?
    var estado: String?

    var isAdmin: Bool {
        role == "ROLE_ADMIN" || roles.contains(where: { $0.erole == "ROLE_ADMIN" })
    }
}
