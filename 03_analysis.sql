-- Project CV | PostgreSQL portfolio queries
-- The public demo contains only data_origin = 'demo_generated'.

-- 1. Product revenue and units sold, ranked by revenue.
SELECT p.product_name,
       p.category,
       SUM(oi.quantity) AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS product_revenue
FROM public.order_items AS oi
JOIN public.products AS p ON p.product_id = oi.product_id
JOIN public.orders AS o ON o.order_id = oi.order_id
WHERE o.data_origin = 'demo_generated'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY product_revenue DESC;

-- 2. Reconciliation: ordered, item, collected and pending totals by order.
-- Each order is aggregated in the view before the totals are compared.
SELECT order_id, order_date, customer_name,
       ordered_total, items_total, collected_total, pending_total,
       item_check,
       ordered_total - COALESCE(collected_total, 0)
                     - COALESCE(pending_total, 0) AS payment_difference
FROM public.project_cv_order_summary
WHERE data_origin = 'demo_generated'
ORDER BY order_id;

-- 3. Daily revenue and running total (window function).
WITH daily_sales AS (
    SELECT order_date, SUM(amount) AS ordered_amount
    FROM public.orders
    WHERE data_origin = 'demo_generated'
    GROUP BY order_date
)
SELECT order_date,
       ordered_amount,
       SUM(ordered_amount) OVER (ORDER BY order_date) AS cumulative_ordered
FROM daily_sales
ORDER BY order_date;

-- 4. Data quality summary. Expected: 31 / 0 / 0 / 4019.30 / 3704.90 / 314.40.
SELECT COUNT(*) AS demo_orders,
       COUNT(*) FILTER (WHERE item_check <> 'items_match') AS item_mismatches,
       COUNT(*) FILTER (
           WHERE ordered_total <> COALESCE(collected_total, 0)
                                + COALESCE(pending_total, 0)
       ) AS payment_mismatches,
       SUM(ordered_total) AS ordered_total,
       SUM(collected_total) AS collected_total,
       SUM(pending_total) AS pending_total
FROM public.project_cv_order_summary
WHERE data_origin = 'demo_generated';
