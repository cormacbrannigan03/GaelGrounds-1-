const STOPS: { tier: 'bronze' | 'silver' | 'gold'; threshold: number }[] = [
  { tier: 'bronze', threshold: 10 },
  { tier: 'silver', threshold: 25 },
  { tier: 'gold', threshold: 50 },
]

/** Visual version of the 10/25/50 bronze/silver/gold thresholds in tierForHomeMatchCount. */
export default function TierRoadmap({ count }: { count: number }) {
  const fillPct = (Math.min(count, 50) / 50) * 100

  return (
    <div className="tier-roadmap">
      <div className="tier-roadmap-track">
        <div className="tier-roadmap-fill" style={{ width: `${fillPct}%` }} />
        {STOPS.map((stop) => (
          <div
            key={stop.tier}
            className={`tier-roadmap-stop tier-roadmap-stop-${stop.tier} ${count >= stop.threshold ? 'reached' : ''}`}
            style={{ left: `${(stop.threshold / 50) * 100}%` }}
          />
        ))}
      </div>
      <div className="tier-roadmap-labels">
        {STOPS.map((stop) => (
          <span
            key={stop.tier}
            className={`tier-roadmap-label tier-roadmap-label-${stop.tier} ${count >= stop.threshold ? 'reached' : ''}`}
            style={{ left: `${(stop.threshold / 50) * 100}%` }}
          >
            {stop.tier[0].toUpperCase() + stop.tier.slice(1)}
          </span>
        ))}
      </div>
    </div>
  )
}
