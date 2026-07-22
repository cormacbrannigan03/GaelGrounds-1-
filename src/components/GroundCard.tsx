import { Link } from 'react-router-dom'

export type GroundCardData = {
  id: string
  name: string
  countyName: string
  capacity: number | null
  visited?: boolean
}

export default function GroundCard({ ground }: { ground: GroundCardData }) {
  return (
    <Link to={`/grounds/${ground.id}`} className={`card ground-card ${ground.visited ? 'visited' : ''}`}>
      <div className="ground-card-top">
        <h3>{ground.name}</h3>
        {ground.visited && <span className="badge badge-visited">✓ Visited</span>}
      </div>
      <p className="muted">{ground.countyName}</p>
      {ground.capacity && <p className="muted small">Capacity: {ground.capacity.toLocaleString()}</p>}
    </Link>
  )
}
