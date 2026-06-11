import SwiftUI

/// Entry point: shows login screen or main tab view.
struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.isUserLoggedIn {
            MainTabView()
                .task {
                    // On launch: push local answers then pull friend updates
                    state.syncToServer()
                    await state.pullFriendsFromServer()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    Task { await state.pullFriendsFromServer() }
                }
        } else {
            LoginView()
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            TopNavigationBar()
            
            // 自定义标签栏
            CustomTabView()
            
            Spacer()
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97)) // 与截图一致的浅灰色背景
        .onChange(of: state.selectedTab) { tab in
            if tab == .friends || tab == .history || tab == .settings {
                Task { await state.pullFriendsFromServer() }
            }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @State private var usernameInput = ""
    @State private var passwordInput = ""
    @State private var authMode: AuthMode = .login
    @State private var authError: String? = nil
    @FocusState private var usernameFocused: Bool
    @FocusState private var passwordFocused: Bool
    
    enum AuthMode: String, CaseIterable {
        case login = "Login"
        case register = "Register"
        
        func title(language: String) -> String {
            switch self {
            case .login:
                return language == "zh" ? "登录" : "Login"
            case .register:
                return language == "zh" ? "注册" : "Register"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App icon + name
               VStack(spacing: 12) {
                   Image(systemName: "moon.stars.fill")
                       .font(.system(size: 56))
                       .foregroundStyle(.indigo)

                   Text(state.language == "zh" ? "念伴" : "PonderPal")
                       .font(.system(size: 34, weight: .semibold, design: .serif))

                   Text(
                       state.language == "zh"
                       ? "记录思绪，陪伴成长"
                       : "Your Reflection Companion"
                   )
                   .font(.subheadline)
                   .foregroundStyle(.secondary)
               }

                // 登录/注册切换
                Picker("Auth Mode", selection: $authMode) {
                    ForEach(AuthMode.allCases, id: \.self) { mode in
                        Text(mode.title(language: state.language))
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
                .onChange(of: authMode) { _ in
                    clearError()
                }

                // 认证表单
                VStack(alignment: .leading, spacing: 20) {
                    // 用户名输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.language == "zh" ? "用户名" : "Username")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        TextField(
                            state.language == "zh" ? "输入用户名" : "Enter username",
                            text: $usernameInput
                        )
                        .focused($usernameFocused)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            passwordFocused = true
                        }
                    }
                    
                    // 密码输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.language == "zh" ? "密码" : "Password")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        SecureField(
                            state.language == "zh" ? "输入密码" : "Enter password",
                            text: $passwordInput
                        )
                        .focused($passwordFocused)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .onSubmit {
                            performAuth()
                        }
                    }
                    
                    // 错误提示
                    if let error = authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 32)

                // 认证按钮
                Button(action: performAuth) {
                    Group {
                        if state.authBusy {
                            ProgressView()
                        } else {
                            Text(authMode.title(language: state.language))
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(authMode == .login ? .indigo : .green)
                .padding(.horizontal, 32)
                .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty || 
                         passwordInput.trimmingCharacters(in: .whitespaces).isEmpty ||
                         state.authBusy)

                Spacer()

                // Language toggle
                Button {
                    state.language = state.language == "zh" ? "en" : "zh"
                    state.save()
                } label: {
                    Text(state.language == "zh" ? "EN" : "中文")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
            }
            .onAppear { 
                usernameFocused = true 
            }
        }
    }

    private func performAuth() {
        clearError()

        Task {
            let result: Result<Void, AppState.AuthError>

            switch authMode {
            case .login:
                result = await state.login(username: usernameInput, password: passwordInput)
            case .register:
                result = await state.register(username: usernameInput, password: passwordInput)
            }

            switch result {
            case .success():
                clearInputs()
                state.syncToServer()
                await state.pullFriendsFromServer()

            case .failure(let error):
                withAnimation {
                    authError = error.localizedDescription(language: state.language)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    clearError()
                }
            }
        }
    }
    
    private func clearInputs() {
        usernameInput = ""
        passwordInput = ""
        usernameFocused = false
        passwordFocused = false
    }
    
    private func clearError() {
        withAnimation {
            authError = nil
        }
    }
}

// MARK: - Top Navigation Bar

struct TopNavigationBar: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        HStack {
            Text("Ponder Pal")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(state.isUserLoggedIn ? state.username : (state.language == "zh" ? "游客" : "Guest"))
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button {
                state.language = state.language == "zh" ? "en" : "zh"
                state.save()
            } label: {
                Text(state.language == "zh" ? "中" : "EN")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Custom Tab View

struct CustomTabView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab buttons
            HStack(spacing: 0) {
                ForEach([AppState.Tab.today, .history, .friends, .settings], id: \.self) { tab in
                    Button {
                        state.selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Text(tabTitle(for: tab))
                                .font(.body)
                                .fontWeight(state.selectedTab == tab ? .semibold : .regular)
                                .foregroundStyle(state.selectedTab == tab ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .background(Color(.systemBackground))
            
            // Underline for selected tab
            HStack(spacing: 0) {
                ForEach([AppState.Tab.today, .history, .friends, .settings], id: \.self) { tab in
                    Rectangle()
                        .fill(state.selectedTab == tab ? Color(red: 0.4, green: 0.6, blue: 0.8) : .clear)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .background(Color(.systemBackground))
            
            // Content
            Group {
                switch state.selectedTab {
                case .today:
                    TodayView()
                case .history:
                    HistoryView()
                case .friends:
                    FriendsView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
    
    private func tabTitle(for tab: AppState.Tab) -> String {
        switch tab {
        case .today:
            return state.language == "zh" ? "今日" : "Today"
        case .history:
            return state.language == "zh" ? "历史" : "History"
        case .friends:
            return state.language == "zh" ? "好友" : "Friends"
        case .settings:
            return state.language == "zh" ? "设置" : "Settings"
        }
    }
}
