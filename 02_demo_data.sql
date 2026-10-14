-- Project CV | reproducible synthetic demo data
-- Run after 01_schema.sql in a NEW, EMPTY database.
-- The production/practice database's 1,506 legacy rows are intentionally excluded.
-- This recreates the verified demo totals and revenue by customer.
-- Payment method for generated orders is illustrative.

INSERT INTO public.customers (customer_id, customer_name)
VALUES (1, 'Anna'), (2, 'George'), (3, 'Maria'),
       (4, 'Robert'), (5, 'Gabriel');

INSERT INTO public.products (product_name, category, current_price)
VALUES ('Wireless Mouse', 'Accessories', 24.90),
       ('Mechanical Keyboard', 'Accessories', 89.00),
       ('USB-C Hub', 'Accessories', 39.50),
       ('27-inch Monitor', 'Displays', 249.00),
       ('Webcam', 'Video', 69.00),
       ('Headset', 'Audio', 79.90);

-- The first demo order has two items and a completed card payment.
INSERT INTO public.orders (order_id, customer_id, amount, order_date, data_origin)
VALUES (1507, 1, 113.90, DATE '2026-10-01', 'demo_generated');

-- Thirty further orders, one per day: one mouse plus a rotating second product.
INSERT INTO public.orders (order_id, customer_id, amount, order_date, data_origin)
SELECT 1508 + day_no,
       1 + (day_no % 5),
       (24.90 + p.current_price)::numeric(10,2),
       DATE '2026-10-01' + day_no,
       'demo_generated'
FROM generate_series(0, 29) AS g(day_no)
JOIN public.products AS p ON p.product_id = 2 + (day_no % 5);

INSERT INTO public.order_items (order_id, product_id, quantity, unit_price)
VALUES (1507, 1, 1, 24.90), (1507, 2, 1, 89.00);

INSERT INTO public.order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, 1, p.current_price
FROM public.orders AS o
JOIN public.products AS p ON p.product_id = 1
WHERE o.order_id BETWEEN 1508 AND 1537;

INSERT INTO public.order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, 1, p.current_price
FROM public.orders AS o
JOIN public.products AS p ON p.product_id = 2 + ((o.order_id - 1508) % 5)
WHERE o.order_id BETWEEN 1508 AND 1537;

INSERT INTO public.payments (order_id, payment_date, amount, payment_method, status)
VALUES (1507, DATE '2026-10-01', 113.90, 'card', 'completed');

INSERT INTO public.payments (order_id, payment_date, amount, payment_method, status)
SELECT o.order_id, o.order_date, o.amount, 'card',
       CASE WHEN o.order_id IN (1517, 1527, 1537)
            THEN 'pending' ELSE 'completed' END
FROM public.orders AS o
WHERE o.order_id BETWEEN 1508 AND 1537;

-- Expected: 31 | 4019.30 | 3704.90 | 314.40 | 0
SELECT COUNT(*) AS demo_orders,
       SUM(ordered_total) AS ordered,
       SUM(collected_total) AS collected,
       SUM(pending_total) AS pending,
       COUNT(*) FILTER (WHERE item_check <> 'items_match') AS item_mismatches
FROM public.project_cv_order_summary
WHERE data_origin = 'demo_generated';
