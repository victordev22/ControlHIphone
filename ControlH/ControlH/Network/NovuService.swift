import Foundation

// Replaces NovuManager — uses its own URLSession (no JWT header)
final class NovuService {
    static let shared = NovuService()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        return URLSession(configuration: cfg)
    }()

    private let base = Constants.baseNovuURL
    private var apiKey: String { Constants.novuAPIKey }

    private init() {}

    // MARK: Bind FCM/APNs device token

    func vincularDispositivo(email: String, deviceToken: String) async {
        for attempt in 1...3 {
            do {
                let body: [String: Any] = [
                    "providerId": "apns",
                    "integrationIdentifier": "apns",
                    "credentials": ["deviceTokens": [deviceToken]]
                ]
                let data = try JSONSerialization.data(withJSONObject: body)
                let path = "subscribers/\(email.urlEncoded)/credentials"
                _ = try await put(path: path, body: data)
                TokenManager.shared.saveNovuEmail(email)
                return
            } catch {
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }
    }

    // MARK: Trigger notification event

    func enviarNotificacion(email: String) async {
        do {
            let body: [String: Any] = [
                "name": Constants.novuWorkflow,
                "to": ["subscriberId": email],
                "payload": ["mensaje": "Tu equipo sigue encendido. Por favor, apágalo al terminar."]
            ]
            let data = try JSONSerialization.data(withJSONObject: body)
            _ = try await post(path: "events/trigger", body: data)
        } catch {
            // Notification failure is non-fatal
        }
    }

    // MARK: Helpers

    private func put(path: String, body: Data) async throws -> Data {
        let url = URL(string: base + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ApiKey \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return data
    }

    private func post(path: String, body: Data) async throws -> Data {
        let url = URL(string: base + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ApiKey \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return data
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
