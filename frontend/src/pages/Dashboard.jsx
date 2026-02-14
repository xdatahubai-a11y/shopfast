import useFetch from '../hooks/useFetch'
import StatusBadge from '../components/StatusBadge'
import Spinner from '../components/Spinner'

const statIcons = ['📦', '💰', '🏷️', '👥']

export default function Dashboard() {
  const { data: stats, loading: sl, error: se } = useFetch('/api/stats')
  const { data: ordersData, loading: ol, error: oe } = useFetch('/api/orders?limit=10')

  const error = se || oe

  if (sl || ol) return <Spinner />

  if (error) return (
    <div className="bg-red-600 text-white px-4 py-3 rounded-lg text-center font-medium">
      ⚠️ Failed to load dashboard: {error}
    </div>
  )

  const orders = ordersData?.orders || ordersData || []

  const statCards = [
    { label: 'Total Orders', value: stats?.totalOrders ?? 0, icon: '📦', color: 'from-blue-500 to-blue-600' },
    { label: 'Revenue', value: `$${(stats?.totalRevenue ?? 0).toLocaleString()}`, icon: '💰', color: 'from-green-500 to-green-600' },
    { label: 'Active Products', value: stats?.activeProducts ?? 0, icon: '🏷️', color: 'from-purple-500 to-purple-600' },
    { label: 'Customers', value: stats?.totalCustomers ?? 0, icon: '👥', color: 'from-amber-500 to-amber-600' },
  ]

  // Build status counts for chart
  const statusCounts = {}
  const allOrders = orders
  if (stats?.ordersByStatus) {
    Object.assign(statusCounts, stats.ordersByStatus)
  }
  const maxCount = Math.max(...Object.values(statusCounts), 1)

  const barColors = {
    pending: 'bg-amber-500',
    confirmed: 'bg-blue-500',
    shipped: 'bg-purple-500',
    delivered: 'bg-green-500',
    cancelled: 'bg-red-500',
  }

  return (
    <div className="space-y-8">
      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map(s => (
          <div key={s.label} className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500 font-medium">{s.label}</p>
                <p className="text-2xl font-bold text-gray-900 mt-1">{s.value}</p>
              </div>
              <div className={`w-12 h-12 rounded-lg bg-gradient-to-br ${s.color} flex items-center justify-center text-xl text-white`}>
                {s.icon}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Orders by Status Chart */}
      {Object.keys(statusCounts).length > 0 && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Orders by Status</h2>
          <div className="flex items-end gap-4 h-48">
            {Object.entries(statusCounts).map(([status, count]) => (
              <div key={status} className="flex-1 flex flex-col items-center gap-2">
                <span className="text-sm font-semibold text-gray-700">{count}</span>
                <div className="w-full flex justify-center">
                  <div
                    className={`w-12 rounded-t-lg ${barColors[status] || 'bg-gray-400'} transition-all`}
                    style={{ height: `${(count / maxCount) * 160}px`, minHeight: '8px' }}
                  />
                </div>
                <span className="text-xs text-gray-500 capitalize">{status}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Recent Orders */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-100">
          <h2 className="text-lg font-semibold text-gray-900">Recent Orders</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Customer</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {orders.slice(0, 10).map(o => (
                <tr key={o.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 text-sm font-mono text-gray-600">#{o.id}</td>
                  <td className="px-6 py-4 text-sm text-gray-900 font-medium">{o.customer_name}</td>
                  <td className="px-6 py-4"><StatusBadge status={o.status} /></td>
                  <td className="px-6 py-4 text-sm font-semibold text-gray-900">${Number(o.total).toFixed(2)}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">{new Date(o.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
