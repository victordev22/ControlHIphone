import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct SignupRequest: Encodable {
    let nickname: String
    let email: String
    let password: String
}

struct JwtResponse: Decodable {
    let token: String
    let email: String?
    let nickname: String?
    let roles: [String]?
}

struct UpdateUserRequest: Encodable {
    var nickname: String?
    var email: String?
    var on_control: String?
    var of_control: String?
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
}
