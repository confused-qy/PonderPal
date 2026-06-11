import Foundation

/// All network calls to the PonderPal backend.
/// Uses async/await — call from a Task or .task {} modifier.
enum APIService {

    static let base = "https://u-82df4907e5.tapi.ai/api/daily_reflect"

    // MARK: - Sync user's visible answers

    static func syncAnswers(username: String, answers: [String: AnswerEntry]) async {
        guard let url = URL(string: "\(base)/sync") else { return }
        let visible = answers.filter { $0.value.visible }
        let payload: [String: Any] = [
            "username": username,
            "answers": visible.mapValues { ["content": $0.content] }
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Get friend list

    static func getFriends(username: String) async -> [String] {
        guard let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(base)/friends?me=\(encoded)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["friends"] as? [String] else { return [] }
        return list
    }

    // MARK: - Link friend bidirectionally

    /// Links `me` ↔ `friend` on the server and returns the friend's latest answers.
    static func linkFriend(me: String, friend: String) async -> [String: AnswerEntry]? {
        guard let url = URL(string: "\(base)/friend/link") else { return nil }
        let payload: [String: Any] = ["me": me, "friend": friend]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw  = json["friend_answers"] as? [String: [String: Any]] else { return nil }
        return parseAnswerDict(raw)
    }

    // MARK: - Get friend's answers

    static func getFriendAnswers(name: String) async -> [String: AnswerEntry]? {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/friend/\(encoded)/answers") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw  = json["answers"] as? [String: [String: Any]] else { return nil }
        return parseAnswerDict(raw)
    }

    // MARK: - Private helpers

    private static func parseAnswerDict(_ raw: [String: [String: Any]]) -> [String: AnswerEntry] {
        raw.compactMapValues { dict in
            guard let content = dict["content"] as? String else { return nil }
            return AnswerEntry(content: content, visible: true)
        }
    }
}
