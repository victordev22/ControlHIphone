import Foundation

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "URL inválida"
        case .invalidResponse:        return "Respuesta inválida del servidor"
        case .unauthorized:           return "Sesión expirada. Inicia sesión de nuevo"
        case .serverError(let c, let m): return "Error \(c): \(m)"
        case .decodingError(let e):   return "Error procesando datos: \(e.localizedDescription)"
        case .networkError(let e):    return "Error de red: \(e.localizedDescription)"
        }
    }
}

// MARK: - Date decoding strategy helpers

extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        // Try milliseconds first (Java Date default), fall back to ISO-8601
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            // milliseconds since epoch (long integer)
            if let ms = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: ms / 1000)
            }
            // ISO-8601 string
            let str = try container.decode(String.self)
            let isoFull = ISO8601DateFormatter()
            isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoFull.date(from: str) { return d }
            isoFull.formatOptions = [.withInternetDateTime]
            if let d = isoFull.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot decode date: \(str)")
        }
        return decoder
    }
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    // MARK: Helpers

    private func request(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = TokenManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    private func buildURL(_ base: String, path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard var components = URLComponents(string: base + path) else {
            throw APIError.invalidURL
        }
        if let qi = queryItems { components.queryItems = qi }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    // MARK: Execute

    @discardableResult
    private func execute(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, http)
    }

    // MARK: GET

    func get<T: Decodable>(_ base: String, path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let url = try buildURL(base, path: path, queryItems: queryItems)
        let (data, http) = try await execute(request(url: url))
        try assertStatus(http, data: data)
        do {
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // GET returning raw String
    func getString(_ base: String, path: String) async throws -> String {
        let url = try buildURL(base, path: path)
        let (data, http) = try await execute(request(url: url))
        try assertStatus(http, data: data)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: POST

    func post<T: Decodable, B: Encodable>(_ base: String, path: String, body: B) async throws -> T {
        let encoded = try JSONEncoder().encode(body)
        let url = try buildURL(base, path: path)
        let (data, http) = try await execute(request(url: url, method: "POST", body: encoded))
        try assertStatus(http, data: data)
        do {
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // POST returning raw String body
    func postRaw<B: Encodable>(_ base: String, path: String, body: B) async throws -> String {
        let encoded = try JSONEncoder().encode(body)
        let url = try buildURL(base, path: path)
        let (data, http) = try await execute(request(url: url, method: "POST", body: encoded))
        try assertStatus(http, data: data)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: POST with raw Data body (used by NovuService)

    func postRawData<T: Decodable>(_ base: String, path: String, body: Data, extraHeaders: [String: String] = [:]) async throws -> T {
        let url = try buildURL(base, path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body
        let (data, http) = try await execute(req)
        try assertStatus(http, data: data)
        do {
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: PATCH

    func patch<T: Decodable, B: Encodable>(_ base: String, path: String, body: B) async throws -> T {
        let encoded = try JSONEncoder().encode(body)
        let url = try buildURL(base, path: path)
        let (data, http) = try await execute(request(url: url, method: "PATCH", body: encoded))
        try assertStatus(http, data: data)
        do {
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: PUT

    func put<T: Decodable, B: Encodable>(_ base: String, path: String, body: B) async throws -> T {
        let encoded = try JSONEncoder().encode(body)
        let url = try buildURL(base, path: path)
        let (data, http) = try await execute(request(url: url, method: "PUT", body: encoded))
        try assertStatus(http, data: data)
        do {
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: DELETE

    func delete(_ base: String, path: String) async throws {
        let url = try buildURL(base, path: path)
        let (data, http) = try await execute(request(url: url, method: "DELETE"))
        if http.statusCode == 401 { throw APIError.unauthorized }
        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode, msg)
        }
    }

    // MARK: GET with query string (SSH execute)

    func getVoid(_ base: String, path: String, queryItems: [URLQueryItem]) async throws {
        let url = try buildURL(base, path: path, queryItems: queryItems)
        let (data, http) = try await execute(request(url: url))
        try assertStatus(http, data: data)
    }

    // MARK: Status check

    private func assertStatus(_ http: HTTPURLResponse, data: Data) throws {
        if http.statusCode == 401 { throw APIError.unauthorized }
        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode, msg)
        }
    }
}
