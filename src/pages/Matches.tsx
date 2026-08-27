import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../context/AuthContext'
import MatchCard, { type MatchCardData } from '../components/MatchCard'
import PersonalMatchCard, { type PersonalMatch } from '../components/PersonalMatchCard'
import AddMatchForm from '../components/AddMatchForm'
import { isUpcoming, SPORT_ICONS, SPORT_LABELS } from '../lib/format'
import { canLogAnotherMatch } from '../lib/matchLimits'
import type { Enums } from '../lib/database.types'

type SportCode = Enums<'sport_code'>

type MatchRow = {
  id: string
  competition: string | null
  played_at: string | null
  home_score: string | null
  away_score: string | null
  ground_id: string | null
  home_county_team_id: string | null
  away_county_team_id: string | null
}

type MatchCardWithSport = MatchCardData & { sportCode: SportCode | null }

type Tab = 'upcoming' | 'fixtures' | 'results'

type MonthGroup = { month: number; matches: MatchCardWithSport[] }
type YearGroup = { year: number; months: MonthGroup[] }

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

const PAGE_SIZE = 1000

// National Football League / National Hurling League both have "Division N"
// tagged for the regular season, but promotion-relegation playoff and final
// rounds -- which don't belong to a single division -- are tagged with just
// the bare league name. Filtering by the bare name is meant to mean "the
// whole league," so it needs to also catch every division's matches, not
// just the handful of undivided playoff rows.
const UMBRELLA_COMPETITIONS = new Set(['National Football League', 'National Hurling League'])

function matchesSelection(selection: string, values: (string | null | undefined)[]) {
  if (!selection) return true
  return values.some((v) => v === selection)
}

function matchesCompetition(selection: string, competitions: (string | null | undefined)[]) {
  if (!selection) return true
  if (UMBRELLA_COMPETITIONS.has(selection)) {
    return competitions.some((c) => c?.startsWith(selection))
  }
  return competitions.some((c) => c === selection)
}

function uniqueSorted(values: (string | null | undefined)[]): string[] {
  return [...new Set(values.filter((v): v is string => Boolean(v)))].sort()
}

// PostgREST (Supabase's data API) caps any single request at 1000 rows by
// default -- an unbounded .select() silently truncates rather than erroring,
// so a plain query only ever returned the most recent ~1000 matches
// (ordered newest-first, so everything older than that just never arrived).
// This fetches every page until one comes back short.
async function fetchAllRows<T>(
  table: string,
  select: string,
  configure?: (q: any) => any,
): Promise<T[]> {
  const rows: T[] = []
  let from = 0
  while (true) {
    let query = supabase.from(table as any).select(select)
    if (configure) query = configure(query)
    const { data, error } = await query.range(from, from + PAGE_SIZE - 1)
    if (error || !data || data.length === 0) break
    rows.push(...(data as T[]))
    if (data.length < PAGE_SIZE) break
    from += PAGE_SIZE
  }
  return rows
}

