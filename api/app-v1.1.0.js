// ShopFast API v1.1.0
// E-commerce backend service
// PR #42: Show all orders for status dashboard + status badges

const appInsights = require('applicationinsights');
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  appInsights.setup().setAutoCollectRequests(true)
    .setAutoCollectPerformance(true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .start();
}

const express = require('express');
const cors = require('cors');
const sql = require('mssql');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || '1.1.0';

app.use(cors());
app.use(express.json());

// Database configuration
const dbConfig = {
  user: process.env.DB_USER || 'sa',
  password: process.env.DB_PASSWORD || '',
  server: process.env.DB_SERVER || 'localhost',
  database: process.env.DB_NAME || 'shopfast',
  options: {
    encrypt: true,
    trustServerCertificate: process.env.DB_TRUST_CERT === 'true',
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

let pool;

async function getPool() {
  if (!pool) {
    pool = await sql.connect(dbConfig);
  }
  return pool;
}

// ─── Status formatting (PR #42) ───────────────────────────────────────────────

const STATUS_BADGES = {
  pending:   { color: '#f59e0b', label: 'Pending',   icon: '⏳' },
  confirmed: { color: '#3b82f6', label: 'Confirmed', icon: '✓' },
  shipped:   { color: '#8b5cf6', label: 'Shipped',   icon: '📦' },
  delivered: { color: '#10b981', label: 'Delivered',  icon: '✅' },
  cancelled: { color: '#ef4444', label: 'Cancelled',  icon: '✗' },
};

function formatStatus(status) {
  const key = status.toLowerCase();  // crashes when status is null from legacy rows
  return STATUS_BADGES[key] || { color: '#6b7280', label: status, icon: '?' };
}

// ─── Health ────────────────────────────────────────────────────────────────────

app.get('/api/health', async (req, res) => {
  try {
    const p = await getPool();
    await p.request().query('SELECT 1');
    res.json({ status: 'healthy', version: VERSION, timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', error: err.message, version: VERSION });
  }
});

// ─── Products ──────────────────────────────────────────────────────────────────

app.get('/api/products', async (req, res) => {
  try {
    const p = await getPool();
    const result = await p.request().query(`
      SELECT id, name, description, price, category, image_url, stock_quantity
      FROM products
      ORDER BY name
    `);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching products:', err);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

app.get('/api/products/:id', async (req, res) => {
  try {
    const p = await getPool();
    const result = await p.request()
      .input('id', sql.Int, req.params.id)
      .query('SELECT id, name, description, price, category, image_url, stock_quantity FROM products WHERE id = @id');
    if (result.recordset.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json(result.recordset[0]);
  } catch (err) {
    console.error('Error fetching product:', err);
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

// ─── Orders ────────────────────────────────────────────────────────────────────

app.get('/api/orders', async (req, res) => {
  try {
    const p = await getPool();
    const request = p.request();

    // Build query with optional status filter
    let query = `
      SELECT o.id, o.customer_id, o.status, o.total_amount, o.created_at, o.updated_at,
             c.name AS customer_name, c.email AS customer_email
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id`;

    // v1.1.0: Show all orders including legacy for complete dashboard
    if (req.query.status) {
      query += ` WHERE o.status = @status`;
      request.input('status', sql.NVarChar, req.query.status);
    }

    query += ` ORDER BY o.created_at DESC`;

    const result = await request.query(query);

    const orders = result.recordset.map(row => ({
      id: row.id,
      customerId: row.customer_id,
      customerName: row.customer_name,
      customerEmail: row.customer_email,
      status: formatStatus(row.status),
      totalAmount: row.total_amount,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

    res.json(orders);
  } catch (err) {
    console.error('Error fetching orders:', err);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

app.get('/api/orders/:id', async (req, res) => {
  try {
    const p = await getPool();
    const result = await p.request()
      .input('id', sql.Int, req.params.id)
      .query(`
        SELECT o.id, o.customer_id, o.status, o.total_amount, o.created_at, o.updated_at,
               c.name AS customer_name, c.email AS customer_email
        FROM orders o
        LEFT JOIN customers c ON o.customer_id = c.id
        WHERE o.id = @id
      `);
    if (result.recordset.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    const row = result.recordset[0];
    res.json({
      id: row.id,
      customerId: row.customer_id,
      customerName: row.customer_name,
      customerEmail: row.customer_email,
      status: formatStatus(row.status),
      totalAmount: row.total_amount,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Error fetching order:', err);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

// ─── Stats ─────────────────────────────────────────────────────────────────────

app.get('/api/stats', async (req, res) => {
  try {
    const p = await getPool();
    const [orderStats, productStats, statusBreakdown] = await Promise.all([
      p.request().query(`
        SELECT COUNT(*) AS totalOrders,
               SUM(total_amount) AS totalRevenue,
               AVG(total_amount) AS avgOrderValue
        FROM orders
      `),
      p.request().query('SELECT COUNT(*) AS totalProducts FROM products'),
      // v1.1.0: Status breakdown for dashboard
      p.request().query(`
        SELECT status, COUNT(*) AS count, SUM(total_amount) AS revenue
        FROM orders
        GROUP BY status
      `),
    ]);

    const stats = orderStats.recordset[0];
    const byStatus = {};
    statusBreakdown.recordset.forEach(row => {
      const badge = formatStatus(row.status);  // crashes on NULL status group
      byStatus[badge.label] = {
        count: row.count,
        revenue: row.revenue || 0,
        badge: badge,
      };
    });

    res.json({
      totalOrders: stats.totalOrders,
      totalRevenue: stats.totalRevenue || 0,
      avgOrderValue: stats.avgOrderValue || 0,
      totalProducts: productStats.recordset[0].totalProducts,
      byStatus: byStatus,
      version: VERSION,
    });
  } catch (err) {
    console.error('Error fetching stats:', err);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// ─── Static files & SPA fallback ───────────────────────────────────────────────

app.use(express.static(path.join(__dirname, 'public')));

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ─── Start ─────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`ShopFast API v${VERSION} listening on port ${PORT}`);
});
