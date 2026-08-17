package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.Friendship
import ie.gaelgrounds.app.data.model.FriendshipInsert
import ie.gaelgrounds.app.data.model.FriendshipStatusUpdate
import ie.gaelgrounds.app.data.model.UserProfile
import io.github.jan.supabase.postgrest.from

/**
 * Friend requests/friends list, backed by the `friendships` table. Sending
 * a request requires premium -- enforced server-side by RLS, not just the
 * client-side check in the Friends screen. Mirrors
 * ios/GaelGrounds/Services/FriendService.swift.
 */
object FriendService {
    data class FriendEntry(val friendshipId: String, val profile: UserProfile) {
        val id: String get() = profile.id
    }

    data class FriendRequest(val friendshipId: String, val profile: UserProfile) {
        val id: String get() = friendshipId
    }

    suspend fun fetchFriends(userId: String): List<FriendEntry> {
        val rows = Supa.client.from("friendships").select {
            filter {
                or {
                    eq("requester_id", userId)
                    eq("addressee_id", userId)
                }
                eq("status", "accepted")
            }
        }.decodeList<Friendship>()

        val otherIds = rows.map { if (it.requesterId == userId) it.addresseeId else it.requesterId }
        val profileById = profilesById(otherIds)

        return rows.mapNotNull { row ->
            val otherId = if (row.requesterId == userId) row.addresseeId else row.requesterId
            val profile = profileById[otherId] ?: return@mapNotNull null
            FriendEntry(row.id, profile)
        }
    }

    /** Requests sent to this user, awaiting a response. */
    suspend fun fetchPendingRequests(userId: String): List<FriendRequest> {
        val rows = Supa.client.from("friendships").select {
            filter {
                eq("addressee_id", userId)
                eq("status", "pending")
            }
        }.decodeList<Friendship>()

        val profileById = profilesById(rows.map { it.requesterId })
        return rows.mapNotNull { row ->
            val profile = profileById[row.requesterId] ?: return@mapNotNull null
            FriendRequest(row.id, profile)
        }
    }

    /** Requests this user sent, still awaiting a response from the other side. */
    suspend fun fetchSentRequests(userId: String): List<FriendRequest> {
        val rows = Supa.client.from("friendships").select {
            filter {
                eq("requester_id", userId)
                eq("status", "pending")
            }
        }.decodeList<Friendship>()

        val profileById = profilesById(rows.map { it.addresseeId })
        return rows.mapNotNull { row ->
            val profile = profileById[row.addresseeId] ?: return@mapNotNull null
            FriendRequest(row.id, profile)
        }
    }

    suspend fun searchUsers(query: String, excludingUserId: String): List<UserProfile> {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return emptyList()
        return Supa.client.from("user_profiles").select {
            filter {
                ilike("display_name", "%$trimmed%")
                neq("id", excludingUserId)
            }
            limit(20)
        }.decodeList()
    }

    suspend fun sendRequest(requesterId: String, addresseeId: String) {
        Supa.client.from("friendships").insert(FriendshipInsert(requesterId, addresseeId))
    }

    suspend fun respondToRequest(friendshipId: String, accept: Boolean) {
        Supa.client.from("friendships").update(
            FriendshipStatusUpdate(status = if (accept) "accepted" else "declined")
        ) {
            filter { eq("id", friendshipId) }
        }
    }

    suspend fun removeFriendship(id: String) {
        Supa.client.from("friendships").delete {
            filter { eq("id", id) }
        }
    }

    private suspend fun profilesById(ids: List<String>): Map<String, UserProfile> {
        val distinctIds = ids.distinct()
        if (distinctIds.isEmpty()) return emptyMap()
        val profiles = Supa.client.from("user_profiles").select {
            filter { isIn("id", distinctIds) }
        }.decodeList<UserProfile>()
        return profiles.associateBy { it.id }
    }
}
