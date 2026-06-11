import SwiftUI

struct SettingsView: View {
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
            VStack(spacing: 24) {
                
                if state.isUserLoggedIn {
                    // 已登录状态 - 显示账户信息和设置
                    loggedInView
                } else {
                    // 未登录状态 - 显示登录/注册表单
                    authView
                }
                
                Spacer()

                
            }
            .padding(20)
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        }
    }
    
    // MARK: - 已登录状态视图
    
    private var loggedInView: some View {
        VStack(spacing: 20) {
            // 用户信息卡片
            VStack(spacing: 16) {
                Circle()
                    .fill(Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Text(String(state.username.prefix(1)).uppercased())
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 0.8))
                    }
                
                Text(state.username)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(state.language == "zh" ? "已登录" : "Logged In")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 2)
            
            // 登出按钮
            Button(action: {
                state.logout()
                clearInputs()
            }) {
                Text(state.language == "zh" ? "登出" : "Logout")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - 登录/注册视图
    
    private var authView: some View {
        VStack(spacing: 20) {
            // 登录/注册模式切换
            Picker("Auth Mode", selection: $authMode) {
                ForEach(AuthMode.allCases, id: \.self) { mode in
                    Text(mode.title(language: state.language))
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: authMode) { _ in
                clearError()
            }
            
            // 认证卡片
            VStack(alignment: .leading, spacing: 20) {
                Text(authMode.title(language: state.language))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
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
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.4, green: 0.6, blue: 0.8), lineWidth: 1)
                    )
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
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.4, green: 0.6, blue: 0.8), lineWidth: 1)
                    )
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
                
                // 认证按钮
                Button(action: performAuth) {
                    Text(authMode.title(language: state.language))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            authMode == .login 
                                ? Color(red: 0.45, green: 0.55, blue: 0.7)
                                : Color(red: 0.4, green: 0.6, blue: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty || 
                         passwordInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 2)
        }
    }
    
    
    // MARK: - Actions
    
    private func performAuth() {
        clearError()
        
        let result: Result<Void, AppState.AuthError>
        
        switch authMode {
        case .login:
            result = state.login(username: usernameInput, password: passwordInput)
        case .register:
            result = state.register(username: usernameInput, password: passwordInput)
        }
        
        switch result {
        case .success():
            // 认证成功，清空输入框
            clearInputs()
            
            // 同步到服务器
            state.syncToServer()
            Task {
                await state.pullFriendsFromServer()
            }
            
        case .failure(let error):
            // 显示错误
            withAnimation {
                authError = error.localizedDescription(language: state.language)
            }
            
            // 3秒后隐藏错误
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                clearError()
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
