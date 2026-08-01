import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import GroundCheckInPanel from '../components/GroundCheckInPanel'

type Ground = { id: string; name: string; capacity: number | null; county_id: string; latitude: number; longitude: number }
type County = { id: string; name: string }

export default function GroundDetail() {
  const { id } = useParams<{ id: string }>()
  const [ground, setGround] = useState<Ground | null>(null)
  const [county, setCounty] = useState<County | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!id) return
    let cancelled = false

    supabase
      .from('grounds')
      .select('id, name, capacity, county_id, latitude, longitude')
      .eq('id', id)
      .single()
      .then(async ({ data }) => {
        if (cancelled || !data) {
          if (!cancelled) setLoading(false)
          return
        }
        setGround(data)
        const { data: countyData } = await supabase.from('counties').select('id, name').eq('id', data.county_id).single()
        if (!cancelled) {
          setCounty(countyData)
          setLoading(false)
        }
      })

    return () => {
      cancelled = true
    }
  }, [id])

  if (loading) return <div className="page"><p className="muted">Loading…</p></div>
  if (!ground) return <div className="page"><p>Ground not found.</p></div>

  const mapUrl = `https://www.openstreetmap.org/?mlat=${ground.latitude}&mlon=${ground.longitude}#map=15/${ground.latitude}/${ground.longitude}`

  return (
    <div className="page">
      <div className="page-header">
        <h1>{ground.name}</h1>
        {county && (
          <p className="muted">
            <Link to={`/counties/${county.id}`}>{county.name}</Link>
          </p>
        )}
        {ground.capacity && <p className="muted small">Capacity: {ground.capacity.toLocaleString()}</p>}
        <a href={mapUrl} target="_blank" rel="noreferrer" className="link">
          View on map →
        </a>
      </div>

      <GroundCheckInPanel groundId={ground.id} />
    </div>
  )
}
