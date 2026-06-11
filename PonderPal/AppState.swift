import Foundation
import Combine

// MARK: - Data Models

struct AnswerEntry: Codable {
    var content: String
    var visible: Bool
}

struct FriendSnapshot: Codable {
    var answers: [String: AnswerEntry]
    var syncedAt: Double
}

struct FriendEntry: Codable, Identifiable {
    var id: String { name }
    var name: String
    var snapshot: FriendSnapshot?
}



// MARK: - AppState

class AppState: ObservableObject {

    // ── Persisted state ────────────────────────────────────────────────
    @Published var username: String        = ""
    @Published var answers:  [String: AnswerEntry] = [:]   // key = "qId_year"
    @Published var friends:  [FriendEntry] = []
    @Published var language: String        = "zh"

    // ── Transient UI state ─────────────────────────────────────────────
    @Published var selectedTab: Tab        = .today
    @Published var syncBusy:    Bool       = false

    enum Tab { case today, history, friends }

    private let defaults = UserDefaults.standard
    private var syncTask: Task<Void, Never>?

    init() {
        load()
        // Detect system language on first launch
        if defaults.string(forKey: "dr_lang") == nil {
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            language = code.hasPrefix("zh") ? "zh" : "en"
        }
    }

    // MARK: - Persistence

    func load() {
        username = defaults.string(forKey: "dr_username") ?? ""
        language = defaults.string(forKey: "dr_lang") ?? "zh"

        if let data = defaults.data(forKey: "dr_answers"),
           let decoded = try? JSONDecoder().decode([String: AnswerEntry].self, from: data) {
            answers = decoded
        }
        if let data = defaults.data(forKey: "dr_friends"),
           let decoded = try? JSONDecoder().decode([FriendEntry].self, from: data) {
            friends = decoded
        }
    }

    func save() {
        defaults.set(username, forKey: "dr_username")
        defaults.set(language, forKey: "dr_lang")
        if let data = try? JSONEncoder().encode(answers) { defaults.set(data, forKey: "dr_answers") }
        if let data = try? JSONEncoder().encode(friends) { defaults.set(data, forKey: "dr_friends") }
    }

    // MARK: - Today helpers

    /// Returns (qId: 1…210, year: Int) for the current date.
    func todayInfo() -> (qId: Int, year: Int) {
        let cal  = Calendar.current
        let now  = Date()
        let year = cal.component(.year, from: now)
        let day  = cal.ordinality(of: .day, in: .year, for: now) ?? 1
        let qId  = ((day - 1) % Questions.count) + 1
        return (qId, year)
    }

    func answerKey(_ qId: Int, _ year: Int) -> String { "\(qId)_\(year)" }

    func hasAnsweredToday() -> Bool {
        let (qId, year) = todayInfo()
        return answers[answerKey(qId, year)] != nil
    }

    var isLoggedIn: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Share code (v3 — username only, UTF-8 base64)

    func generateShareCode() -> String {
        let payload = ["v": 3, "n": username] as [String: Any]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return Data(json.utf8).base64EncodedString()
    }

    /// Parses a v3 or legacy v2 share code, returns the friend's username or nil.
    func parseFriendCode(_ raw: String) -> String? {
        guard let bytes = Data(base64Encoded: raw) else { return nil }

        // v3: plain UTF-8 JSON
        if let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
            if let v = json["v"] as? Int, v == 3, let name = json["n"] as? String { return name }
            // v2 without percent encoding
            if let name = json["name"] as? String { return name }
        }

        // v2: percent-encoded UTF-8 JSON
        if let str      = String(data: bytes, encoding: .utf8),
           let decoded  = str.removingPercentEncoding,
           let jsonData = decoded.data(using: .utf8),
           let json     = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let name     = json["name"] as? String {
            return name
        }
        return nil
    }

    // MARK: - Server sync

    func syncToServer() {
        guard !username.isEmpty else { return }
        syncTask?.cancel()
        syncTask = Task {
            await APIService.syncAnswers(username: username, answers: answers)
        }
    }

    @MainActor
    func pullFriendsFromServer() async {
        guard !username.isEmpty else { return }
        syncBusy = true
        defer { syncBusy = false }

        let serverFriends = await APIService.getFriends(username: username)
        var changed = false

        for fname in serverFriends {
            guard let fetched = await APIService.getFriendAnswers(name: fname) else { continue }
            let snapshot = FriendSnapshot(answers: fetched, syncedAt: Date().timeIntervalSince1970)
            if let idx = friends.firstIndex(where: { $0.name == fname }) {
                friends[idx].snapshot = snapshot
            } else {
                friends.append(FriendEntry(name: fname, snapshot: snapshot))
            }
            changed = true
        }
        if changed { save() }
    }

    @MainActor
    func importFriend(code: String) async -> Result<String, ImportError> {
        guard !username.isEmpty else { return .failure(.notLoggedIn) }
        guard let friendName = parseFriendCode(code) else { return .failure(.invalidCode) }
        guard friendName != username else { return .failure(.selfImport) }

        // Link bidirectionally on server
        let serverAnswers = await APIService.linkFriend(me: username, friend: friendName)
        let snapshot = FriendSnapshot(
            answers: serverAnswers ?? [:],
            syncedAt: Date().timeIntervalSince1970
        )

        if let idx = friends.firstIndex(where: { $0.name == friendName }) {
            friends[idx].snapshot = snapshot
            save()
            return .success("updated:\(friendName)")
        } else {
            friends.append(FriendEntry(name: friendName, snapshot: snapshot))
            save()
            // Push my answers so friend can discover me
            syncToServer()
            return .success("added:\(friendName)")
        }
    }

    enum ImportError: Error {
        case invalidCode, selfImport, notLoggedIn
        
        func localizedDescription(language: String) -> String {
            switch self {
            case .invalidCode:
                return language == "zh" ? "分享码无效，请检查后重试" : "Invalid share code, please check and try again"
            case .selfImport:
                return language == "zh" ? "不能添加自己哦" : "You cannot add yourself"
            case .notLoggedIn:
                return language == "zh" ? "请先登录" : "Please log in first"
            }
        }
    }
}
