import Foundation
import Supabase

/// Friend requests/friends list, backed by the `friendships` table.
/// Sending a request requires premium — enforced server-side by the
/// "premium users can send friend requests" RLS policy
/// (supabase/migrations/20260801023442_create_friendships_table.sql), not
/// just by the client-side check in FriendsView.
enum FriendService {
    struct FriendEntry: Identifiable {
        let friendshipId: UUID
        let profile: UserProfile
        var id: UUID { profile.id }
    }

    struct FriendRequest: Identifiable {
        let friendshipId: UUID
        let profile: UserProfile
        var id: UUID { friendshipId }
    }

    static func fetchFriends(userId: UUID) async throws -> [FriendEntry] {
        let rows: [Friendship] = try await Supa.client
            .from("friendships")
            .select()
            .or("requester_id.eq.\(userId.uuidString),addressee_id.eq.\(userId.uuidString)")
            .eq("status", value: "accepted")
            .execute()
            .value

        let otherIds = rows.map { $0.requesterId == userId ? $0.addresseeId : $0.requesterId }
        let profileById = try await profilesById(otherIds)

        return rows.compactMap { row in
            let otherId = row.requesterId == userId ? row.addresseeId : row.requesterId
            guard let profile = profileById[otherId] else { return nil }
            return FriendEntry(friendshipId: row.id, profile: profile)
        }
    }

    /// Requests sent to this user, awaiting a response.
    static func fetchPendingRequests(userId: UUID) async throws -> [FriendRequest] {
        let rows: [Friendship] = try await Supa.client
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value

        let profileById = try await profilesById(rows.map(\.requesterId))
        return rows.compactMap { row in
            guard let profile = profileById[row.requesterId] else { return nil }
            return FriendRequest(friendshipId: row.id, profile: profile)
        }
    }

    /// Requests this user sent, still awaiting a response from the other side.
    static func fetchSentRequests(userId: UUID) async throws -> [FriendRequest] {
        let rows: [Friendship] = try await Supa.client
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value

        let profileById = try await profilesById(rows.map(\.addresseeId))
        return rows.compactMap { row in
            guard let profile = profileById[row.addresseeId] else { return nil }
            return FriendRequest(friendshipId: row.id, profile: profile)
        }
    }

    static func searchUsers(query: String, excluding userId: UUID) async throws -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await Supa.client
            .from("user_profiles")
            .select()
            .ilike("display_name", value: "%\(trimmed)%")
            .neq("id", value: userId)
            .limit(20)
            .execute()
            .value
    }

    static func sendRequest(from requesterId: UUID, to addresseeId: UUID) async throws {
        try await Supa.client
            .from("friendships")
            .insert(FriendshipInsert(requesterId: requesterId, addresseeId: addresseeId))
            .execute()
    }

    static func respondToRequest(friendshipId: UUID, accept: Bool) async throws {
        try await Supa.client
            .from("friendships")
            .update(FriendshipStatusUpdate(status: accept ? "accepted" : "declined"))
            .eq("id", value: friendshipId)
            .execute()
    }

    static func removeFriendship(id: UUID) async throws {
        try await Supa.client
            .from("friendships")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    private static func profilesById(_ ids: [UUID]) async throws -> [UUID: UserProfile] {
        guard !ids.isEmpty else { return [:] }
        let profiles: [UserProfile] = try await Supa.client
            .from("user_profiles")
            .select()
            .in("id", values: Array(Set(ids)))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }
}
