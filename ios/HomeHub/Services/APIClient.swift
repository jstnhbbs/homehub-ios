import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL."
        case .invalidResponse:
            "Unexpected server response."
        case .unauthorized:
            "You are not signed in."
        case .serverError(let message):
            message
        case .decodingError(let message):
            "Could not read server data: \(message)"
        }
    }
}

extension Error {
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if (self as? URLError)?.code == .cancelled { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    var userFacingMessage: String? {
        isCancellation ? nil : localizedDescription
    }
}

struct APIClient: Sendable {
    let baseURL: URL
    private let session: URLSession
    private let credentials: SessionCredentials

    /// A session that leaves cookies alone: the app keeps the sign-in cookie in the Keychain and sends
    /// it itself (see `SessionCredentials`), so the system's cookie storage must not also hold it.
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuration)
    }()

    init(baseURL: URL, session: URLSession = APIClient.defaultSession, credentials: SessionCredentials? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.credentials = credentials ?? SessionCredentials.shared(for: baseURL)
    }

    /// The server's own origin, such as "https://example.com" or "http://localhost:3000".
    ///
    /// The sign-in service (Better Auth) refuses any request that carries a cookie but no Origin
    /// header ("Missing or null Origin"), to stop other websites using a signed-in person's cookie.
    /// A native app has no origin of its own, so for the sign-in service's paths it presents the
    /// server's. Without this, signing out failed quietly (the session stayed valid on the server)
    /// and signing in again was refused while the old cookie was still held.
    static func origin(of baseURL: URL) -> String? {
        guard let scheme = baseURL.scheme, let host = baseURL.host else { return nil }
        if let port = baseURL.port { return "\(scheme)://\(host):\(port)" }
        return "\(scheme)://\(host)"
    }

    /// The paths served by the sign-in service rather than Beacon's own mobile API.
    static func isAuthPath(_ path: String) -> Bool {
        path.hasPrefix("/api/auth/")
    }

    private func addOriginIfNeeded(to request: inout URLRequest, path: String) {
        guard Self.isAuthPath(path), let origin = Self.origin(of: baseURL) else { return }
        request.setValue(origin, forHTTPHeaderField: "Origin")
    }

    /// Forgets the saved session for this server.
    func clearCookies() {
        credentials.clear()
    }

    /// Runs a request and keeps any cookies the server set or removed.
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else { throw APIError.invalidURL }
        let snapshot = credentials.snapshot(for: url)
        let generation = snapshot.generation
        var request = request
        request.setValue(snapshot.header, forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        guard generation == credentials.sessionGeneration else { throw CancellationError() }
        if let http = response as? HTTPURLResponse, let url = request.url {
            credentials.absorb(http, from: url, generation: generation)
        }
        return (data, response)
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authorized: Bool = true
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Beacon-iOS/1.0", forHTTPHeaderField: "User-Agent")
        addOriginIfNeeded(to: &request, path: path)

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.api.encode(body)
        }

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401, authorized {
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(APIClient.serverErrorMessage(statusCode: http.statusCode, data: data))
        }

        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(APIClient.decodingMessage(error))
        }
    }

    /// Fetches a raw response body, for file downloads such as the household export.
    func requestData(_ path: String, timeout: TimeInterval = 60) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Beacon-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(APIClient.serverErrorMessage(statusCode: http.statusCode, data: data))
        }
        return data
    }

    func requestVoid(
        _ path: String,
        method: String = "POST",
        body: (any Encodable)? = nil
    ) async throws {
        try await performRequest(path: path, method: method, jsonBody: body)
    }

    func uploadMultipart<T: Decodable>(
        _ path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Beacon-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(APIClient.serverErrorMessage(statusCode: http.statusCode, data: data))
        }

        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(APIClient.decodingMessage(error))
        }
    }

    private func performRequest(
        path: String,
        method: String,
        jsonBody: (any Encodable)? = nil
    ) async throws {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Beacon-iOS/1.0", forHTTPHeaderField: "User-Agent")
        addOriginIfNeeded(to: &request, path: path)

        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.api.encode(jsonBody)
        }

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(APIClient.serverErrorMessage(statusCode: http.statusCode, data: data))
        }
    }

    static func serverErrorMessage(statusCode: Int, data: Data) -> String {
        // Beacon's own routes answer {"error": "..."}; the sign-in service answers {"message": "..."}.
        if let response = try? JSONDecoder.api.decode(ErrorResponse.self, from: data),
           let text = response.error ?? response.message,
           !text.isEmpty {
            return text
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        if body.contains("<!DOCTYPE") || body.contains("<html") {
            switch statusCode {
            case 404:
                return """
                Beacon's server doesn't support this yet (404). \
                If you run your own server, deploy the latest version, or check the server address (HOMEHUB_API_URL).
                """
            default:
                return "Unexpected server response (\(statusCode))."
            }
        }

        if body.isEmpty {
            return "Request failed (\(statusCode))."
        }

        if body.count > 240 {
            return String(body.prefix(240)) + "…"
        }
        return body
    }

    static func decodingMessage(_ error: Error) -> String {
        func path(_ codingPath: [CodingKey]) -> String {
            let value = codingPath.map(\.stringValue).joined(separator: ".")
            return value.isEmpty ? "response" : value
        }

        switch error {
        case let DecodingError.keyNotFound(key, context):
            return "Missing \(path(context.codingPath + [key]))."
        case let DecodingError.valueNotFound(_, context):
            return "Missing value at \(path(context.codingPath))."
        case let DecodingError.typeMismatch(_, context):
            return "Unexpected value at \(path(context.codingPath)): \(context.debugDescription)"
        case let DecodingError.dataCorrupted(context):
            return "Invalid data at \(path(context.codingPath)): \(context.debugDescription)"
        default:
            return error.localizedDescription
        }
    }
}

struct ErrorResponse: Decodable, Sendable {
    var error: String?
    var message: String?
}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.fractional.date(from: value)
                ?? ISO8601DateFormatter().date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }
        return decoder
    }()
}

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
