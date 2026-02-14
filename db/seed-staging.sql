-- Staging seed data: CLEAN — all fields populated, no edge cases

INSERT INTO customers (email, name, tier) VALUES
('alice@test.com', 'Alice Johnson', 'premium'),
('bob@test.com', 'Bob Smith', 'standard'),
('carol@test.com', 'Carol Williams', 'vip');

INSERT INTO products (sku, name, description, price, stock, category, image_url) VALUES
('LAPTOP-001', 'ProBook 15', '15-inch laptop, 16GB RAM, 512GB SSD', 999.99, 50, 'Electronics', '/images/laptop.jpg'),
('PHONE-001', 'SmartPhone X', '6.5-inch OLED, 128GB', 699.99, 120, 'Electronics', '/images/phone.jpg'),
('HEADSET-001', 'AudioPro Wireless', 'Noise-cancelling bluetooth headset', 149.99, 200, 'Audio', '/images/headset.jpg'),
('KEYBOARD-001', 'MechType Pro', 'Mechanical keyboard, Cherry MX Blue', 89.99, 75, 'Accessories', '/images/keyboard.jpg'),
('MOUSE-001', 'ErgoClick', 'Ergonomic wireless mouse', 49.99, 150, 'Accessories', '/images/mouse.jpg');

INSERT INTO orders (customer_id, status, total, shipping_address) VALUES
(1, 'delivered', 999.99, '123 Main St, Seattle, WA 98101'),
(2, 'shipped', 149.99, '456 Oak Ave, Portland, OR 97201'),
(3, 'confirmed', 789.98, '789 Pine Rd, San Francisco, CA 94102'),
(1, 'pending', 49.99, '123 Main St, Seattle, WA 98101');

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total) VALUES
(1, 1, 1, 999.99, 999.99),
(2, 3, 1, 149.99, 149.99),
(3, 2, 1, 699.99, 699.99),
(3, 5, 1, 89.99, 89.99),
(4, 5, 1, 49.99, 49.99);
