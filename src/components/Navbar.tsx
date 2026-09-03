import { useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const LINKS = [
  { to: '/matches', label: 'Matches' },
  { to: '/grounds', label: 'Grounds' },
  { to: '/counties', label: 'Counties' },
  { to: '/leaderboard', label: 'Leaderboard' },
  { to: '/premium', label: 'Premium' },
  { to: '/friends', label: 'Friends' },
  { to: '/profile', label: 'Profile' },
]

export default function Navbar() {
  const { user, signOut } = useAuth()
  const navigate = useNavigate()
  const [menuOpen, setMenuOpen] = useState(false)

  return (
    <header className="navbar">
      <div className="navbar-inner">
        {user && (
          <button
            className="hamburger-btn"
            aria-label="Open menu"
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(true)}
          >
            <span />
            <span />
            <span />
          </button>
        )}

        <NavLink to="/" className="brand">
          <span className="brand-mark">GG</span>
          <span>GaelGrounds</span>
        </NavLink>

        {user && (
          <nav className="nav-links">
            {LINKS.map((link) => (
              <NavLink key={link.to} to={link.to} className={({ isActive }) => (isActive ? 'active' : '')}>
                {link.label}
              </NavLink>
            ))}
          </nav>
        )}

        <div className="navbar-actions">
          <a
            href="https://apps.apple.com/app/id6799921807"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-outline btn-sm navbar-store-link"
          >
            iOS App
          </a>
          {user ? (
            <button
              className="btn btn-ghost"
              onClick={async () => {
                await signOut()
                navigate('/')
              }}
            >
              Sign out
            </button>
          ) : (
            <NavLink to="/auth" className="btn btn-primary">
              Sign in
            </NavLink>
          )}
        </div>
      </div>

      {user && (
        <>
          <div
            className={`mobile-nav-backdrop${menuOpen ? ' open' : ''}`}
            onClick={() => setMenuOpen(false)}
            aria-hidden="true"
          />
          <nav className={`mobile-nav-drawer${menuOpen ? ' open' : ''}`} aria-label="Main navigation">
            <div className="mobile-nav-drawer-header">
              <span className="brand">
                <span className="brand-mark">GG</span>
                <span>GaelGrounds</span>
              </span>
              <button className="mobile-nav-close" aria-label="Close menu" onClick={() => setMenuOpen(false)}>
                ×
              </button>
            </div>
            {LINKS.map((link) => (
              <NavLink
                key={link.to}
                to={link.to}
                className={({ isActive }) => (isActive ? 'active' : '')}
                onClick={() => setMenuOpen(false)}
              >
                {link.label}
              </NavLink>
            ))}
          </nav>
        </>
      )}
    </header>
  )
}
