import { createContext, useContext, useState, type ReactNode } from 'react'

type Override = { primary: string; secondary: string } | null

type BackgroundContextValue = {
  override: Override
  setOverride: (o: Override) => void
}

const BackgroundContext = createContext<BackgroundContextValue | undefined>(undefined)

export function BackgroundProvider({ children }: { children: ReactNode }) {
  const [override, setOverride] = useState<Override>(null)
  return <BackgroundContext.Provider value={{ override, setOverride }}>{children}</BackgroundContext.Provider>
}

export function useBackground() {
  const ctx = useContext(BackgroundContext)
  if (!ctx) throw new Error('useBackground must be used within BackgroundProvider')
  return ctx
}
