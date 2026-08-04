import SwiftUI
import Supabase

struct FriendsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var premium: PremiumStore

    @State private var friends: [FriendService.FriendEntry] = []
    @State private var incomingRequests: [FriendService.FriendRequest] = []
    @State private var sentRequests: [FriendService.FriendRequest] = []
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isLoading = true
    @State private var isSearching = false
    @State private var isBusy = false
    @State private var showingPaywall = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var friendIds: Set<UUID> { Set(friends.map(\.profile.id)) }
    private var sentIds: Set<UUID> { Set(sentRequests.map(\.profile.id)) }
    private var incomingByProfileId: [UUID: FriendService.FriendRequest] {
        Dictionary(uniqueKeysWithValues: incomingRequests.map { ($0.profile.id, $0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Search by name to add a friend", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { newValue in scheduleSearch(newValue) }

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }

                if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    section("Results") {
                        if isSearching {
                            ProgressView()
                        } else if searchResults.isEmpty {
                            Text("No one found.").foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(searchResults) { profile in
                                    searchResultRow(profile)
                                }
                            }
                        }
                    }
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    if !incomingRequests.isEmpty {
                        section("Requests") {
                            VStack(spacing: 8) {
                                ForEach(incomingRequests) { request in
                                    requestRow(request)
                                }
                            }
                        }
                    }

                    section("Friends (\(friends.count))") {
                        if friends.isEmpty {
                            Text("No friends yet — search above to send a request.").foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(friends) { entry in
                                    NavigationLink(value: FriendProfileRoute(id: entry.profile.id)) {
                                        friendRow(entry.profile)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if !sentRequests.isEmpty {
                        section("Pending") {
                            VStack(spacing: 8) {
                                ForEach(sentRequests) { request in
                                    HStack {
                                        Text(request.profile.displayName ?? "A fan")
                                        Spacer()
                                        Text("Requested").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Friends")
        .navigationDestination(for: FriendProfileRoute.self) { route in
            FriendProfileView(userId: route.id)
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView(reason: "Friends require Premium.")
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
    }

    private func friendRow(_ profile: UserProfile) -> some View {
        HStack {
            Text(profile.displayName ?? "A fan").foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func requestRow(_ request: FriendService.FriendRequest) -> some View {
        HStack {
            Text(request.profile.displayName ?? "A fan")
            Spacer()
            Button("Accept") { Task { await respond(to: request, accept: true) } }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
            Button("Decline") { Task { await respond(to: request, accept: false) } }
                .buttonStyle(.bordered)
        }
        .disabled(isBusy)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func searchResultRow(_ profile: UserProfile) -> some View {
        HStack {
            Text(profile.displayName ?? "A fan")
            Spacer()
            if friendIds.contains(profile.id) {
                Text("Friends").font(.caption).foregroundStyle(.secondary)
            } else if sentIds.contains(profile.id) {
                Text("Requested").font(.caption).foregroundStyle(.secondary)
            } else if let incoming = incomingByProfileId[profile.id] {
                Button("Accept") { Task { await respond(to: incoming, accept: true) } }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandGreen)
                    .disabled(isBusy)
            } else {
                Button("Add") { Task { await sendRequest(to: profile.id) } }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(query)
        }
    }

    private func search(_ query: String) async {
        guard let userId = auth.userId else { return }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await FriendService.searchUsers(query: query, excluding: userId)
        } catch {
            print("Friend search failed: \(error)")
        }
    }

    private func sendRequest(to addresseeId: UUID) async {
        guard let userId = auth.userId else { return }
        guard premium.isPremium else {
            showingPaywall = true
            return
        }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            try await FriendService.sendRequest(from: userId, to: addresseeId)
            await load()
        } catch {
            errorMessage = "Couldn't send that request — \(error.localizedDescription)"
        }
    }

    private func respond(to request: FriendService.FriendRequest, accept: Bool) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await FriendService.respondToRequest(friendshipId: request.friendshipId, accept: accept)
            await load()
        } catch {
            errorMessage = "Couldn't respond to that request — \(error.localizedDescription)"
        }
    }

    private func load() async {
        guard let userId = auth.userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let friendsTask = FriendService.fetchFriends(userId: userId)
            async let incomingTask = FriendService.fetchPendingRequests(userId: userId)
            async let sentTask = FriendService.fetchSentRequests(userId: userId)
            (friends, incomingRequests, sentRequests) = try await (friendsTask, incomingTask, sentTask)
        } catch {
            print("Friends load failed: \(error)")
        }
    }
}

/// Minimal read-only view of a friend's stats, pushed via the
/// `FriendProfileRoute` navigation value (previously unused/dead code).
struct FriendProfileView: View {
    let userId: UUID

    @State private var profile: UserProfile?
    @State private var groundsCount = 0
    @State private var matchesCount = 0
    @State private var achievementsCount = 0
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(profile?.displayName ?? "A fan").font(.title2.bold())

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 12) {
                        StatTile(value: groundsCount, label: "Grounds visited")
                        StatTile(value: matchesCount, label: "Matches attended")
                        StatTile(value: achievementsCount, label: "Achievements")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Friend")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let profileTask: UserProfile = Supa.client
                .from("user_profiles").select().eq("id", value: userId).single().execute().value
            async let grounds = countRows("user_visits", userId: userId)
            async let matches = countRows("user_match_attendance", userId: userId)
            async let achievements = countRows("user_achievements", userId: userId)
            (profile, groundsCount, matchesCount, achievementsCount) = try await (profileTask, grounds, matches, achievements)
        } catch {
            print("FriendProfileView load failed: \(error)")
        }
    }

    private func countRows(_ table: String, userId: UUID) async -> Int {
        (try? await Supa.client.from(table).select(head: true, count: .exact).eq("user_id", value: userId).execute().count) ?? 0
    }
}