export default function Matches() {
  const { user } = useAuth()
  const [matches, setMatches] = useState<MatchCardWithSport[]>([])
  const [personalMatches, setPersonalMatches] = useState<PersonalMatch[]>([])
  const [showingAddMatch, setShowingAddMatch] = useState(false)
  const [addMatchBlocked, setAddMatchBlocked] = useState(false)
  const [checkingAddMatch, setCheckingAddMatch] = useState(false)
  const [myMatchesExpanded, setMyMatchesExpanded] = useState(true)
  const [showingFilters, setShowingFilters] = useState(false)
  const [selectedCounty, setSelectedCountyFilter] = useState('')
  const [selectedCompetition, setSelectedCompetitionFilter] = useState('')
  const [selectedVenue, setSelectedVenueFilter] = useState('')
  const [selectedSport, setSelectedSport] = useState<SportCode>('gaelic_football')
  const [tab, setTab] = useState<Tab>('upcoming')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [expandedYears, setExpandedYears] = useState<Set<number> | null>(null)
  const [expandedMonths, setExpandedMonths] = useState<Set<string>>(new Set())

  useEffect(() => {
    let cancelled = false

    async function load() {
      const rows = await fetchAllRows<MatchRow>(
        'matches',
        'id, competition, played_at, home_score, away_score, ground_id, home_county_team_id, away_county_team_id',
        (q) => q.order('played_at', { ascending: false }),
      )

      if (cancelled) return
      if (rows.length === 0) {
        setLoading(false)
        return
      }

      const teamIds = [...new Set(rows.flatMap((m) => [m.home_county_team_id, m.away_county_team_id].filter(Boolean)))] as string[]
      const groundIds = [...new Set(rows.map((m) => m.ground_id).filter(Boolean))] as string[]

      const [{ data: teams }, { data: grounds }] = await Promise.all([
        teamIds.length ? supabase.from('county_teams').select('id, county_id, sport_code').in('id', teamIds) : Promise.resolve({ data: [] as any[] }),
        groundIds.length ? supabase.from('grounds').select('id, name').in('id', groundIds) : Promise.resolve({ data: [] as any[] }),
      ])

      const countyIds = [...new Set((teams ?? []).map((t) => t.county_id))]
      const { data: counties } = countyIds.length
        ? await supabase.from('counties').select('id, name, primary_colour, secondary_colour').in('id', countyIds)
        : { data: [] as any[] }

      const countyById = new Map((counties ?? []).map((c) => [c.id, c]))
      const teamById = new Map((teams ?? []).map((t) => [t.id, t]))
      const groundNameById = new Map((grounds ?? []).map((g) => [g.id, g.name]))

      const attendance = await fetchAllRows<{ match_id: string }>('user_match_attendance', 'match_id')
      const attendanceByMatch = new Map<string, number>()
      for (const a of attendance) attendanceByMatch.set(a.match_id, (attendanceByMatch.get(a.match_id) ?? 0) + 1)

      const cards: MatchCardWithSport[] = rows.map((m) => {
        const home = m.home_county_team_id ? teamById.get(m.home_county_team_id) : null
        const away = m.away_county_team_id ? teamById.get(m.away_county_team_id) : null
        const homeCounty = home ? countyById.get(home.county_id) : null
        const awayCounty = away ? countyById.get(away.county_id) : null
        return {
          id: m.id,
          competition: m.competition,
          played_at: m.played_at,
          home_score: m.home_score,
          away_score: m.away_score,
          homeName: homeCounty?.name ?? 'TBC',
          awayName: awayCounty?.name ?? 'TBC',
          homeColours:
            homeCounty?.primary_colour && homeCounty?.secondary_colour
              ? { primary: homeCounty.primary_colour, secondary: homeCounty.secondary_colour }
              : null,
          awayColours:
            awayCounty?.primary_colour && awayCounty?.secondary_colour
              ? { primary: awayCounty.primary_colour, secondary: awayCounty.secondary_colour }
              : null,
          groundName: m.ground_id ? groundNameById.get(m.ground_id) ?? null : null,
          attendeeCount: attendanceByMatch.get(m.id) ?? 0,
          sportCode: (home?.sport_code ?? away?.sport_code ?? null) as SportCode | null,
        }
      })

      if (!cancelled) {
        setMatches(cards)
        setLoading(false)
      }
    }

    load()
    return () => {
      cancelled = true
    }
  }, [])

  const loadPersonalMatches = async () => {
    if (!user) {
      setPersonalMatches([])
      return
    }
    const { data } = await supabase
      .from('user_personal_matches')
      .select('id, home_team, away_team, competition, round, venue, played_at, home_score, away_score')
      .eq('user_id', user.id)
      .order('played_at', { ascending: false })
    setPersonalMatches(data ?? [])
  }

  useEffect(() => {
    loadPersonalMatches()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user])

  async function tapAddMatch() {
    if (!user) return
    setCheckingAddMatch(true)
    const { data: profile } = await supabase.from('user_profiles').select('is_premium').eq('id', user.id).single()
    const allowed = await canLogAnotherMatch(user.id, profile?.is_premium ?? false)
    setCheckingAddMatch(false)
    if (allowed) {
      setAddMatchBlocked(false)
      setShowingAddMatch(true)
    } else {
      setAddMatchBlocked(true)
    }
  }

  async function deletePersonalMatch(id: string) {
    await supabase.from('user_personal_matches').delete().eq('id', id)
    await loadPersonalMatches()
  }

  const sportFiltered = useMemo(
    () => matches.filter((m) => m.sportCode === selectedSport),
    [matches, selectedSport],
  )

  const searchFiltered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return sportFiltered
    return sportFiltered.filter(
      (m) =>
        m.homeName.toLowerCase().includes(q) ||
        m.awayName.toLowerCase().includes(q) ||
        (m.competition ?? '').toLowerCase().includes(q) ||
        (m.groundName ?? '').toLowerCase().includes(q) ||
        (m.played_at && new Date(m.played_at).getFullYear().toString() === q),
    )
  }, [sportFiltered, search])

  const personalSearchFiltered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return personalMatches
    return personalMatches.filter(
      (m) =>
        m.home_team.toLowerCase().includes(q) ||
        m.away_team.toLowerCase().includes(q) ||
        (m.competition ?? '').toLowerCase().includes(q) ||
        (m.venue ?? '').toLowerCase().includes(q) ||
        new Date(m.played_at).getFullYear().toString() === q,
    )
  }, [personalMatches, search])

  const countyOptions = useMemo(
    () =>
      uniqueSorted([
        ...sportFiltered.flatMap((m) => [m.homeName, m.awayName]),
        ...personalMatches.flatMap((m) => [m.home_team, m.away_team]),
      ]),
    [sportFiltered, personalMatches],
  )
  const competitionOptions = useMemo(
    () => uniqueSorted([...sportFiltered.map((m) => m.competition), ...personalMatches.map((m) => m.competition)]),
    [sportFiltered, personalMatches],
  )
  const venueOptions = useMemo(
    () => uniqueSorted([...sportFiltered.map((m) => m.groundName), ...personalMatches.map((m) => m.venue)]),
    [sportFiltered, personalMatches],
  )
  const activeFilterCount = [selectedCounty, selectedCompetition, selectedVenue].filter(Boolean).length
  const hasQueryOrFilters = search.trim() !== '' || activeFilterCount > 0

  const filteredMatches = useMemo(
    () =>
      searchFiltered.filter(
        (m) =>
          matchesSelection(selectedCounty, [m.homeName, m.awayName]) &&
          matchesCompetition(selectedCompetition, [m.competition]) &&
          matchesSelection(selectedVenue, [m.groundName]),
      ),
    [searchFiltered, selectedCounty, selectedCompetition, selectedVenue],
  )

  const filteredPersonalMatches = useMemo(
    () =>
      personalSearchFiltered.filter(
        (m) =>
          matchesSelection(selectedCounty, [m.home_team, m.away_team]) &&
          matchesCompetition(selectedCompetition, [m.competition]) &&
          matchesSelection(selectedVenue, [m.venue]),
      ),
    [personalSearchFiltered, selectedCounty, selectedCompetition, selectedVenue],
  )

  // Upcoming and Fixtures show the same list -- matching MatchesView.swift
  // and the Android port, where both tabs are separate entry points onto
  // identical content rather than two different filters.
  const upcomingList = useMemo(
    () =>
      filteredMatches
        .filter((m) => !Boolean(m.home_score && m.away_score) && m.played_at && isUpcoming(m.played_at, false))
        .sort((a, b) => (a.played_at ?? '').localeCompare(b.played_at ?? '')),
    [filteredMatches],
  )

  const resultsList = useMemo(
    () => filteredMatches.filter((m) => Boolean(m.home_score && m.away_score)),
    [filteredMatches],
  )

  const yearGroups = useMemo<YearGroup[]>(() => {
    const byYear = new Map<number, Map<number, MatchCardWithSport[]>>()
    for (const m of resultsList) {
      if (!m.played_at) continue
      const d = new Date(m.played_at)
      const year = d.getFullYear()
      const month = d.getMonth() + 1
      if (!byYear.has(year)) byYear.set(year, new Map())
      const byMonth = byYear.get(year)!
      if (!byMonth.has(month)) byMonth.set(month, [])
      byMonth.get(month)!.push(m)
    }
    return [...byYear.entries()]
      .map(([year, byMonth]) => ({
        year,
        months: [...byMonth.entries()]
          .map(([month, ms]) => ({
            month,
            matches: [...ms].sort((a, b) => (b.played_at ?? '').localeCompare(a.played_at ?? '')),
          }))
          .sort((a, b) => b.month - a.month),
      }))
      .sort((a, b) => b.year - a.year)
  }, [resultsList])

  const undatedResults = useMemo(() => resultsList.filter((m) => !m.played_at), [resultsList])

  // Reset to the most recent year/month whenever the underlying result set
  // changes shape (e.g. switching sport) rather than only on first load.
  useEffect(() => {
    if (yearGroups.length === 0) {
      setExpandedYears(new Set())
      setExpandedMonths(new Set())
      return
    }
    const mostRecent = yearGroups[0]
    setExpandedYears(new Set([mostRecent.year]))
    setExpandedMonths(mostRecent.months.length > 0 ? new Set([`${mostRecent.year}-${mostRecent.months[0].month}`]) : new Set())
  }, [yearGroups])

  const openYears = expandedYears ?? new Set<number>()

  function toggleYear(year: number) {
    const next = new Set(openYears)
    if (next.has(year)) next.delete(year)
    else next.add(year)
    setExpandedYears(next)
  }

  function toggleMonth(key: string) {
    const next = new Set(expandedMonths)
    if (next.has(key)) next.delete(key)
    else next.add(key)
    setExpandedMonths(next)
  }

  const displayedList = tab === 'results' ? null : upcomingList
  const sportOptions: SportCode[] = ['gaelic_football', 'hurling']

  return (
    <div className="page">
      <h1>Fixtures &amp; results</h1>
      <p className="muted">
        Missed checking in on the day? Find the match below and check in any time — even years later.
      </p>
      <div className="filter-tabs">
        {sportOptions.map((sport) => (
          <button key={sport} className={selectedSport === sport ? 'active' : ''} onClick={() => setSelectedSport(sport)}>
            {SPORT_ICONS[sport]} {SPORT_LABELS[sport]}
          </button>
        ))}
      </div>
      <div className="matches-search-row">
        <input
          className="search-input"
          placeholder="Search by team, competition, ground or year…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <button
          className={activeFilterCount > 0 ? 'btn btn-outline btn-sm active' : 'btn btn-outline btn-sm'}
          onClick={() => setShowingFilters((v) => !v)}
        >
          🔎 Filters{activeFilterCount > 0 ? ` (${activeFilterCount})` : ''}
        </button>
      </div>

      {showingFilters && (
        <div className="card match-filters">
          <label>
            County
            <select value={selectedCounty} onChange={(e) => setSelectedCountyFilter(e.target.value)}>
              <option value="">Any county</option>
              {countyOptions.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </label>
          <label>
            Competition
            <select value={selectedCompetition} onChange={(e) => setSelectedCompetitionFilter(e.target.value)}>
              <option value="">Any competition</option>
              {competitionOptions.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </label>
          <label>
            Venue
            <select value={selectedVenue} onChange={(e) => setSelectedVenueFilter(e.target.value)}>
              <option value="">Any venue</option>
              {venueOptions.map((v) => (
                <option key={v} value={v}>
                  {v}
                </option>
              ))}
            </select>
          </label>
          <button
            className="btn btn-ghost btn-sm"
            disabled={activeFilterCount === 0}
            onClick={() => {
              setSelectedCountyFilter('')
              setSelectedCompetitionFilter('')
              setSelectedVenueFilter('')
            }}
          >
            Reset filters
          </button>
        </div>
      )}

      <div className="filter-tabs">
        <button className={tab === 'upcoming' ? 'active' : ''} onClick={() => setTab('upcoming')}>
          Upcoming
        </button>
        <button className={tab === 'fixtures' ? 'active' : ''} onClick={() => setTab('fixtures')}>
          Fixtures
        </button>
        <button className={tab === 'results' ? 'active' : ''} onClick={() => setTab('results')}>
          Results
        </button>
      </div>

      {user && tab === 'results' && !showingAddMatch && (
        <button className="btn btn-outline btn-sm add-match-toggle" onClick={tapAddMatch} disabled={checkingAddMatch}>
          {checkingAddMatch ? 'Checking…' : '+ Add a match'}
        </button>
      )}
      {addMatchBlocked && (
        <p className="muted small">
          You've reached the free plan's 10-match limit — <Link to="/premium">upgrade to Premium</Link> to log more.
        </p>
      )}
      {showingAddMatch && (
        <AddMatchForm
          onAdded={() => {
            setShowingAddMatch(false)
            loadPersonalMatches()
          }}
          onCancel={() => setShowingAddMatch(false)}
        />
      )}

      {loading ? (
        <p className="muted">Loading matches…</p>
      ) : tab !== 'results' ? (
        displayedList && displayedList.length === 0 ? (
          <p className="muted">{hasQueryOrFilters ? 'No matches found.' : 'No upcoming fixtures.'}</p>
        ) : (
          <div className="card-grid">
            {displayedList!.map((m) => (
              <MatchCard key={m.id} match={m} />
            ))}
          </div>
        )
      ) : yearGroups.length === 0 && undatedResults.length === 0 && filteredPersonalMatches.length === 0 ? (
        <p className="muted">
          {hasQueryOrFilters ? 'No matches found. Try a different search or filter.' : 'No results yet — check back once games have been played.'}
        </p>
      ) : (
        <div className="results-groups">
          {filteredPersonalMatches.length > 0 && (
            <div className="results-year">
              <button className="results-group-header" onClick={() => setMyMatchesExpanded((v) => !v)}>
                <span>
                  {myMatchesExpanded ? '▾' : '▸'} My Matches
                </span>
                <span className="muted small">
                  {filteredPersonalMatches.length} match{filteredPersonalMatches.length === 1 ? '' : 'es'}
                </span>
              </button>
              {myMatchesExpanded && (
                <div className="card-grid">
                  {filteredPersonalMatches.map((m) => (
                    <PersonalMatchCard key={m.id} match={m} onDelete={() => deletePersonalMatch(m.id)} />
                  ))}
                </div>
              )}
            </div>
          )}
          {yearGroups.map((yg) => {
            const isOpen = openYears.has(yg.year)
            const total = yg.months.reduce((sum, mo) => sum + mo.matches.length, 0)
            return (
              <div key={yg.year} className="results-year">
                <button className="results-group-header" onClick={() => toggleYear(yg.year)}>
                  <span>
                    {isOpen ? '▾' : '▸'} {yg.year}
                  </span>
                  <span className="muted small">
                    {total} match{total === 1 ? '' : 'es'}
                  </span>
                </button>
                {isOpen &&
                  yg.months.map((mo) => {
                    const key = `${yg.year}-${mo.month}`
                    const monthOpen = expandedMonths.has(key)
                    return (
                      <div key={key} className="results-month">
                        <button className="results-group-header results-month-header" onClick={() => toggleMonth(key)}>
                          <span>
                            {monthOpen ? '▾' : '▸'} {MONTH_NAMES[mo.month - 1]}
                          </span>
                          <span className="muted small">
                            {mo.matches.length} match{mo.matches.length === 1 ? '' : 'es'}
                          </span>
                        </button>
                        {monthOpen && (
                          <div className="card-grid">
                            {mo.matches.map((m) => (
                              <MatchCard key={m.id} match={m} />
                            ))}
                          </div>
                        )}
                      </div>
                    )
                  })}
              </div>
            )
          })}
          {undatedResults.length > 0 && (
            <div className="results-year">
              <div className="results-group-header">
                <span>No confirmed date</span>
                <span className="muted small">
                  {undatedResults.length} match{undatedResults.length === 1 ? '' : 'es'}
                </span>
              </div>
              <div className="card-grid">
                {undatedResults.map((m) => (
                  <MatchCard key={m.id} match={m} />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
