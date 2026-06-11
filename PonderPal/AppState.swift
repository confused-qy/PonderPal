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
    @Published var isLoggedIn: Bool        = false
    @Published var authToken: String?      = nil
    @Published var authBusy: Bool          = false

    // ── Transient UI state ─────────────────────────────────────────────
    @Published var selectedTab: Tab        = .today
    @Published var syncBusy:    Bool       = false

    enum Tab { case today, history, friends, settings }

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
        authToken = KeychainService.loadToken()
        isLoggedIn = authToken != nil && !username.trimmingCharacters(in: .whitespaces).isEmpty

        if isLoggedIn {
            loadUserData(for: username)
        } else {
            clearUserData()
        }
    }

    func save() {
        defaults.set(username, forKey: "dr_username")
        defaults.set(language, forKey: "dr_lang")
        defaults.set(isLoggedIn, forKey: "dr_isLoggedIn")

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        if !trimmedUsername.isEmpty {
            saveUserData(for: trimmedUsername)
        }
    }

    private func answersKey(for username: String) -> String {
        "dr_answers_\(username)"
    }

    private func friendsKey(for username: String) -> String {
        "dr_friends_\(username)"
    }

    private func loadUserData(for username: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedUsername.isEmpty else {
            clearUserData()
            return
        }

        if let data = defaults.data(forKey: answersKey(for: trimmedUsername)),
           let decoded = try? JSONDecoder().decode([String: AnswerEntry].self, from: data) {
            answers = decoded
        } else {
            answers = [:]
        }

        if let data = defaults.data(forKey: friendsKey(for: trimmedUsername)),
           let decoded = try? JSONDecoder().decode([FriendEntry].self, from: data) {
            friends = decoded
        } else {
            friends = []
        }
    }

    private func saveUserData(for username: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedUsername.isEmpty else { return }

        if let data = try? JSONEncoder().encode(answers) {
            defaults.set(data, forKey: answersKey(for: trimmedUsername))
        }
        if let data = try? JSONEncoder().encode(friends) {
            defaults.set(data, forKey: friendsKey(for: trimmedUsername))
        }
    }

    private func clearUserData() {
        answers = [:]
        friends = []
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

    var isUserLoggedIn: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && isLoggedIn && authToken != nil
    }

    // MARK: - Login/Register Methods
    
    enum AuthError: Error {
        case emptyFields
        case userAlreadyExists
        case userNotFound
        case incorrectPassword
        case network(String)
        
        func localizedDescription(language: String) -> String {
            switch self {
            case .emptyFields:
                return language == "zh" ? "用户名和密码不能为空" : "Username and password cannot be empty"
            case .userAlreadyExists:
                return language == "zh" ? "用户名已存在" : "User already exists"
            case .userNotFound:
                return language == "zh" ? "用户不存在" : "User not found"
            case .incorrectPassword:
                return language == "zh" ? "密码错误" : "Incorrect password"
            case .network(let message):
                return message
            }
        }
    }
    
    @MainActor
    func register(username: String, password: String) async -> Result<Void, AuthError> {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedUsername.isEmpty && !trimmedPassword.isEmpty else {
            return .failure(.emptyFields)
        }
        
        authBusy = true
        defer { authBusy = false }

        do {
            try await APIService.register(username: trimmedUsername, password: trimmedPassword)
            return await login(username: trimmedUsername, password: trimmedPassword)
        } catch {
            return .failure(mapAuthError(error))
        }
    }
    
    @MainActor
    func login(username: String, password: String) async -> Result<Void, AuthError> {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedUsername.isEmpty && !trimmedPassword.isEmpty else {
            return .failure(.emptyFields)
        }
        
        authBusy = true
        defer { authBusy = false }

        do {
            let response = try await APIService.login(username: trimmedUsername, password: trimmedPassword)
            authToken = response.token
            KeychainService.saveToken(response.token)
            self.username = response.user.username
            self.isLoggedIn = true
            loadUserData(for: response.user.username)
            save()
            return .success(())
        } catch {
            return .failure(mapAuthError(error))
        }
    }
    
    func logout() {
        let currentUsername = username.trimmingCharacters(in: .whitespaces)
        if !currentUsername.isEmpty {
            saveUserData(for: currentUsername)
        }

        username = ""
        isLoggedIn = false
        authToken = nil
        clearUserData()
        KeychainService.deleteToken()
        
        defaults.removeObject(forKey: "dr_username")
        defaults.removeObject(forKey: "dr_isLoggedIn")
        
        save()
    }

    private func mapAuthError(_ error: Error) -> AuthError {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("already exists") {
            return .userAlreadyExists
        }
        if message.localizedCaseInsensitiveContains("invalid username or password") {
            return .incorrectPassword
        }
        if message.localizedCaseInsensitiveContains("not found") {
            return .userNotFound
        }
        return .network(message)
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
        guard isUserLoggedIn, let token = authToken else { return }
        syncTask?.cancel()
        syncTask = Task {
            await APIService.syncAnswers(username: username, answers: answers, token: token)
        }
    }

    @MainActor
    func pullFriendsFromServer() async {
        guard isUserLoggedIn, let token = authToken else { return }
        syncBusy = true
        defer { syncBusy = false }

        let serverFriends = await APIService.getFriends(username: username, token: token)
        var changed = false

        for fname in serverFriends {
            guard let fetched = await APIService.getFriendAnswers(name: fname, token: token) else { continue }
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
        guard isUserLoggedIn, let token = authToken else { return .failure(.notLoggedIn) }
        guard let friendName = parseFriendCode(code) else { return .failure(.invalidCode) }
        guard friendName != username else { return .failure(.selfImport) }

        // Link bidirectionally on server
        let serverAnswers = await APIService.linkFriend(me: username, friend: friendName, token: token)
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
