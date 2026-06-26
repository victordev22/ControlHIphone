import Foundation

struct Horas: Codable, Identifiable, Hashable, Equatable {
    let id: Int
    let user: String
    let hora_encendido: Date?
    let hora_apagado: Date?
    let minutosInactivo: Int?
    let listaApps: String?

    var isOn: Bool { hora_apagado == nil }

    var durationSeconds: TimeInterval {
        guard let start = hora_encendido else { return 0 }
        let end = hora_apagado ?? Date()
        return max(0, end.timeIntervalSince(start))
    }

    var durationFormatted: String {
        let s = Int(durationSeconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
