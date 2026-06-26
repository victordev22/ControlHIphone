import Foundation

struct Incidencia: Codable, Identifiable {
    let id: Int
    let pc: PcRef
    let gestor_incidencia: String
    let incidencia: String
    let fecha: Date?
    let estado: String?
}

struct PcRef: Codable {
    var id: Int
    var nickname: String?
    var email: String?
    var of_control: String?
    var on_control: String?
}

struct CreateIncidenciaRequest: Encodable {
    let pc: PcRef
    let gestor_incidencia: String
    let incidencia: String
}

struct UpdateIncidenciaRequest: Encodable {
    var gestor_incidencia: String?
    var incidencia: String?
    var estado: String?
}
