import { useEffect } from 'react'
import { useBackground } from '../context/BackgroundContext'

// Mirrors iOS detail views calling `.countyBackground(_:)` with a specific
// county's own colours instead of the signed-in user's supported county --
// CountyDetailView uses county?.name and GroundDetailView uses the ground's
// countyName. Reverts to the app-wide supported-county wash (App.tsx) the
// moment the page unmounts or its colours go away.
export function useCountyPageBackground(primaryColour: string | null | undefined, secondaryColour: string | null | undefined) {
  const { setOverride } = useBackground()

  useEffect(() => {
    setOverride(primaryColour && secondaryColour ? { primary: primaryColour, secondary: secondaryColour } : null)
    return () => setOverride(null)
  }, [primaryColour, secondaryColour, setOverride])
}
