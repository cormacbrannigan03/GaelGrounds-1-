import { Link } from 'react-router-dom'

export default function NotFound() {
  return (
    <div className="page">
      <h1>Page not found</h1>
      <Link to="/" className="link">
        ← Back home
      </Link>
    </div>
  )
}
