import SwiftUI
import PhotosUI
import Supabase

struct DashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var supportedCounty: SupportedCountyStore

    @State private var upcoming: [MatchSummary] = []
    @State private var groundsVisited = 0
    @State private var matchesAttended = 0
    @State private var achievementsUnlocked = 0
    @State private var isLoading = true
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeTask: Task<Void, Never>?

    @State private var avatarURL: String?
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Every ground. Every code. Every county.")
                        .font(.title.bold())
                    Text(
                        "Check in at Gaelic football, hurling, camogie and ladies' football matches in real time, " +
                        "and build your own record of the grounds you've stood in across all 32 counties."
                    )
                    .foregroundStyle(.secondary)
                }

                if auth.isSignedIn {
                    HStack(spacing: 12) {
                        StatTile(value: groundsVisited, label: "Grounds visited")
                        StatTile(value: matchesAttended, label: "Matches attended")
                        StatTile(value: achievementsUnlocked, label: "Achievements")
                    }

                    AvatarPickerSection(
                        avatarURL: avatarURL,
                        selectedItem: $selectedAvatarItem,
                        isUploading: isUploadingAvatar
                    )
                    if let avatarError {
                        Text(avatarError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Upcoming fixtures").font(.title3.bold())
                        Spacer()
                        NavigationLink("See all fixtures →", value: MatchesRouteTag())
                    }

                    if isLoading {
                        ProgressView()
                    } else if upcoming.isEmpty {
                        Text("No upcoming fixtures right now — check back soon.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(upcoming) { match in
                                MatchCardView(match: match)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("GaelGrounds")
        .navigationDestination(for: MatchRoute.self) { route in
            MatchDetailView(matchId: route.id)
        }
        .navigationDestination(for: MatchesRouteTag.self) { _ in
            MatchesView()
        }
        .task {
            await load(showSpinner: true)
            let (channel, task) = RealtimeWatcher.watch(table: "matches") { Task { await load(showSpinner: false) } }
            realtimeChannel = channel
            realtimeTask = task
        }
        .onDisappear { RealtimeWatcher.stop(channel: realtimeChannel, task: realtimeTask) }
        .refreshable { await load(showSpinner: false) }
        .onChange(of: selectedAvatarItem) { newItem in
            guard let newItem else { return }
            Task { await addAvatar(from: newItem) }
        }
        .countyBackground(supportedCounty.countyName)
    }

    private func addAvatar(from item: PhotosPickerItem) async {
        guard let userId = auth.userId else { return }
        isUploadingAvatar = true
        avatarError = nil
        defer {
            isUploadingAvatar = false
            selectedAvatarItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                avatarError = "Couldn't load that photo — try another."
                return
            }
            let url = try await AvatarService.upload(rawImageData: data, userId: userId)
            try await Supa.client
                .from("user_profiles")
                .update(UserProfileAvatarUpdate(avatarUrl: url))
                .eq("id", value: userId)
                .execute()
            avatarURL = url
        } catch {
            avatarError = "Couldn't upload that photo — try again."
        }
    }

    private func load(showSpinner: Bool) async {
        if showSpinner { isLoading = true }
        defer { if showSpinner { isLoading = false } }

        do {
            let matches = try await MatchService.fetchUpcomingAndLive()
            upcoming = try await MatchService.resolveSummaries(matches)
        } catch {
            print("Dashboard load failed: \(error)")
        }

        guard let userId = auth.userId else { return }
        async let groundsCount = distinctGroundsVisited(userId: userId)
        async let matchesCount = countRows("user_match_attendance", userId: userId)
        async let achievementsCount = countRows("user_achievements", userId: userId)
        groundsVisited = await groundsCount
        matchesAttended = await matchesCount
        achievementsUnlocked = await achievementsCount

        let profile: UserProfile? = try? await Supa.client
            .from("user_profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        avatarURL = profile?.avatarUrl
    }

    private func countRows(_ table: String, userId: UUID) async -> Int {
        (try? await Supa.client.from(table).select(head: true, count: .exact).eq("user_id", value: userId).execute().count) ?? 0
    }

    // A raw row count on user_visits counts every check-in, not every
    // ground -- checking into the same ground for 3 different matches is 3
    // rows but 1 ground. Matches how ProfileView already counts its own
    // "Grounds visited" stat.
    private func distinctGroundsVisited(userId: UUID) async -> Int {
        struct GroundIdOnly: Decodable { let groundId: UUID }
        let rows: [GroundIdOnly] = (try? await Supa.client
            .from("user_visits")
            .select("ground_id")
            .eq("user_id", value: userId)
            .execute()
            .value) ?? []
        return Set(rows.map(\.groundId)).count
    }
}

/// Lightweight tag type so the "See all fixtures" link can push MatchesView
/// via the same NavigationStack-based `navigationDestination` pattern used
/// for detail routes.
private struct MatchesRouteTag: Hashable {}

private struct AvatarPickerSection: View {
    let avatarURL: String?
    @Binding var selectedItem: PhotosPickerItem?
    let isUploading: Bool

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack(spacing: 12) {
                ZStack {
                    if let avatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 56, height: 56)
                            .foregroundStyle(.secondary)
                    }

                    if isUploading {
                        Circle().fill(.black.opacity(0.35)).frame(width: 56, height: 56)
                        ProgressView().tint(.white)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Color.brandGreenLight)
                        .background(Circle().fill(.white))
                }

                Text(avatarURL == nil ? "Add profile photo" : "Change profile photo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(10)
            .gaelCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
    }
}
