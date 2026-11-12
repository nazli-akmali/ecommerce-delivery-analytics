-- 02 · Initial data exploration and validation
-- Purpose : understand order statuses, missing timestamps and the grain of the
--           orders / order_items relationship before defining any KPI.
-- Requires: 01_create_tables.sql and the imported Olist CSVs.

-- 1. Source row counts
SELECT COUNT(*) AS total_orders FROM public.orders;
SELECT COUNT(*) AS total_order_items FROM public.order_items;

-- 2. Order status composition
SELECT order_status, COUNT(*) AS total_orders,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM public.orders GROUP BY order_status ORDER BY total_orders DESC;

-- 3. Missing delivery timestamps among delivered orders
SELECT COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_delivery_dates,
       ROUND(COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) * 100.0
             / NULLIF(COUNT(*), 0), 3) AS missing_percentage
FROM public.orders WHERE order_status = 'delivered';
SELECT COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS missing_carrier_dates,
       ROUND(COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) * 100.0
             / NULLIF(COUNT(*), 0), 2) AS missing_carrier_percentage
FROM public.orders WHERE order_status = 'delivered';

-- 4. Join coverage and grain: one order can have several items
SELECT COUNT(*) AS total_items, COUNT(DISTINCT order_id) AS unique_orders
FROM public.order_items;
SELECT order_id, COUNT(*) AS item_count FROM public.order_items
GROUP BY order_id ORDER BY item_count DESC LIMIT 10;
SELECT COUNT(*) AS orders_without_items
FROM public.orders o LEFT JOIN public.order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;
SELECT o.order_status, COUNT(*) AS orders_without_items
FROM public.orders o LEFT JOIN public.order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL GROUP BY o.order_status ORDER BY orders_without_items DESC;
SELECT COUNT(*) AS multi_item_orders FROM (
    SELECT order_id FROM public.order_items GROUP BY order_id HAVING COUNT(*) > 1
) x;
-- Joining items to orders inflates row counts; counting joined rows as orders would be wrong.
SELECT COUNT(*) AS joined_delivered_rows, COUNT(DISTINCT o.order_id) AS distinct_delivered_orders
FROM public.orders o JOIN public.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- 5. Verify that aggregating items per order first prevents join duplication
--    (joined_rows should equal distinct_orders)
WITH order_item_summary AS (
    SELECT order_id, COUNT(*) AS item_count FROM public.order_items GROUP BY order_id
)
SELECT COUNT(*) AS joined_rows, COUNT(DISTINCT o.order_id) AS distinct_orders
FROM public.orders o JOIN order_item_summary s ON o.order_id = s.order_id
WHERE o.order_status = 'delivered';

-- 6. Seller count per order
WITH seller_summary AS (
    SELECT order_id, COUNT(*) AS item_count, COUNT(DISTINCT seller_id) AS seller_count
    FROM public.order_items GROUP BY order_id
)
SELECT seller_count, COUNT(*) AS total_orders, ROUND(AVG(item_count), 2) AS avg_item_count
FROM seller_summary GROUP BY seller_count ORDER BY seller_count;
