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

struct APIClient: Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HomeHub-iOS/1.0", forHTTPHeaderField: "User-Agent")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.api.encode(body)
        }

        let (data, response) = try await session.data(for: request)
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
            throw APIError.decodingError(error.localizedDescription)
        }
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
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HomeHub-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
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
            throw APIError.decodingError(error.localizedDescription)
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HomeHub-iOS/1.0", forHTTPHeaderField: "User-Agent")

        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.api.encode(jsonBody)
        }

        let (data, response) = try await session.data(for: request)
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
        if let error = try? JSONDecoder.api.decode(ErrorResponse.self, from: data).error,
           !error.isEmpty {
            return error
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        if body.contains("<!DOCTYPE") || body.contains("<html") {
            switch statusCode {
            case 404:
                return """
                The server does not have the mobile API yet (404). \
                Deploy the latest Home Hub backend, or point HOMEHUB_API_URL at a local dev server.
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
}

struct ErrorResponse: Decodable, Sendable {
    let error: String
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
