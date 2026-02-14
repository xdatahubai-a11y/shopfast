import { useState } from 'react'
import useFetch from '../hooks/useFetch'
import StatusBadge from '../components/StatusBadge'
import Spinner from '../components/Spinner'

export default function Orders() {
  const { data, loading, error } = useFetch('/api/orders')
  const [expanded, setExpanded] = useState(null)

  if (loading) return <Spinner />
  if (error) return (
    <div className="bg-red-600 text-white px-4 py-3 rounded-lg text-center font-medium">
      ⚠️ Failed to load orders: {error}
    </div>
  )

  const orders = data?.orders || data || []

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-100">
        <h1 className="text-xl font-bold text-gray-900">Orders</h1>
        <p className="text-sm text-gray-500 mt-1">{orders.length} total orders</p>
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
            {orders.map(o => (
              <>
                <tr
                  key={o.id}
                  onClick={() => setExpanded(expanded === o.id ? null : o.id)}
                  className="hover:bg-gray-50 cursor-pointer transition-colors"
                >
                  <td className="px-6 py-4 text-sm font-mono text-gray-600">#{o.id}</td>
                  <td className="px-6 py-4 text-sm text-gray-900 font-medium">{o.customer_name}</td>
                  <td className="px-6 py-4"><StatusBadge status={o.status} /></td>
                  <td className="px-6 py-4 text-sm font-semibold text-gray-900">${Number(o.total).toFixed(2)}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">{new Date(o.created_at).toLocaleDateString()}</td>
                </tr>
                {expanded === o.id && (
                  <tr key={`${o.id}-detail`}>
                    <td colSpan={5} className="px-6 py-4 bg-gray-50">
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <span className="text-gray-500">Email:</span>
                          <p className="font-medium">{o.customer_email || '—'}</p>
                        </div>
                        <div>
                          <span className="text-gray-500">Items:</span>
                          <p className="font-medium">{o.items?.length || o.item_count || '—'}</p>
                        </div>
                        <div>
                          <span className="text-gray-500">Order ID:</span>
                          <p className="font-mono font-medium">#{o.id}</p>
                        </div>
                        <div>
                          <span className="text-gray-500">Created:</span>
                          <p className="font-medium">{new Date(o.created_at).toLocaleString()}</p>
                        </div>
                      </div>
                      {o.items && o.items.length > 0 && (
                        <div className="mt-3 border-t pt-3">
                          <p className="text-xs text-gray-500 uppercase font-medium mb-2">Items</p>
                          {o.items.map((item, i) => (
                            <div key={i} className="flex justify-between text-sm py-1">
                              <span>{item.product_name || item.name} × {item.quantity}</span>
                              <span className="font-medium">${Number(item.price * item.quantity).toFixed(2)}</span>
                            </div>
                          ))}
                        </div>
                      )}
                    </td>
                  </tr>
                )}
              </>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
