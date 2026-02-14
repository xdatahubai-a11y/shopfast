import { useState, Fragment } from 'react'
import useFetch from '../hooks/useFetch'
import StatusBadge from '../components/StatusBadge'
import Spinner from '../components/Spinner'

export default function Orders() {
  const { data: rawData, loading, error } = useFetch('/api/orders')
  const [expanded, setExpanded] = useState(null)

  if (loading) return <Spinner />
  if (error) return (
    <div className="bg-danger/5 border border-danger/20 text-danger px-6 py-4 rounded-xl text-sm font-medium">
      Failed to load orders: {error}
    </div>
  )

  const orders = Array.isArray(rawData) ? rawData : (rawData?.orders || [])

  return (
    <div className="bg-surface rounded-xl border border-border overflow-hidden">
      <div className="px-6 py-4 border-b border-border flex items-center justify-between">
        <div>
          <h1 className="text-base font-semibold text-text-primary">Orders</h1>
          <p className="text-xs text-text-muted mt-0.5">{orders.length} total orders</p>
        </div>
        <input
          type="text"
          placeholder="Search orders..."
          className="text-sm px-3 py-1.5 border border-border rounded-lg bg-surface-secondary text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-brand-500/20 focus:border-brand-500 w-56"
        />
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
            {orders.map(o => (
              <Fragment key={o.id}>
                <tr
                  onClick={() => setExpanded(expanded === o.id ? null : o.id)}
                  className="hover:bg-surface-secondary/50 cursor-pointer transition-colors"
                >
                  <td className="px-6 py-3.5 text-sm font-mono text-text-secondary">#{o.id}</td>
                  <td className="px-6 py-3.5 text-sm text-text-primary font-medium">{o.customerName || o.customer_name}</td>
                  <td className="px-6 py-3.5"><StatusBadge status={o.status} /></td>
                  <td className="px-6 py-3.5 text-sm font-semibold text-text-primary text-right">${Number(o.total).toFixed(2)}</td>
                  <td className="px-6 py-3.5 text-sm text-text-secondary text-right">{new Date(o.createdAt || o.created_at).toLocaleDateString()}</td>
                </tr>
                {expanded === o.id && (
                  <tr>
                    <td colSpan={5} className="px-6 py-4 bg-surface-secondary border-t border-border-light">
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <span className="text-[11px] text-text-muted uppercase tracking-wide font-medium">Email</span>
                          <p className="text-text-primary mt-0.5">{o.customerEmail || o.customer_email || '—'}</p>
                        </div>
                        <div>
                          <span className="text-[11px] text-text-muted uppercase tracking-wide font-medium">Items</span>
                          <p className="text-text-primary mt-0.5">{o.items?.length || o.item_count || '—'}</p>
                        </div>
                        <div>
                          <span className="text-[11px] text-text-muted uppercase tracking-wide font-medium">Order ID</span>
                          <p className="font-mono text-text-primary mt-0.5">#{o.id}</p>
                        </div>
                        <div>
                          <span className="text-[11px] text-text-muted uppercase tracking-wide font-medium">Created</span>
                          <p className="text-text-primary mt-0.5">{new Date(o.createdAt || o.created_at).toLocaleString()}</p>
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
