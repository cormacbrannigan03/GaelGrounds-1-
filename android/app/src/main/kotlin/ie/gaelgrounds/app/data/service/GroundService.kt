package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.Ground
import ie.gaelgrounds.app.data.model.GroundSummary
import ie.gaelgrounds.app.data.model.UserVisit
import ie.gaelgrounds.app.data.model.UserVisitInsert
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order

/**
 * Grounds listing + visit tracking. Mirrors the inline Supabase calls in
 * ios/GaelGrounds/Views/Grounds/GroundsView.swift and GroundDetailView.swift.
 */
object GroundService {
    suspend fun fetchAll(): List<Ground> {
        return Supa.client.from("grounds").select {
            order("name", Order.ASCENDING)
        }.decodeList()
    }

    suspend fun fetchSummaries(userId: String?): List<GroundSummary> {
        val groundRows = fetchAll()
        val counties = Supa.client.from("counties").select().decodeList<County>()
        val countyNameById = counties.associate { it.id to it.name }

        val visitedIds: Set<String> = if (userId != null) {
            Supa.client.from("user_visits").select {
                filter { eq("user_id", userId) }
            }.decodeList<UserVisit>().map { it.groundId }.toSet()
        } else {
            emptySet()
        }

        return groundRows.map { g ->
            GroundSummary(
                id = g.id,
                name = g.name,
                countyName = countyNameById[g.countyId] ?: "",
                capacity = g.capacity,
                visited = visitedIds.contains(g.id),
                latitude = g.latitude,
                longitude = g.longitude,
                isPrimary = g.isPrimary,
            )
        }
    }

    suspend fun fetchGround(id: String): Ground {
        return Supa.client.from("grounds").select {
            filter { eq("id", id) }
            single()
        }.decodeSingle()
    }

    suspend fun fetchVisits(userId: String, groundId: String): List<UserVisit> {
        return Supa.client.from("user_visits").select {
            filter {
                eq("user_id", userId)
                eq("ground_id", groundId)
            }
        }.decodeList()
    }

    suspend fun logVisit(insert: UserVisitInsert) {
        Supa.client.from("user_visits").insert(insert)
    }
}
