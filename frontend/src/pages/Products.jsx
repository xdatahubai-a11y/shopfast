import useFetch from '../hooks/useFetch'
import Spinner from '../components/Spinner'

export default function Products() {
  const { data: rawData, loading, error } = useFetch('/api/products')

  if (loading) return <Spinner />
  if (error) return (
    <div className="bg-danger/5 border border-danger/20 text-danger px-6 py-4 rounded-xl text-sm font-medium">
      Failed to load products: {error}
    </div>
  )

  // API returns flat array or {products: [...]}
  const products = Array.isArray(rawData) ? rawData : (rawData?.products || [])

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-base font-semibold text-text-primary">Products</h1>
          <p className="text-xs text-text-muted mt-0.5">{products.length} active products</p>
        </div>
        <input
          type="text"
          placeholder="Search products..."
          className="text-sm px-3 py-1.5 border border-border rounded-lg bg-surface text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 w-56"
        />
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
        {products.map(p => (
          <div key={p.id} className="bg-surface rounded-xl border border-border overflow-hidden hover:shadow-sm transition-shadow group">
            <div className="h-44 bg-surface-secondary flex items-center justify-center">
              {p.image_url ? (
                <img src={p.image_url} alt={p.name} className="w-full h-full object-cover" />
              ) : (
                <svg className="w-10 h-10 text-text-muted/30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" /></svg>
              )}
            </div>
            <div className="p-4">
              <div className="flex items-start justify-between gap-2">
                <h3 className="text-sm font-semibold text-text-primary leading-tight">{p.name}</h3>
                <span className="text-base font-bold text-brand-700">${Number(p.price).toFixed(2)}</span>
              </div>
              <div className="flex items-center justify-between mt-3">
                {p.category && (
                  <span className="bg-purple-50 text-purple-700 text-[11px] px-2 py-0.5 rounded-md font-medium">
                    {p.category}
                  </span>
                )}
                <span className={`text-[11px] font-medium ${p.stock > 10 ? 'text-success' : p.stock > 0 ? 'text-warning' : 'text-danger'}`}>
                  {p.stock > 0 ? `${p.stock} in stock` : 'Out of stock'}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
