import { useState, useEffect } from 'react'
import Dashboard from './pages/Dashboard'
import Orders from './pages/Orders'
import Products from './pages/Products'

function App() {
  const [page, setPage] = useState('dashboard')
  const [health, setHealth] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetch('/api/health')
      .then(r => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json() })
      .then(d => setHealth(d))
      .catch(e => setError(e.message))
  }, [])

  const version = health?.version || '...'
  const environment = health?.environment || 'Production'

  const tabs = [
    { id: 'dashboard', label: 'Dashboard', icon: '📊' },
    { id: 'orders', label: 'Orders', icon: '📦' },
    { id: 'products', label: 'Products', icon: '🏷️' },
  ]

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {error && (
        <div className="bg-red-600 text-white px-4 py-3 text-center font-medium">
          ⚠️ API Error: {error}
        </div>
      )}
      <header className="bg-gradient-to-r from-blue-800 to-purple-700 text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <span className="text-2xl font-bold">⚡ ShopFast</span>
              {health && (
                <span className="bg-white/20 text-xs px-2 py-1 rounded-full font-mono">
                  v{version}
                </span>
              )}
            </div>
            <nav className="flex gap-1">
              {tabs.map(t => (
                <button
                  key={t.id}
                  onClick={() => setPage(t.id)}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                    page === t.id
                      ? 'bg-white/25 text-white'
                      : 'text-white/70 hover:bg-white/10 hover:text-white'
                  }`}
                >
                  {t.icon} {t.label}
                </button>
              ))}
            </nav>
          </div>
        </div>
      </header>

      <main className="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 lg:px-8 py-8">
        {page === 'dashboard' && <Dashboard />}
        {page === 'orders' && <Orders />}
        {page === 'products' && <Products />}
      </main>

      <footer className="bg-gray-800 text-gray-400 text-center py-4 text-sm">
        ShopFast Admin v{version} — {environment}
      </footer>
    </div>
  )
}

export default App
