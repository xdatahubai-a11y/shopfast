// ShopFast API — v1.1.0 (PR #2: "Improve order listing with status filtering")
// 
// Changes in this version:
//   - Added status filter to /api/orders endpoint
//   - Added status badge formatting (uppercase first letter)
//   - Added order count by status to /api/stats
//   - Performance: only fetch active orders by default
//
const appInsights = require('applicationinsights');
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .setAutoCollectRequests(true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectPerformance(true)
    .start();
}
const client = appInsights.defaultClient;

const express = require('express');
const cors = require('cors');
const sql = require('mssql');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const dbConfig = {
  server: process.env.SQL_SERVER,
  database: process.env.SQL_DATABASE || 'shopfast',
  user: process.env.SQL_USER,
  password: process.env.SQL_PASSWORD,
  options: { encrypt: true, trustServerCertificate: false },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 }
};

let pool = null;
async function getPool() {
  if (!pool) pool = await sql.connect(dbConfig);
  return pool;
}

// ─── Helper: format status badge ───────────────────
// NEW in v1.1.0: Pretty-print order status for the UI
function formatStatus(status) {
  // Capitalize first letter, lowercase rest
  return status.charAt(0).toUpperCase() + status.slice(1).toLowerCase();
  // BUG: No null check! Legacy orders have status = NULL
  // This will throw: "TypeError: Cannot read properties of null (reading 'charAt')"
}

// ─── Helper: status color for UI ───────────────────
function getStatusColor(status) {
  const colors = {
    'Pending': '#f59e0b',
    'Confirmed': '#3b82f6',
    'Shipped': '#8b5cf6',
    'Delivered': '#10b981',
    'Cancelled': '#ef4444'
  };
  return colors[formatStatus(status)] || '#6b7280';
}

// ─── Health ────────────────────────────────────────
app.get('/api/health', async (_req, res) => {
  try {
    const p = await getPool();
    await p.request().query('SELECT 1');
    res.json({ status: 'healthy', version: process.env.APP_VERSION || '1.1.0', timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', error: err.message });
  }
});

// ─── Products ──────────────────────────────────────
app.get('/api/products', async (_req, res) => {
  try {
    const p = await getPool();
    const result = await p.request().query('SELECT * FROM products WHERE active = 1 ORDER BY name');
    res.json({ products: result.recordset });
  } catch (err) {
    client?.trackException({ exception: err });
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

app.get('/api/products/:id', async (req, res) => {
  try {
    const p = await getPool();
    const result = await p.request()
      .input('id', sql.Int, req.params.id)
      .query('SELECT * FROM products WHERE id = @id');
    if (!result.recordset.length) return res.status(404).json({ error: 'Product not found' });
    res.json(result.recordset[0]);
  } catch (err) {
    client?.trackException({ exception: err });
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

// ─── Orders (CHANGED in v1.1.0) ───────────────────
app.get('/api/orders', async (req, res) => {
  try {
    const p = await getPool();
    const statusFilter = req.query.status;

    // v1.1.0: Added status filtering and improved response format
    let query = `
      SELECT o.*, c.name as customer_name, c.email as customer_email
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
    `;
    const request = p.request();
    if (statusFilter) {
      query += ' WHERE o.status = @status';
      request.input('status', sql.NVarChar, statusFilter);
    }
    query += ' ORDER BY o.created_at DESC';

    const result = await request.query(query);

    // v1.1.0: Format status for UI display
    const orders = result.recordset.map(row => ({
      id: row.id,
      customer: row.customer_name || 'Unknown',
      email: row.customer_email || '',
      status: formatStatus(row.status),          // ← BUG: crashes on NULL status
      statusColor: getStatusColor(row.status),   // ← BUG: also crashes
      total: row.total,
      address: row.shipping_address || '',
      notes: row.notes || '',
      created: row.created_at,
      updated: row.updated_at
    }));

    res.json({ orders, count: orders.length });
  } catch (err) {
    client?.trackException({ exception: err, properties: {
      endpoint: '/api/orders',
      statusFilter: req.query.status || 'none',
      version: '1.1.0'
    }});
    console.error('GET /api/orders error:', err.message);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

app.get('/api/orders/:id', async (req, res) => {
  try {
    const p = await getPool();
    const result = await p.request()
      .input('id', sql.Int, req.params.id)
      .query(`
        SELECT o.*, c.name as customer_name, c.email as customer_email
        FROM orders o
        LEFT JOIN customers c ON o.customer_id = c.id
        WHERE o.id = @id
      `);
    if (!result.recordset.length) return res.status(404).json({ error: 'Order not found' });

    const row = result.recordset[0];
    const items = await p.request()
      .input('orderId', sql.Int, req.params.id)
      .query(`
        SELECT oi.*, p.name as product_name, p.sku
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = @orderId
      `);

    res.json({
      ...row,
      status: formatStatus(row.status),           // ← BUG: crashes on NULL
      statusColor: getStatusColor(row.status),     // ← BUG: crashes on NULL
      customer_name: row.customer_name || 'Unknown',
      items: items.recordset
    });
  } catch (err) {
    client?.trackException({ exception: err });
    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

// ─── Dashboard Stats (CHANGED in v1.1.0) ──────────
app.get('/api/stats', async (_req, res) => {
  try {
    const p = await getPool();
    const [orders, revenue, products, customers, byStatus] = await Promise.all([
      p.request().query('SELECT COUNT(*) as count FROM orders'),
      p.request().query('SELECT ISNULL(SUM(total), 0) as total FROM orders'),
      p.request().query('SELECT COUNT(*) as count FROM products WHERE active = 1'),
      p.request().query('SELECT COUNT(*) as count FROM customers'),
      // v1.1.0: Added order breakdown by status
      p.request().query('SELECT status, COUNT(*) as count FROM orders GROUP BY status'),
    ]);

    // v1.1.0: Format status breakdown for UI
    const statusBreakdown = byStatus.recordset.map(row => ({
      status: formatStatus(row.status),    // ← BUG: crashes on NULL status group
      count: row.count,
      color: getStatusColor(row.status)
    }));

    res.json({
      orders: orders.recordset[0].count,
      revenue: revenue.recordset[0].total,
      products: products.recordset[0].count,
      customers: customers.recordset[0].count,
      byStatus: statusBreakdown
    });
  } catch (err) {
    client?.trackException({ exception: err });
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// ─── SPA fallback ──────────────────────────────────
app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ─── Error handler ─────────────────────────────────
app.use((err, _req, res, _next) => {
  client?.trackException({ exception: err });
  console.error('Unhandled:', err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`ShopFast API running on port ${PORT} (v${process.env.APP_VERSION || '1.1.0'})`));
