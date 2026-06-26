import Foundation

final class IncidenciaService {
    static let shared = IncidenciaService()
    private let client = APIClient.shared
    private let base = Constants.baseControlURL   // incidencias live on the control server

    private init() {}

    func getIncidencias() async throws -> [Incidencia] {
        try await client.get(base, path: "api/incidencias")
    }

    func createIncidencia(_ req: CreateIncidenciaRequest) async throws -> Incidencia {
        try await client.post(base, path: "api/incidencias", body: req)
    }

    func updateIncidencia(id: Int, req: UpdateIncidenciaRequest) async throws -> Incidencia {
        try await client.put(base, path: "api/incidencias/\(id)", body: req)
    }

    func deleteIncidencia(id: Int) async throws {
        try await client.delete(base, path: "api/incidencias/\(id)")
    }
}
