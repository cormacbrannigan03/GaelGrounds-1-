import { formatMatchDate } from '../lib/format'

export type PersonalMatch = {
  id: string
  home_team: string
  away_team: string
  competition: string | null
  round: string | null
  venue: string | null
  played_at: string
  home_score: string | null
  away_score: string | null
}

export default function PersonalMatchCard({ match, onDelete }: { match: PersonalMatch; onDelete: () => void }) {
  const hasScore = Boolean(match.home_score && match.away_score)

  return (
    <div className="card personal-match-card">
      <div className="match-card-top">
        <span className="competition">{match.competition ?? 'Personal Match'}</span>
        <button className="btn-ghost personal-match-delete" onClick={onDelete} aria-label="Delete match" title="Delete match">
          🗑
        </button>
      </div>
      {match.round && <p className="muted small personal-match-round">{match.round}</p>}
      <div className="match-card-teams">
        <span className="team-name">{match.home_team}</span>
        <span className="score">{hasScore ? `${match.home_score} – ${match.away_score}` : 'v'}</span>
        <span className="team-name">{match.away_team}</span>
      </div>
      <div className="match-card-meta">
        <span>{formatMatchDate(match.played_at)}</span>
        {match.venue && <span>· {match.venue}</span>}
      </div>
    </div>
  )
}
