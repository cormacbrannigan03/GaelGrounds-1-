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

    enum RelationshipStatus: Equatable {
        // Deliberately not named `none` -- that spelling collides with
        // Optional<RelationshipStatus>.none in switch pattern matching.
        case unrelated
        case sent
        case received
        case friends
    }

    struct Relationship {
        let status: RelationshipStatus
        let friendshipId: UUID?
    }

    /// Resolves the relationship between two specific users, whichever
    /// direction the request went (or none at all) -- used by
    /// FriendProfileView to decide which friend-action control to show.
    static func fetchRelationship(between userId: UUID, and otherId: UUID) async throws -> Relationship {
        let rows: [Friendship] = try await Supa.client
            .from("friendships")
            .select()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(otherId.uuidString)),and(requester_id.eq.\(otherId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
            .value

        if let accepted = rows.first(where: { $0.status == "accepted" }) {
            return Relationship(status: .friends, friendshipId: accepted.id)
        }
        if let received = rows.first(where: { $0.status == "pending" && $0.addresseeId == userId }) {
            return Relationship(status: .received, friendshipId: received.id)
        }
        if let sent = rows.first(where: { $0.status == "pending" && $0.requesterId == userId }) {
            return Relationship(status: .sent, friendshipId: sent.id)
        }
        return Relationship(status: .unrelated, friendshipId: nil)
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

    // friendships.status has a CHECK constraint allowing only "pending" and
    // "accepted" -- there's no "declined" value, so declining deletes the
    // row instead of writing a status the database would reject outright.
    static func respondToRequest(friendshipId: UUID, accept: Bool) async throws {
        if accept {
            try await Supa.client
                .from("friendships")
                .update(FriendshipStatusUpdate(status: "accepted"))
                .eq("id", value: friendshipId)
                .execute()
        } else {
            try await removeFriendship(id: friendshipId)
        }
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
