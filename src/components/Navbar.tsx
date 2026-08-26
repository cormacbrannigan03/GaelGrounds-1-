import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export default function Navbar() {
  const { user, signOut } = useAuth()
  const navigate = useNavigate()

  return (
    <header className="navbar">
      <div className="navbar-inner">
        <NavLink to="/" className="brand">
          <span className="brand-mark">GG</span>
          <span>GaelGrounds</span>
        </NavLink>

        {user && (
          <nav className="nav-links">
            <NavLink to="/matches" className={({ isActive }) => (isActive ? 'active' : '')}>
              Matches
            </NavLink>
            <NavLink to="/grounds" className={({ isActive }) => (isActive ? 'active' : '')}>
              Grounds
            </NavLink>
            <NavLink to="/counties" className={({ isActive }) => (isActive ? 'active' : '')}>
              Counties
            </NavLink>
            <NavLink to="/leaderboard" className={({ isActive }) => (isActive ? 'active' : '')}>
              Leaderboard
            </NavLink>
            <NavLink to="/premium" className={({ isActive }) => (isActive ? 'active' : '')}>
              Premium
            </NavLink>
            <NavLink to="/friends" className={({ isActive }) => (isActive ? 'active' : '')}>
              Friends
            </NavLink>
            <NavLink to="/profile" className={({ isActive }) => (isActive ? 'active' : '')}>
              Profile
            </NavLink>
          </nav>
        )}

        <div className="navbar-actions">
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
    </header>
  )
}
