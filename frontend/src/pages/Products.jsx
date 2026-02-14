import useFetch from '../hooks/useFetch'
import Spinner from '../components/Spinner'

export default function Products() {
  const { data, loading, error } = useFetch('/api/products')

  if (loading) return <Spinner />
  if (error) return (
    <div className="bg-red-600 text-white px-4 py-3 rounded-lg text-center font-medium">
      ⚠️ Failed to load products: {error}
    </div>
  )

  const products = data?.products || data || []

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-bold text-gray-900">Products</h1>
        <p className="text-sm text-gray-500 mt-1">{products.length} active products</p>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {products.map(p => (
          <div key={p.id} className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-md transition-shadow">
            <div className="h-48 bg-gray-100 flex items-center justify-center">
              {p.image_url ? (
                <img src={p.image_url} alt={p.name} className="w-full h-full object-cover" />
              ) : (
                <span className="text-4xl text-gray-300">🏷️</span>
              )}
            </div>
            <div className="p-4">
              <div className="flex items-start justify-between gap-2">
                <h3 className="font-semibold text-gray-900 text-sm leading-tight">{p.name}</h3>
                <span className="text-lg font-bold text-blue-700">${Number(p.price).toFixed(2)}</span>
              </div>
              <div className="flex items-center justify-between mt-3">
                {p.category && (
                  <span className="bg-purple-100 text-purple-700 text-xs px-2 py-0.5 rounded-full font-medium">
                    {p.category}
                  </span>
                )}
                <span className={`text-xs font-medium ${p.stock > 10 ? 'text-green-600' : p.stock > 0 ? 'text-amber-600' : 'text-red-600'}`}>
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
