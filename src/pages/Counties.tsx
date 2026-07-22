import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import type { Enums } from '../lib/database.types'

type CountyRow = {
  id: string
  name: string
  province: Enums<'province'>
  primary_colour: string | null
}

const PROVINCE_ORDER: Enums<'province'>[] = ['Leinster', 'Munster', 'Connacht', 'Ulster']

export default function Counties() {
  const [counties, setCounties] = useState<CountyRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase
      .from('counties')
      .select('id, name, province, primary_colour')
      .order('name')
      .then(({ data }) => {
        setCounties(data ?? [])
        setLoading(false)
      })
  }, [])

  return (
    <div className="page">
      <h1>All 32 counties</h1>
      <p className="muted">Every county competing at intercounty level, across Gaelic football, hurling, camogie and ladies' football.</p>

      {loading ? (
        <p className="muted">Loading counties…</p>
      ) : (
        PROVINCE_ORDER.map((province) => {
          const inProvince = counties.filter((c) => c.province === province)
          if (inProvince.length === 0) return null
          return (
            <section key={province}>
              <h2>{province}</h2>
              <div className="county-grid">
                {inProvince.map((c) => (
                  <Link
                    key={c.id}
                    to={`/counties/${c.id}`}
                    className="county-chip"
                    style={{ borderColor: c.primary_colour ?? undefined }}
                  >
                    {c.name}
                  </Link>
                ))}
              </div>
            </section>
          )
        })
      )}
    </div>
  )
}
