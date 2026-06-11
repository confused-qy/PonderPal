import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var state: AppState

    /// Groups: qId → [(year, myAnswer?, [(friendName, answer)])]
    private var groups: [(qId: Int, rows: [(year: Int, mine: AnswerEntry?, friendEntries: [(name: String, entry: AnswerEntry)])])] {
        buildGroups()
    }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(groups, id: \.qId) { group in
                            HistoryGroupRow(group: group)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(state.language == "zh" ? "还没有任何回答" : "No answers yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(state.language == "zh" ? "从今天的问题开始记录吧" : "Start with today's question")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data building

    private func buildGroups() -> [(qId: Int, rows: [(year: Int, mine: AnswerEntry?, friendEntries: [(name: String, entry: AnswerEntry)])])] {
        let (todayQId, todayYear) = state.todayInfo()
        let myAnsweredToday = state.hasAnsweredToday()

        // Collect all qIds that have any answer
        var qIdSet = Set<Int>()
        for key in state.answers.keys {
            if let qId = Int(key.split(separator: "_").first ?? "") { qIdSet.insert(qId) }
        }
        for friend in state.friends {
            for key in (friend.snapshot?.answers ?? [:]).keys {
                if let qId = Int(key.split(separator: "_").first ?? "") { qIdSet.insert(qId) }
            }
        }

        // Collect all years per qId
        return qIdSet.sorted(by: >).map { qId in
            var yearSet = Set<Int>()
            for key in state.answers.keys {
                let parts = key.split(separator: "_")
                if let kQId = Int(parts.first ?? ""), let kYear = Int(parts.last ?? ""),
                   kQId == qId { yearSet.insert(kYear) }
            }
            for friend in state.friends {
                for key in (friend.snapshot?.answers ?? [:]).keys {
                    let parts = key.split(separator: "_")
                    if let kQId = Int(parts.first ?? ""), let kYear = Int(parts.last ?? ""),
                       kQId == qId { yearSet.insert(kYear) }
                }
            }

            let rows: [(year: Int, mine: AnswerEntry?, friendEntries: [(name: String, entry: AnswerEntry)])] =
            yearSet.sorted(by: >).map { year in
                let mine = state.answers[state.answerKey(qId, year)]
                let friendEntries: [(name: String, entry: AnswerEntry)] = state.friends.compactMap { friend in
                    guard let entry = friend.snapshot?.answers[state.answerKey(qId, year)] else { return nil }
                    // Lock today's friend answer until user has answered today
                    if qId == todayQId && year == todayYear && !myAnsweredToday { return nil }
                    return (friend.name, entry)
                }
                return (year, mine, friendEntries)
            }.filter { $0.mine != nil || !$0.friendEntries.isEmpty }

            return (qId, rows)
        }.filter { !$0.rows.isEmpty }
    }
}

// MARK: - Group Row

struct HistoryGroupRow: View {
    @EnvironmentObject var state: AppState
    let group: (qId: Int, rows: [(year: Int, mine: AnswerEntry?, friendEntries: [(name: String, entry: AnswerEntry)])])
    @State private var expanded = true

    private var question: String { Questions.question(qId: group.qId, lang: state.language) }
    private var dateStr:  String { Questions.dateString(qId: group.qId, lang: state.language) }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(group.rows, id: \.year) { row in
                YearBlock(qId: group.qId, row: row)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateStr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(question)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Year block

struct YearBlock: View {
    @EnvironmentObject var state: AppState
    let qId: Int
    let row: (year: Int, mine: AnswerEntry?, friendEntries: [(name: String, entry: AnswerEntry)])

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(row.year))
                .font(.caption.bold())
                .foregroundStyle(.indigo)

            // My answer
            if let mine = row.mine {
                HStack(alignment: .top, spacing: 10) {
                    Text(state.language == "zh" ? "我" : "Me")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.indigo, in: Capsule())

                    Text(mine.content)
                        .font(.subheadline)

                    Spacer()

                    // Visibility toggle
                    Button {
                        state.answers[state.answerKey(qId, row.year)]?.visible.toggle()
                        state.save()
                        state.syncToServer()
                    } label: {
                        Image(systemName: mine.visible ? "eye" : "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Friend answers
            ForEach(row.friendEntries, id: \.name) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text(String(item.name.prefix(5)))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange, in: Capsule())

                    Text(item.entry.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
    }
}
