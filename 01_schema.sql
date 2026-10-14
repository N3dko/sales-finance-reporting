-- Project CV | PostgreSQL schema
-- Run in a new, empty database. The Calendar table is created in Power BI.

CREATE TABLE public.customers (
    customer_id integer PRIMARY KEY,
    customer_name varchar(100),
    country varchar(50),
    city varchar(50),
    age integer
);

CREATE TABLE public.products (
    product_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name varchar(100) NOT NULL,
    category varchar(50) NOT NULL,
    current_price numeric(10,2) NOT NULL CHECK (current_price >= 0)
);

CREATE TABLE public.orders (
    order_id integer PRIMARY KEY,
    customer_id integer REFERENCES public.customers(customer_id),
    amount numeric(10,2),
    order_date date,
    data_origin varchar(30) NOT NULL DEFAULT 'legacy_unitemized'
);

CREATE TABLE public.order_items (
    order_item_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id integer NOT NULL REFERENCES public.orders(order_id),
    product_id integer NOT NULL REFERENCES public.products(product_id),
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(10,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE public.payments (
    payment_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id integer NOT NULL REFERENCES public.orders(order_id),
    payment_date date NOT NULL,
    amount numeric(10,2) NOT NULL CHECK (amount > 0),
    payment_method varchar(30) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('completed', 'pending', 'failed', 'refunded'))
);

CREATE VIEW public.project_cv_order_summary AS
WITH item_totals AS (
    SELECT order_id, SUM(quantity * unit_price) AS items_total
    FROM public.order_items
    GROUP BY order_id
), payment_totals AS (
    SELECT order_id,
           COUNT(*) AS payment_count,
           SUM(amount) FILTER (WHERE status = 'completed') AS collected_total,
           SUM(amount) FILTER (WHERE status = 'pending') AS pending_total
    FROM public.payments
    GROUP BY order_id
)
SELECT o.order_id,
       o.order_date,
       o.data_origin,
       c.customer_id,
       c.customer_name,
       c.country,
       o.amount AS ordered_total,
       i.items_total,
       CASE WHEN p.payment_count IS NULL THEN NULL
            ELSE COALESCE(p.collected_total, 0) END AS collected_total,
       CASE WHEN p.payment_count IS NULL THEN NULL
            ELSE COALESCE(p.pending_total, 0) END AS pending_total,
       CASE WHEN i.items_total IS NULL THEN 'no_item_detail'
            WHEN i.items_total <> o.amount THEN 'item_mismatch'
            ELSE 'items_match' END AS item_check
FROM public.orders AS o
JOIN public.customers AS c ON c.customer_id = o.customer_id
LEFT JOIN item_totals AS i ON i.order_id = o.order_id
LEFT JOIN payment_totals AS p ON p.order_id = o.order_id;
