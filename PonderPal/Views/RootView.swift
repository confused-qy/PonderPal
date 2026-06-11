import SwiftUI

/// Entry point: shows login screen or main tab view.
struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.isLoggedIn {
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
            if tab == .friends || tab == .history {
                Task { await state.pullFriendsFromServer() }
            }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App icon + name
                VStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.indigo)
                    Text("念伴")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                    Text("Ponder Pal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Username input
                VStack(alignment: .leading, spacing: 8) {
                    Text(state.language == "zh" ? "你的名字" : "Your name")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField(
                        state.language == "zh" ? "输入昵称…" : "Enter a nickname…",
                        text: $input
                    )
                    .focused($focused)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .autocorrectionDisabled()
                    .onSubmit { login() }
                }
                .padding(.horizontal, 32)

                Button(action: login) {
                    Text(state.language == "zh" ? "开始" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .padding(.horizontal, 32)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)

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
            .onAppear { focused = true }
        }
    }

    private func login() {
        let name = input.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        state.username = name
        state.save()
        Task {
            state.syncToServer()
            await state.pullFriendsFromServer()
        }
    }
}

// MARK: - Top Navigation Bar

struct TopNavigationBar: View {
    @EnvironmentObject var state: AppState
    @State private var showingRename = false
    @State private var newName = ""
    
    var body: some View {
        HStack {
            Text("Ponder Pal")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(state.username)
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button(state.language == "zh" ? "重命名" : "Rename") {
                newName = state.username
                showingRename = true
            }
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
        .alert(state.language == "zh" ? "重命名" : "Rename", isPresented: $showingRename) {
            TextField(state.language == "zh" ? "新名字" : "New name", text: $newName)
            Button(state.language == "zh" ? "取消" : "Cancel", role: .cancel) { }
            Button(state.language == "zh" ? "保存" : "Save") {
                if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    state.username = newName.trimmingCharacters(in: .whitespaces)
                    state.save()
                }
            }
        }
    }
}

// MARK: - Custom Tab View

struct CustomTabView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab buttons
            HStack(spacing: 0) {
                ForEach([AppState.Tab.today, .history, .friends], id: \.self) { tab in
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
                ForEach([AppState.Tab.today, .history, .friends], id: \.self) { tab in
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
        }
    }
}
