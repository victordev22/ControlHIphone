import Foundation

final class ControlService {
    static let shared = ControlService()
    private let client = APIClient.shared
    private let base = Constants.baseControlURL

    private init() {}

    func getHoras() async throws -> [Horas] {
        try await client.get(base, path: Constants.pathHoras)
    }

    func getHoraById(_ id: Int) async throws -> Horas {
        try await client.get(base, path: "control/find/\(id)")
    }
}
