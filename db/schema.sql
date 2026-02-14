-- ShopFast E-Commerce Database Schema

CREATE TABLE customers (
    id INT IDENTITY(1,1) PRIMARY KEY,
    email NVARCHAR(255) NOT NULL UNIQUE,
    name NVARCHAR(255) NOT NULL,
    tier NVARCHAR(50) DEFAULT 'standard',  -- 'standard', 'premium', 'vip'
    created_at DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE products (
    id INT IDENTITY(1,1) PRIMARY KEY,
    sku NVARCHAR(50) NOT NULL UNIQUE,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    price DECIMAL(10,2) NOT NULL,
    stock INT DEFAULT 0,
    category NVARCHAR(100),
    image_url NVARCHAR(500),
    active BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE orders (
    id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    status NVARCHAR(50) NOT NULL DEFAULT 'pending',  -- pending, confirmed, shipped, delivered, cancelled
    total DECIMAL(10,2) NOT NULL,
    shipping_address NVARCHAR(500),
    notes NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE order_items (
    id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at);
CREATE INDEX idx_order_items_order ON order_items(order_id);
