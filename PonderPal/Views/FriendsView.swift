import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var state: AppState
    @State private var importCode = ""
    @State private var importMessage: (text: String, isError: Bool)? = nil
    @State private var showCopied = false
    @State private var isImporting = false

    private var shareCode: String { state.generateShareCode() }
    private var todayQId: Int { state.todayInfo().0 }
    private var todayYear: Int { state.todayInfo().1 }
    private var myAnsweredToday: Bool { state.hasAnsweredToday() }
    private var todayQuestion: String { Questions.question(qId: todayQId, lang: state.language) }

    var body: some View {
        NavigationStack {
            List {
                // Share code section
                shareSection

                // Import section
                importSection

                // Friends list
                if !state.friends.isEmpty {
                    friendsSection
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Share code

    private var shareSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(state.language == "zh" ? "我的分享码" : "My Share Code")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Text(state.language == "zh"
                     ? "把分享码发给朋友，他们导入后可以互相看到今日的回答"
                     : "Send this code to a friend — once imported you can each see today's answers")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(shareCode)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .foregroundStyle(.indigo)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        UIPasteboard.general.string = shareCode
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(showCopied ? .green : .indigo)
                    }
                }
                .padding(12)
                .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Import section

    private var importSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(state.language == "zh" ? "导入好友分享码" : "Import a Friend's Code")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                HStack {
                    TextField(
                        state.language == "zh" ? "粘贴分享码…" : "Paste share code…",
                        text: $importCode
                    )
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    Button(action: doImport) {
                        if isImporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(state.language == "zh" ? "导入" : "Import")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .disabled(importCode.trimmingCharacters(in: .whitespaces).isEmpty || isImporting)
                }

                if let msg = importMessage {
                    Label(msg.text, systemImage: msg.isError ? "xmark.circle" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(msg.isError ? .red : .green)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Friends list

    private var friendsSection: some View {
        Section(state.language == "zh" ? "好友 (\(state.friends.count))" : "Friends (\(state.friends.count))") {
            ForEach(state.friends) { friend in
                FriendRow(
                    friend: friend,
                    todayQId: todayQId,
                    todayYear: todayYear,
                    myAnsweredToday: myAnsweredToday,
                    todayQuestion: todayQuestion
                )
            }
            .onDelete { indices in
                state.friends.remove(atOffsets: indices)
                state.save()
            }
        }
    }

    // MARK: - Actions

    private func doImport() {
        let raw = importCode.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        isImporting = true
        importMessage = nil

        Task {
            let result = await state.importFriend(code: raw)
            await MainActor.run {
                isImporting = false
                switch result {
                case .success(let info):
                    let name = info.split(separator: ":").last.map(String.init) ?? ""
                    let added = info.hasPrefix("added")
                    importMessage = (
                        added
                          ? (state.language == "zh" ? "✓ 已添加好友 \(name)" : "✓ Added \(name)")
                          : (state.language == "zh" ? "✓ 已更新 \(name) 的回答" : "✓ Updated answers from \(name)"),
                        false
                    )
                    importCode = ""
                case .failure(let err):
                    importMessage = (err.localizedDescription(language: state.language), true)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    importMessage = nil
                }
            }
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    @EnvironmentObject var state: AppState
    let friend: FriendEntry
    let todayQId:        Int
    let todayYear:       Int
    let myAnsweredToday: Bool
    let todayQuestion:   String

    private var todayAnswer: AnswerEntry? {
        friend.snapshot?.answers["\(todayQId)_\(todayYear)"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(.indigo.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(friend.name.prefix(1)).uppercased())
                            .font(.system(.subheadline, design: .serif).bold())
                            .foregroundStyle(.indigo)
                    }
                Text(friend.name)
                    .font(.subheadline.weight(.medium))
            }

            // Today's question
            Text(todayQuestion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Answer or lock/no-answer state
            answerContent
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var answerContent: some View {
        if !myAnsweredToday {
            if todayAnswer != nil {
                // Friend answered but I haven't yet
                Label(
                    state.language == "zh"
                        ? "好友已经回答了～先写下你的答案，解锁之后就能看到了 ✍️"
                        : "Your friend answered — write yours first to unlock 🔒",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Text(state.language == "zh"
                     ? "回答今天的问题后，就能看到好友的答案了 ✍️"
                     : "Answer today's question to see what your friends think ✍️")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        } else if let ans = todayAnswer {
            Text(ans.content)
                .font(.subheadline)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        } else {
            Text(state.language == "zh" ? "对方今天还没有回答" : "No answer yet today")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
    }
}
