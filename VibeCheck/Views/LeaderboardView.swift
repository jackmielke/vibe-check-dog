import SwiftUI

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var loading = true
    @State private var error: String?
    @State private var sort: VibeAPI.Sort = .top
    @AppStorage("hiddenEntryIDs") private var hiddenRaw: String = ""

    private var hidden: Set<String> { Set(hiddenRaw.split(separator: ",").map(String.init)) }
    private var visible: [LeaderboardEntry] { entries.filter { !hidden.contains($0.id) } }

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            VStack(spacing: 0) {
                sortPicker
                content
            }
        }
        .navigationTitle("Vibe Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sort) { await load() }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $sort) {
            Text("Top vibes").tag(VibeAPI.Sort.top)
            Text("Most recent").tag(VibeAPI.Sort.recent)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .onChange(of: sort) { _, _ in SFX.tap() }
        .accessibilityIdentifier("leaderboardSort")
    }

    @ViewBuilder
    private var content: some View {
        if loading && entries.isEmpty {
            Spacer()
            ProgressView().controlSize(.large).tint(Theme.accent)
            Spacer()
        } else if let error, entries.isEmpty {
            Spacer()
            errorState(error)
            Spacer()
        } else {
            List {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink {
                        LeaderboardDetailView(entry: entry, rank: sort == .top ? index + 1 : nil)
                    } label: {
                        row(entry, rank: sort == .top ? index + 1 : nil)
                    }
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

    private func row(_ entry: LeaderboardEntry, rank: Int?) -> some View {
        HStack(spacing: 13) {
            if let rank {
                Text("\(rank)")
                    .font(Theme.display(15, .bold))
                    .foregroundStyle(rank <= 3 ? Theme.accent : Theme.muted)
                    .frame(width: 24, alignment: .trailing)
                    .monospacedDigit()
            }

            CachedImage(url: entry.imageURL.flatMap(URL.init), maxPixel: 180)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                if let a = entry.vibeAnalysis {
                    Text(a).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
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
            Button { hide(entry) } label: { Label("Hide this post", systemImage: "eye.slash") }
            Button(role: .destructive) { report(entry) } label: { Label("Report", systemImage: "flag") }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            MascotView(mood: .thinking, size: 120).accessibilityHidden(true)
            Text(message)
                .font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Try again") { Task { await load() } }
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            entries = try await VibeAPI.leaderboard(sort: sort)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func hide(_ entry: LeaderboardEntry) {
        var ids = hidden
        ids.insert(entry.id)
        hiddenRaw = ids.joined(separator: ",")
    }

    private func report(_ entry: LeaderboardEntry) {
        hide(entry)
        var c = URLComponents(string: "mailto:jackcmielke@gmail.com")
        c?.queryItems = [
            URLQueryItem(name: "subject", value: "Vibe Check report: \(entry.id)"),
            URLQueryItem(name: "body", value: "Reporting this post.\n\nPost ID: \(entry.id)\nName: \(entry.name)\nScore: \(entry.score)\n\nReason:")
        ]
        if let url = c?.url { UIApplication.shared.open(url) }
    }
}

/// Full-size look at one entry.
struct LeaderboardDetailView: View {
    let entry: LeaderboardEntry
    var rank: Int?

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    CachedImage(url: entry.imageURL.flatMap(URL.init), maxPixel: 1400)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Text(DogLines.emoji(for: entry.score)).font(.system(size: 44))

                    Text("\(entry.score)")
                        .font(Theme.display(74, .black))
                        .foregroundStyle(Theme.scoreColor(entry.score))
                        .monospacedDigit()

                    if let a = entry.vibeAnalysis {
                        Text(a)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.cream)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .vibeCard()
                    }

                    HStack(spacing: 10) {
                        if let rank {
                            Label("#\(rank)", systemImage: "trophy.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        if let d = entry.createdAt {
                            Text(d, format: .dateTime.month(.abbreviated).day().year())
                                .font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
