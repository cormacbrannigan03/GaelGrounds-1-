import { Link } from 'react-router-dom'
import { formatMatchDate, isLive, isUpcoming } from '../lib/format'

export type MatchCardData = {
  id: string
  competition: string | null
  played_at: string
  home_score: string | null
  away_score: string | null
  homeName: string
  awayName: string
  groundName: string | null
  attendeeCount?: number
}

export default function MatchCard({ match }: { match: MatchCardData }) {
  const hasScore = Boolean(match.home_score && match.away_score)
  const live = isLive(match.played_at, hasScore)
  const upcoming = isUpcoming(match.played_at, hasScore)

  return (
    <Link to={`/matches/${match.id}`} className="card match-card">
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
        <span>{formatMatchDate(match.played_at)}</span>
        {match.groundName && <span>· {match.groundName}</span>}
        {typeof match.attendeeCount === 'number' && (
          <span className="attendee-pill">👥 {match.attendeeCount} checked in</span>
        )}
      </div>
    </Link>
  )
}
