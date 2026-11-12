-- 07 · Order structure
-- Purpose : compare single vs multi-item and single vs multi-seller orders.
-- Requires: order_structure_analysis from 03_reporting_views.sql.

-- 1. Single-item vs multi-item: overall
SELECT item_type, COUNT(*) AS total_orders, SUM(is_late) AS late_orders,
       ROUND(AVG(is_late) * 100, 2) AS late_delivery_rate
FROM public.order_structure_analysis GROUP BY item_type ORDER BY item_type;

-- 2. Single-item vs multi-item: monthly Jan–May 2018
SELECT order_month, item_type, COUNT(*) AS total_orders,
       SUM(is_late) AS late_orders, ROUND(AVG(is_late) * 100, 2) AS late_delivery_rate
FROM public.order_structure_analysis
WHERE order_month >= DATE '2018-01-01' AND order_month < DATE '2018-06-01'
GROUP BY order_month, item_type ORDER BY order_month, item_type;

-- 3. Single-seller vs multi-seller: delivery rate and durations
SELECT seller_type, COUNT(*) AS total_orders, SUM(is_late) AS late_orders,
       ROUND(AVG(is_late) * 100, 2) AS late_delivery_rate,
       ROUND(AVG(actual_delivery_days)::numeric, 2) AS avg_actual_delivery_days,
       ROUND(AVG(estimated_delivery_days)::numeric, 2) AS avg_estimated_delivery_days
FROM public.order_structure_analysis GROUP BY seller_type ORDER BY seller_type;
-- Seller count is COUNT(DISTINCT seller_id), which excludes NULL seller IDs.
-- A zero-seller order would fall in the ELSE ('Multi-seller') group; inspect if relevant.
