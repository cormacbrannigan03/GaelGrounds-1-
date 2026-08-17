package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.CountyTeam
import ie.gaelgrounds.app.data.model.Ground
import ie.gaelgrounds.app.data.model.Honour
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order

/**
 * Counties/teams/honours browsing. Mirrors the inline Supabase calls in
 * ios/GaelGrounds/Views/Counties/CountiesView.swift,
 * CountyDetailView.swift and TeamDetailView.swift.
 */
object CountyService {
    suspend fun fetchAll(): List<County> {
        return Supa.client.from("counties").select {
            order("name", Order.ASCENDING)
        }.decodeList()
    }

    data class CountyDetail(
        val county: County,
        val teams: List<CountyTeam>,
        val grounds: List<Ground>,
        val honours: List<Honour>,
    )

    suspend fun fetchDetail(countyId: String): CountyDetail {
        val county = Supa.client.from("counties").select {
            filter { eq("id", countyId) }
            single()
        }.decodeSingle<County>()

        val teams = Supa.client.from("county_teams").select {
            filter {
                eq("county_id", countyId)
                isIn("sport_code", listOf("gaelic_football", "hurling"))
            }
        }.decodeList<CountyTeam>()

        val grounds = Supa.client.from("grounds").select {
            filter { eq("county_id", countyId) }
        }.decodeList<Ground>()

        val teamIds = teams.map { it.id }
        val honours = if (teamIds.isEmpty()) {
            emptyList()
        } else {
            Supa.client.from("honours").select {
                filter { isIn("county_team_id", teamIds) }
                order("year", Order.DESCENDING)
            }.decodeList<Honour>()
        }

        return CountyDetail(county, teams, grounds, honours)
    }

    suspend fun fetchTeam(teamId: String): CountyTeam {
        return Supa.client.from("county_teams").select {
            filter { eq("id", teamId) }
            single()
        }.decodeSingle()
    }

    suspend fun fetchHonours(countyTeamId: String): List<Honour> {
        return Supa.client.from("honours").select {
            filter { eq("county_team_id", countyTeamId) }
            order("year", Order.DESCENDING)
        }.decodeList()
    }
}
