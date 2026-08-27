import SwiftUI
import Supabase

private struct FriendRow: Identifiable {
    let id: UUID
    let userId: UUID
    let name: String?
}

struct FriendsView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var friends: [FriendRow] = []
    @State private var pendingReceived: [FriendRow] = []
    @State private var pendingSentIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isLoading = true
    @State private var isSearching = false

    var body: some View {
        List {
            if !pendingReceived.isEmpty {
                Section("Requests") {
                    ForEach(pendingReceived) { req in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(req.name ?? "A fan").font(.subheadline.bold())
                                Text("Sent you a friend request").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Decline") {
                                Task { await declineRequest(req.id) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.secondary)
                            Button("Accept") {
                                Task { await acceptRequest(req.id) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.brandGreen)
                        }
                    }
                }
            }

            Section("Friends (\(friends.count))") {
                if isLoading {
                    ProgressView()
                } else if friends.isEmpty {
                    Text("No friends yet — search to find people.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(friends) { friend in
                        NavigationLink(value: FriendProfileRoute(id: friend.userId)) {
                            Text(friend.name ?? "A fan").font(.subheadline)
                        }
                    }
                }
            }

            if !searchText.isEmpty {
                Section("Search results") {
                    if isSearching {
                        ProgressView()
                    } else if searchResults.isEmpty {
                        Text("No users found.").foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(searchResults) { user in
                            HStack {
                                Text(user.displayName ?? "A fan").font(.subheadline)
                                Spacer()
                                if user.id == auth.userId {
                                    Text("You").font(.caption).foregroundStyle(.secondary)
                                } else if friends.contains(where: { $0.userId == user.id }) {
                                    Text("Friends").font(.caption).foregroundStyle(.secondary)
                                } else if pendingSentIds.contains(user.id) {
                                    Text("Requested").font(.caption).foregroundStyle(.secondary)
                                } else if let req = pendingReceived.first(where: { $0.userId == user.id }) {
                                    Button("Accept") {
                                        Task { await acceptRequest(req.id) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.brandGreen)
                                } else {
                                    Button("Add") {
                                        Task { await sendRequest(to: user.id) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .tint(.brandGreen)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search by name")
        .onChange(of: searchText) { _, new in
            Task { await search(query: new) }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Friends")
        .navigationDestination(for: FriendProfileRoute.self) { route in
            FriendProfileView(userId: route.id)
        }
        .task { await load() }
        .refreshable { await load() }
        .gaelGroundsBackground()
    }

    private func load() async {
        guard let myId = auth.userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let fromMeTask: [Friendship] = Supa.client
                .from("friendships").select().eq("requester_id", value: myId).execute().value
            async let toMeTask: [Friendship] = Supa.client
                .from("friendships").select().eq("addressee_id", value: myId).execute().value

            let fromMe = try await fromMeTask
            let toMe = try await toMeTask
            let rows = fromMe + toMe

            let accepted = rows.filter { $0.status == "accepted" }
            let pending = rows.filter { $0.status == "pending" }

            let receivedRows = pending.filter { $0.addresseeId == myId }
            pendingSentIds = Set(pending.filter { $0.requesterId == myId }.map(\.addresseeId))

            let friendUserIds = accepted.map { $0.requesterId == myId ? $0.addresseeId : $0.requesterId }
            let receivedUserIds = receivedRows.map(\.requesterId)
            let allIds = Array(Set(friendUserIds + receivedUserIds))

            let profiles: [UserProfile] = allIds.isEmpty ? [] : try await Supa.client
                .from("user_profiles").select().in("id", values: allIds).execute().value
            let nameById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName) })

            friends = zip(accepted, friendUserIds)
                .map { friendship, uid in FriendRow(id: friendship.id, userId: uid, name: nameById[uid] ?? nil) }
                .sorted { ($0.name ?? "").localizedCompare($1.name ?? "") == .orderedAscending }

            pendingReceived = receivedRows.map {
                FriendRow(id: $0.id, userId: $0.requesterId, name: nameById[$0.requesterId] ?? nil)
            }
        } catch {
            print("FriendsView load failed: \(error)")
        }
    }

    private func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await Supa.client
                .from("user_profiles")
                .select()
                .ilike("display_name", pattern: "%\(trimmed)%")
                .limit(15)
                .execute()
                .value
        } catch {
            print("FriendsView search failed: \(error)")
        }
    }

    private func sendRequest(to userId: UUID) async {
        guard let myId = auth.userId else { return }
        do {
            try await Supa.client
                .from("friendships")
                .insert(FriendshipInsert(requesterId: myId, addresseeId: userId))
                .execute()
            pendingSentIds.insert(userId)
        } catch {
            print("sendRequest failed: \(error)")
        }
    }

    private func acceptRequest(_ friendshipId: UUID) async {
        do {
            try await Supa.client
                .from("friendships")
                .update(FriendshipStatusUpdate(status: "accepted"))
                .eq("id", value: friendshipId)
                .execute()
            await load()
        } catch {
            print("acceptRequest failed: \(error)")
        }
    }

    // friendships.status has a CHECK constraint allowing only "pending" and
    // "accepted" -- there's no "declined" value, so this deletes the row
    // instead (the RLS delete policy already allows either party to). The
    // unique(requester_id, addressee_id) constraint means the same person
    // can send a fresh request later, which reads better anyway.
    private func declineRequest(_ friendshipId: UUID) async {
        do {
            try await Supa.client
                .from("friendships")
                .delete()
                .eq("id", value: friendshipId)
                .execute()
            await load()
        } catch {
            print("declineRequest failed: \(error)")
        }
    }
}
