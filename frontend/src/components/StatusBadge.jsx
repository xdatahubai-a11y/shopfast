const fallbackStyles = {
  pending:   'bg-amber-50 text-amber-700 border-amber-200',
  confirmed: 'bg-blue-50 text-blue-700 border-blue-200',
  shipped:   'bg-purple-50 text-purple-700 border-purple-200',
  delivered: 'bg-green-50 text-green-700 border-green-200',
  cancelled: 'bg-red-50 text-red-700 border-red-200',
}

const fallbackDots = {
  pending: 'bg-amber-500',
  confirmed: 'bg-blue-500',
  shipped: 'bg-purple-500',
  delivered: 'bg-green-500',
  cancelled: 'bg-red-500',
}

export default function StatusBadge({ status }) {
  // status can be a string or an object {color, label, icon}
  let label, key
  if (typeof status === 'object' && status !== null) {
    label = status.label || 'Unknown'
    key = label.toLowerCase()
  } else {
    label = status || 'Unknown'
    key = (status || '').toLowerCase()
  }

  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[11px] font-semibold border ${fallbackStyles[key] || 'bg-gray-50 text-gray-600 border-gray-200'}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${fallbackDots[key] || 'bg-gray-400'}`} />
      {label}
    </span>
  )
}
