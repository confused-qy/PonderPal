import SwiftUI

struct TodayView: View {
    @EnvironmentObject var state: AppState
    @State private var draftText  = ""
    @State private var isVisible  = true
    @State private var savedBanner = false
    @FocusState private var textFocused: Bool
    
    private var info: (qId: Int, year: Int) { state.todayInfo() }
    private var key:  String { state.answerKey(info.qId, info.year) }
    private var existing: AnswerEntry? { state.answers[key] }
    private var question: String { Questions.question(qId: info.qId, lang: state.language) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Date
                Text(todayDateString())
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Question card - 按照截图样式：白色背景，圆角，阴影
                VStack(alignment: .leading, spacing: 0) {
                    Text(question)
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                        .padding(24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                // Answer section
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Text input - 按照截图样式：白色背景，蓝色边框
                    TextField(state.language == "zh" ? "写下你今天的回答..." : "Write your answer for today...", text: $draftText, axis: .vertical)
                        .font(.body)
                        .lineLimit(8...15)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.4, green: 0.6, blue: 0.8), lineWidth: 2)
                        )
                        .focused($textFocused)
                   
                   HStack {
                       HStack(spacing: 6) {
                           Image(systemName: isVisible ? "checkmark.square.fill" : "square")
                               .foregroundStyle(isVisible ? Color(red: 0.4, green: 0.6, blue: 0.8) : .secondary)
                           Text(state.language == "zh" ? "好友可见" : "Visible to friends")
                               .font(.body)
                               .foregroundStyle(.secondary)
                       }
                       .frame(maxWidth: .infinity, alignment: .center)
                       .onTapGesture {
                           isVisible.toggle()
                       }
                   }
                    
                    // Save button - 按照截图样式：蓝灰色背景
                    Button(action: saveAnswer) {
                        Text(state.language == "zh" ? "保存回答" : "Save Answer")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.45, green: 0.55, blue: 0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(draftText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20)
                
                // Past answers (if any)
                if !pastAnswersForThisQuestion().isEmpty {
                    pastAnswersSection
                        .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 100) // Extra space at bottom
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97)) // 浅灰色背景，与截图一致
        .onAppear { loadDraft() }
        .onTapGesture { textFocused = false }
        .overlay(
            Group {
                if savedBanner {
                    VStack {
                        Spacer()
                        Text(state.language == "zh" ? "回答已保存！" : "Answer saved!")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 50)
                    }
                    .animation(.easeInOut(duration: 0.5), value: savedBanner)
                }
            }
        )
    }
    
    // MARK: - Past answers
    
    @ViewBuilder
    private var pastAnswersSection: some View {
        let pastYears: [(year: Int, entry: AnswerEntry)] = (1...10).compactMap { offset in
            let y = info.year - offset
            guard let entry = state.answers[state.answerKey(info.qId, y)] else { return nil }
            return (y, entry)
        }
        
        if !pastYears.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(state.language == "zh" ? "往年的你" : "Past years")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                
                ForEach(pastYears, id: \.year) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(item.year))
                            .font(.caption.bold())
                            .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 0.8))
                            .frame(width: 36, alignment: .leading)
                        
                        Text(item.entry.content)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // Visibility toggle
                        Button {
                            state.answers[state.answerKey(info.qId, item.year)]?.visible.toggle()
                            state.save()
                            state.syncToServer()
                        } label: {
                            Image(systemName: item.entry.visible ? "eye" : "eye.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 1)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadDraft() {
        if let e = existing {
            draftText = e.content
            isVisible = e.visible
        }
    }
    
    private func saveAnswer() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.answers[key] = AnswerEntry(content: trimmed, visible: isVisible)
        state.save()
        state.syncToServer()
        textFocused = false
        
        withAnimation {
            savedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { savedBanner = false }
        }
    }
    
    private func pastAnswersForThisQuestion() -> [(year: Int, entry: AnswerEntry)] {
        return (1...10).compactMap { offset in
            let y = info.year - offset
            guard let entry = state.answers[state.answerKey(info.qId, y)] else { return nil }
            return (y, entry)
        }
    }
    
    private func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: state.language == "zh" ? "zh_CN" : "en_US")
        fmt.dateStyle = .full
        return fmt.string(from: Date())
    }
}
