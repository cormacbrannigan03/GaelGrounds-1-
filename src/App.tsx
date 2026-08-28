import { lazy, Suspense } from 'react'
import { Routes, Route } from 'react-router-dom'
import Navbar from './components/Navbar'
import ProtectedRoute from './components/ProtectedRoute'
import { useAuth } from './context/AuthContext'
import { useBackground } from './context/BackgroundContext'
import { hexToRgbTriplet } from './lib/format'
import Dashboard from './pages/Dashboard'
import AuthPage from './pages/AuthPage'
import ConfirmEmail from './pages/ConfirmEmail'

// Everything below is lazy-loaded: Dashboard and AuthPage above are the two
// pages almost every visitor lands on first (a signed-in user redirected
// straight to '/', or a new/signed-out one going to '/auth'), so they ship
// in the initial bundle. Every other page only used to be reachable by
// navigating there anyway, so there's no reason a first-time visitor on a
// slow connection -- exactly the paying-customer sign-up scenario -- should
// have to download Achievements/Leaderboard/Premium/every detail page
// before they can even see the sign-in form.
const Counties = lazy(() => import('./pages/Counties'))
const CountyDetail = lazy(() => import('./pages/CountyDetail'))
const TeamDetail = lazy(() => import('./pages/TeamDetail'))
const Grounds = lazy(() => import('./pages/Grounds'))
const GroundDetail = lazy(() => import('./pages/GroundDetail'))
const Matches = lazy(() => import('./pages/Matches'))
const MatchDetail = lazy(() => import('./pages/MatchDetail'))
const Profile = lazy(() => import('./pages/Profile'))
const Achievements = lazy(() => import('./pages/Achievements'))
const Friends = lazy(() => import('./pages/Friends'))
const FriendProfile = lazy(() => import('./pages/FriendProfile'))
const Leaderboard = lazy(() => import('./pages/Leaderboard'))
const Premium = lazy(() => import('./pages/Premium'))
const NotFound = lazy(() => import('./pages/NotFound'))

// Matches Theme.swift's brandGreen/brandGold -- the same default the
// body's CSS gradient already falls back to when no county is set.
const DEFAULT_PRIMARY = '#0b3d2e'
const DEFAULT_SECONDARY = '#d9a441'

export default function App() {
  const { supportedCounty } = useAuth()
  const { override } = useBackground()

  // Mirrors countyBackground(_:) in ios/GaelGrounds/Utilities/Theme.swift --
  // same four gradient stops, same diagonal direction. When no county is
  // set this intentionally matches the default green/gold wash already on
  // body (see index.css), just re-applied here so switching a supported
  // county on/off doesn't leave a visible seam between the two layers.
  // `override` is set by useCountyPageBackground() on detail pages that,
  // like CountyDetailView/GroundDetailView on iOS, tint the page with a
  // specific county's own colours instead of the signed-in user's.
  const primary = override?.primary ?? supportedCounty?.primaryColour ?? DEFAULT_PRIMARY
  const secondary = override?.secondary ?? supportedCounty?.secondaryColour ?? DEFAULT_SECONDARY
  const countyBackground = {
    backgroundImage: `linear-gradient(135deg,
      rgba(${hexToRgbTriplet(primary)}, 0.94) 0%,
      rgba(${hexToRgbTriplet(primary)}, 0.78) 28%,
      rgba(${hexToRgbTriplet(secondary)}, 0.72) 72%,
      rgba(${hexToRgbTriplet(secondary)}, 0.92) 100%)`,
  }

  return (
    <>
      {/* Full-bleed backdrop behind everything -- <main> itself is a
          constrained, centered content column (max-width: 1080px), so the
          gradient has to live on its own full-viewport layer instead of on
          main directly, or it'd render as a boxed block rather than a
          page-wide wash. */}
      <div className="app-background" style={countyBackground} aria-hidden="true" />
      <Navbar />
      <main>
        <Suspense fallback={<div className="page-loading">Loading…</div>}>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/auth" element={<AuthPage />} />
            <Route path="/auth/confirm-email" element={<ConfirmEmail />} />
            <Route path="/counties" element={<Counties />} />
            <Route path="/counties/:id" element={<CountyDetail />} />
            <Route path="/counties/:countyId/teams/:teamId" element={<TeamDetail />} />
            <Route path="/grounds" element={<Grounds />} />
            <Route path="/grounds/:id" element={<GroundDetail />} />
            <Route path="/matches" element={<Matches />} />
            <Route path="/matches/:id" element={<MatchDetail />} />
            <Route
              path="/profile"
              element={
                <ProtectedRoute>
                  <Profile />
                </ProtectedRoute>
              }
            />
            <Route
              path="/friends"
              element={
                <ProtectedRoute>
                  <Friends />
                </ProtectedRoute>
              }
            />
            <Route
              path="/friends/:id"
              element={
                <ProtectedRoute>
                  <FriendProfile />
                </ProtectedRoute>
              }
            />
            <Route
              path="/achievements"
              element={
                <ProtectedRoute>
                  <Achievements />
                </ProtectedRoute>
              }
            />
            <Route path="/leaderboard" element={<Leaderboard />} />
            <Route path="/premium" element={<Premium />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </Suspense>
      </main>
    </>
  )
}
