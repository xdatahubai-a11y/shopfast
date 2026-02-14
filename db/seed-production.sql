-- Production seed data: REAL-WORLD — includes legacy data with nulls and edge cases
-- This is what breaks the "bad PR" — legacy orders have NULL status from a 2023 migration

INSERT INTO customers (email, name, tier) VALUES
('sarah@example.com', 'Sarah Chen', 'vip'),
('mike@example.com', 'Mike Torres', 'premium'),
('emma@example.com', 'Emma Davis', 'standard'),
('raj@example.com', 'Raj Patel', 'premium'),
('lisa@example.com', 'Lisa Anderson', NULL),        -- legacy: tier never set
('legacy-import@system', 'System Import', NULL);     -- legacy: batch import account

INSERT INTO products (sku, name, description, price, stock, category, image_url) VALUES
('LAPTOP-001', 'ProBook 15', '15-inch laptop, 16GB RAM, 512GB SSD', 999.99, 23, 'Electronics', '/images/laptop.jpg'),
('PHONE-001', 'SmartPhone X', '6.5-inch OLED, 128GB', 699.99, 87, 'Electronics', '/images/phone.jpg'),
('HEADSET-001', 'AudioPro Wireless', 'Noise-cancelling bluetooth headset', 149.99, 156, 'Audio', '/images/headset.jpg'),
('KEYBOARD-001', 'MechType Pro', 'Mechanical keyboard, Cherry MX Blue', 89.99, 42, 'Accessories', '/images/keyboard.jpg'),
('MOUSE-001', 'ErgoClick', 'Ergonomic wireless mouse', 49.99, 91, 'Accessories', '/images/mouse.jpg'),
('MONITOR-001', 'UltraView 27', '27-inch 4K IPS monitor', 449.99, 18, 'Electronics', '/images/monitor.jpg'),
('CABLE-001', 'USB-C Hub', '7-in-1 USB-C hub', 39.99, 234, 'Accessories', NULL),  -- legacy: no image
('STAND-001', 'AdjustDesk', 'Adjustable laptop stand', 59.99, 67, 'Accessories', NULL);

-- Recent orders — all clean
INSERT INTO orders (customer_id, status, total, shipping_address) VALUES
(1, 'delivered', 1449.98, '100 Market St, San Francisco, CA 94105'),
(2, 'shipped', 149.99, '200 Broadway, New York, NY 10012'),
(3, 'confirmed', 699.99, '300 Michigan Ave, Chicago, IL 60601'),
(4, 'pending', 539.97, '400 Elm St, Dallas, TX 75201'),
(1, 'delivered', 89.99, '100 Market St, San Francisco, CA 94105');

-- LEGACY ORDERS — migrated from old system in 2023
-- These have NULL status (old system used different status codes, migration set them to NULL)
INSERT INTO orders (customer_id, status, total, shipping_address, notes) VALUES
(5, NULL, 299.99, '500 Legacy Blvd, Austin, TX 73301', 'Migrated from legacy system 2023-06'),
(5, NULL, 149.99, NULL, 'Migrated from legacy system 2023-06'),
(6, NULL, 1299.97, '600 Import Ave, Miami, FL 33101', 'Bulk import 2023-Q2'),
(6, NULL, 89.99, NULL, 'Migrated from legacy system 2023-03'),
(6, NULL, 449.99, '600 Import Ave, Miami, FL 33101', 'Migrated - original status unknown');

-- Legacy order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total) VALUES
(1, 1, 1, 999.99, 999.99),
(1, 3, 3, 149.99, 449.97),
(2, 3, 1, 149.99, 149.99),
(3, 2, 1, 699.99, 699.99),
(4, 4, 1, 89.99, 89.99),
(4, 6, 1, 449.99, 449.99),
(5, 4, 1, 89.99, 89.99),
(6, 5, 6, 49.99, 299.94),
(7, 3, 1, 149.99, 149.99),
(8, 1, 1, 1299.97, 1299.97),
(9, 4, 1, 89.99, 89.99),
(10, 6, 1, 449.99, 449.99);
