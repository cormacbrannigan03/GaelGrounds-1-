import { Link } from 'react-router-dom'
import { formatMatchDate, hexToRgbTriplet, isLive, isUpcoming, type CountyColours } from '../lib/format'

export type MatchCardData = {
  id: string
  competition: string | null
  played_at: string | null
  home_score: string | null
  away_score: string | null
  homeName: string
  awayName: string
  homeColours?: CountyColours | null
  awayColours?: CountyColours | null
  groundName: string | null
  attendeeCount?: number
}

/**
 * A county's primary colour sits at its own edge, fades through its
 * secondary colour, and is fully transparent by the card's midpoint --
 * so the `.card` background shows through in the middle rather than a
 * hardcoded white, which is what keeps this looking right in dark mode.
 */
function sideWash(colours: CountyColours | null | undefined, direction: 'right' | 'left'): string | null {
  if (!colours) return null
  const primary = hexToRgbTriplet(colours.primary)
  const secondary = hexToRgbTriplet(colours.secondary)
  return `linear-gradient(to ${direction}, rgba(${primary}, 0.34) 0%, rgba(${secondary}, 0.20) 30%, rgba(${secondary}, 0) 55%)`
}

export default function MatchCard({ match }: { match: MatchCardData }) {
  const hasScore = Boolean(match.home_score && match.away_score)
  const live = match.played_at ? isLive(match.played_at, hasScore) : false
  const upcoming = match.played_at ? isUpcoming(match.played_at, hasScore) : false

  const washLayers = [sideWash(match.homeColours, 'right'), sideWash(match.awayColours, 'left')].filter(
    (layer): layer is string => layer !== null,
  )
  const washStyle = washLayers.length > 0 ? { backgroundImage: washLayers.join(', ') } : undefined

  return (
    <Link to={`/matches/${match.id}`} className="card match-card" style={washStyle}>
      <div className="match-card-top">
        <span className="competition">{match.competition ?? 'Gaelic Games'}</span>
        {live && <span className="badge badge-live">● LIVE</span>}
        {!live && upcoming && <span className="badge badge-upcoming">Upcoming</span>}
      </div>
      <div className="match-card-teams">
        <span className="team-name">{match.homeName}</span>
        <span className="score">{hasScore ? `${match.home_score} – ${match.away_score}` : 'v'}</span>
        <span className="team-name">{match.awayName}</span>
      </div>
      <div className="match-card-meta">
        <span>{match.played_at ? formatMatchDate(match.played_at) : 'Date to be confirmed'}</span>
        {match.groundName && <span>· {match.groundName}</span>}
        {typeof match.attendeeCount === 'number' && (
          <span className="attendee-pill">👥 {match.attendeeCount} checked in</span>
        )}
      </div>
    </Link>
  )
}
