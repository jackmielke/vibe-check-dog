import SwiftUI

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var loading = true
    @State private var error: String?
    @AppStorage("hiddenEntryIDs") private var hiddenRaw: String = ""

    private var hidden: Set<String> {
        Set(hiddenRaw.split(separator: ",").map(String.init))
    }

    private var visible: [LeaderboardEntry] {
        entries.filter { !hidden.contains($0.id) }
    }

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            if loading && entries.isEmpty {
                ProgressView().controlSize(.large).tint(Theme.accent)
            } else if let error, entries.isEmpty {
                errorState(error)
            } else {
                List {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                        row(entry, rank: index + 1)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Leaderboard")
        .task { if entries.isEmpty { await load() } }
    }

    private func row(_ entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: 13) {
            Text("\(rank)")
                .font(Theme.display(15, .bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 24, alignment: .trailing)
                .monospacedDigit()

            AsyncImage(url: entry.imageURL.flatMap(URL.init)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Theme.bgLift)
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                if let a = entry.vibeAnalysis {
                    Text(a)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            Text("\(entry.score)")
                .font(Theme.display(24, .black))
                .foregroundStyle(Theme.scoreColor(entry.score))
                .monospacedDigit()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .contextMenu {
            Button {
                hide(entry)
            } label: {
                Label("Hide this post", systemImage: "eye.slash")
            }
            Button(role: .destructive) {
                report(entry)
            } label: {
                Label("Report", systemImage: "flag")
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            DogView(mood: .thinking, size: 130).accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try again") { Task { await load() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            entries = try await VibeAPI.leaderboard()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Hidden locally and immediately - the user never has to see it again.
    private func hide(_ entry: LeaderboardEntry) {
        var ids = hidden
        ids.insert(entry.id)
        hiddenRaw = ids.joined(separator: ",")
    }

    private func report(_ entry: LeaderboardEntry) {
        hide(entry)
        let subject = "Vibe Check report: \(entry.id)"
        let body = """
        Reporting this leaderboard post.

        Post ID: \(entry.id)
        Name: \(entry.name)
        Score: \(entry.score)

        Reason:
        """
        var c = URLComponents(string: "mailto:jackcmielke@gmail.com")
        c?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = c?.url { UIApplication.shared.open(url) }
    }
}
