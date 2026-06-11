import Foundation

/// All network calls to the PonderPal backend.
/// Uses async/await — call from a Task or .task {} modifier.
enum APIService {

    // Simulator local backend. For a physical iPhone, use your Mac's LAN IP,
    // for example: http://192.168.1.23:3000/api/daily_reflect
    static let base = "http://localhost:3000/api/daily_reflect"

    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server URL"
            case .invalidResponse:
                return "Invalid server response"
            case .server(let message):
                return message
            }
        }
    }

    struct AuthResponse: Decodable {
        let token: String
        let user: User

        struct User: Decodable {
            let username: String
        }
    }

    // MARK: - Authentication

    static func register(username: String, password: String) async throws {
        guard let url = URL(string: "\(base)/register") else { throw APIError.invalidURL }
        let payload = ["username": username, "password": password]
        let body = try JSONSerialization.data(withJSONObject: payload)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        _ = try await send(req)
    }

    static func login(username: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(base)/login") else { throw APIError.invalidURL }
        let payload = ["username": username, "password": password]
        let body = try JSONSerialization.data(withJSONObject: payload)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let data = try await send(req)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    // MARK: - Sync user's visible answers

    static func syncAnswers(username: String, answers: [String: AnswerEntry], token: String) async {
        guard let url = URL(string: "\(base)/sync") else { return }
        let payload: [String: Any] = [
            "username": username,
            "answers": answers.mapValues { ["content": $0.content, "visible": $0.visible] }
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&req, token: token)
        req.httpBody = body
        _ = try? await send(req)
    }

    // MARK: - Get friend list

    static func getFriends(username: String, token: String) async -> [String] {
        guard let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(base)/friends?me=\(encoded)") else { return [] }
        var req = URLRequest(url: url)
        authorize(&req, token: token)
        guard let data = try? await send(req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["friends"] as? [String] else { return [] }
        return list
    }

    // MARK: - Link friend bidirectionally

    /// Links `me` ↔ `friend` on the server and returns the friend's latest answers.
    static func linkFriend(me: String, friend: String, token: String) async -> [String: AnswerEntry]? {
        guard let url = URL(string: "\(base)/friend/link") else { return nil }
        let payload: [String: Any] = ["me": me, "friend": friend]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&req, token: token)
        req.httpBody = body
        guard let data = try? await send(req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw  = json["friend_answers"] as? [String: [String: Any]] else { return nil }
        return parseAnswerDict(raw)
    }

    // MARK: - Get friend's answers

    static func getFriendAnswers(name: String, token: String) async -> [String: AnswerEntry]? {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/friend/\(encoded)/answers") else { return nil }
        var req = URLRequest(url: url)
        authorize(&req, token: token)
        guard let data = try? await send(req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw  = json["answers"] as? [String: [String: Any]] else { return nil }
        return parseAnswerDict(raw)
    }

    // MARK: - Private helpers

    private static func authorize(_ req: inout URLRequest, token: String) {
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private static func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = parseErrorMessage(data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(message)
        }
        return data
    }

    private static func parseErrorMessage(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["error"] as? String
    }

    private static func parseAnswerDict(_ raw: [String: [String: Any]]) -> [String: AnswerEntry] {
        raw.compactMapValues { dict in
            guard let content = dict["content"] as? String else { return nil }
            return AnswerEntry(content: content, visible: true)
        }
    }
}
