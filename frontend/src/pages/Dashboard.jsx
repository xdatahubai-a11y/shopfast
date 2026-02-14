import useFetch from '../hooks/useFetch'
import StatusBadge from '../components/StatusBadge'
import Spinner from '../components/Spinner'

export default function Dashboard() {
  const { data: stats, loading: sl, error: se } = useFetch('/api/stats')
  const { data: ordersData, loading: ol, error: oe } = useFetch('/api/orders?limit=10')

  const error = se || oe

  if (sl || ol) return <Spinner />

  if (error) return (
    <div className="bg-danger/5 border border-danger/20 text-danger px-6 py-4 rounded-xl text-sm font-medium">
      Failed to load dashboard: {error}
    </div>
  )

  const orders = ordersData?.orders || ordersData || []

  const statCards = [
    { label: 'Total Orders', value: stats?.totalOrders ?? 0, icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" /></svg>
    ), color: 'text-brand-600 bg-brand-50', trend: '+12%' },
    { label: 'Revenue', value: `$${(stats?.totalRevenue ?? 0).toLocaleString()}`, icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
    ), color: 'text-success bg-green-50', trend: '+8%' },
    { label: 'Active Products', value: stats?.activeProducts ?? 0, icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" /></svg>
    ), color: 'text-purple-600 bg-purple-50', trend: '+3' },
    { label: 'Customers', value: stats?.totalCustomers ?? 0, icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" /></svg>
    ), color: 'text-amber-600 bg-amber-50', trend: '+5%' },
  ]

  // Build status counts
  const statusCounts = stats?.ordersByStatus || {}
  const maxCount = Math.max(...Object.values(statusCounts), 1)
  const barColors = {
    pending: 'bg-amber-500',
    confirmed: 'bg-brand-500',
    shipped: 'bg-purple-500',
    delivered: 'bg-green-500',
    cancelled: 'bg-red-500',
  }

  return (
    <div className="space-y-6">
      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {statCards.map(s => (
          <div key={s.label} className="bg-surface rounded-xl border border-border p-5 hover:shadow-sm transition-shadow">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs font-medium text-text-secondary uppercase tracking-wide">{s.label}</p>
                <p className="text-2xl font-bold text-text-primary mt-2">{s.value}</p>
                <p className="text-xs text-success font-medium mt-1">{s.trend} this month</p>
              </div>
              <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${s.color}`}>
                {s.icon}
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Orders by Status Chart */}
        {Object.keys(statusCounts).length > 0 && (
          <div className="bg-surface rounded-xl border border-border p-6">
            <h2 className="text-sm font-semibold text-text-primary mb-6">Orders by Status</h2>
            <div className="flex items-end gap-3 h-44">
              {Object.entries(statusCounts).map(([status, count]) => (
                <div key={status} className="flex-1 flex flex-col items-center gap-2">
                  <span className="text-xs font-semibold text-text-primary">{count}</span>
                  <div className="w-full flex justify-center">
                    <div
                      className={`w-10 rounded-t-md ${barColors[status] || 'bg-gray-300'} transition-all`}
                      style={{ height: `${(count / maxCount) * 130}px`, minHeight: '4px' }}
                    />
                  </div>
                  <span className="text-[10px] text-text-muted capitalize font-medium">{status}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Recent Orders */}
        <div className="bg-surface rounded-xl border border-border overflow-hidden lg:col-span-2">
          <div className="px-6 py-4 border-b border-border flex items-center justify-between">
            <h2 className="text-sm font-semibold text-text-primary">Recent Orders</h2>
            <span className="text-xs text-text-muted">{orders.length} orders</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-surface-secondary">
                  <th className="px-6 py-3 text-left text-[11px] font-semibold text-text-secondary uppercase tracking-wider">ID</th>
                  <th className="px-6 py-3 text-left text-[11px] font-semibold text-text-secondary uppercase tracking-wider">Customer</th>
                  <th className="px-6 py-3 text-left text-[11px] font-semibold text-text-secondary uppercase tracking-wider">Status</th>
                  <th className="px-6 py-3 text-right text-[11px] font-semibold text-text-secondary uppercase tracking-wider">Total</th>
                  <th className="px-6 py-3 text-right text-[11px] font-semibold text-text-secondary uppercase tracking-wider">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border-light">
                {orders.slice(0, 8).map(o => (
                  <tr key={o.id} className="hover:bg-surface-secondary/50 transition-colors">
                    <td className="px-6 py-3 text-sm font-mono text-text-secondary">#{o.id}</td>
                    <td className="px-6 py-3 text-sm text-text-primary font-medium">{o.customer_name}</td>
                    <td className="px-6 py-3"><StatusBadge status={o.status} /></td>
                    <td className="px-6 py-3 text-sm font-semibold text-text-primary text-right">${Number(o.total).toFixed(2)}</td>
                    <td className="px-6 py-3 text-sm text-text-secondary text-right">{new Date(o.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}
