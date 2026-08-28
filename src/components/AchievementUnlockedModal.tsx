import { useEffect } from 'react'
import type { AchievementDefinition } from '../lib/achievements'

// Matches AchievementUnlockedView in ios/GaelGrounds/Views/Matches/CheckInPanel.swift
// -- a real congratulations modal instead of a small dismissible toast,
// shown after a check-in unlocks one or more achievements.
export default function AchievementUnlockedModal({
  achievements,
  onClose,
}: {
  achievements: AchievementDefinition[]
  onClose: () => void
}) {
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [onClose])

  return (
    <div className="achievement-modal-overlay" onClick={onClose}>
      <div className="achievement-modal" onClick={(e) => e.stopPropagation()}>
        <h2>Congratulations!</h2>
        <p className="muted">
          {achievements.length === 1 ? "You've unlocked an achievement" : "You've unlocked new achievements"}
        </p>

        <ul className="achievement-modal-list">
          {achievements.map((def) => (
            <li key={def.id}>
              <span className="achievement-modal-icon">🏆</span>
              <span>
                <strong>{def.title}</strong>
                <span className="muted small">{def.description}</span>
              </span>
            </li>
          ))}
        </ul>

        <button className="btn btn-primary btn-block" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  )
}
