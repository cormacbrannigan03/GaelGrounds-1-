import { Link } from 'react-router-dom'

export type AlternateGround = {
  id: string
  name: string
  visited?: boolean
}

export type GroundCardData = {
  id: string
  name: string
  countyName: string
  capacity: number | null
  visited?: boolean
  alternateGrounds?: AlternateGround[]
}

export default function GroundCard({ ground }: { ground: GroundCardData }) {
  return (
    <div className={`card ground-card ${ground.visited ? 'visited' : ''}`}>
      <Link to={`/grounds/${ground.id}`} className="ground-card-link">
        <div className="ground-card-top">
          <h3>{ground.name}</h3>
          {ground.visited && <span className="badge badge-visited">✓ Visited</span>}
        </div>
        <p className="muted">{ground.countyName}</p>
        {ground.capacity && <p className="muted small">Capacity: {ground.capacity.toLocaleString()}</p>}
      </Link>
      {ground.alternateGrounds && ground.alternateGrounds.length > 0 && (
        <div className="ground-card-alternates">
          <p className="muted small">Also in {ground.countyName}:</p>
          <ul>
            {ground.alternateGrounds.map((alt) => (
              <li key={alt.id}>
                <Link to={`/grounds/${alt.id}`}>
                  {alt.name}
                  {alt.visited && <span className="badge badge-visited">✓</span>}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
