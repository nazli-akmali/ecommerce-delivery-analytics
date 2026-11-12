-- 03 · Reporting views
-- Purpose : reusable views for analysis and for the Tableau data sources.
-- Requires: 01_create_tables.sql and the imported Olist CSVs.
-- Run this before scripts 05, 06 and 07, which query these views.
--
-- General analytical views (full history, no date filter):
--   monthly_delivery_performance  one row per purchase month
--   order_structure_analysis      one row per delivered order
--   shipping_risk_analysis        one row per eligible single-item delivered order
--   seller_performance_analysis   one row per seller (eligible single-item orders)
-- Dashboard-specific view (purchases Jan 2017 - Aug 2018):
--   seller_performance_dashboard  one row per seller

-- ===================== General analytical views =====================

CREATE OR REPLACE VIEW public.monthly_delivery_performance AS
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS order_month,
       COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date) AS late_orders,
       ROUND(COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS late_delivery_rate,
       ROUND((AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400))::numeric, 2) AS avg_actual_delivery_days,
       ROUND((AVG(EXTRACT(EPOCH FROM (order_estimated_delivery_date - order_purchase_timestamp)) / 86400))::numeric, 2) AS avg_estimated_delivery_days
FROM public.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY 1;

CREATE OR REPLACE VIEW public.order_structure_analysis AS
WITH order_summary AS (
    SELECT order_id, COUNT(*) AS item_count, COUNT(DISTINCT seller_id) AS seller_count
    FROM public.order_items GROUP BY order_id
)
SELECT o.order_id, DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
       s.item_count, s.seller_count,
       CASE WHEN s.item_count = 1 THEN 'Single-item' ELSE 'Multi-item' END AS item_type,
       CASE WHEN s.seller_count = 1 THEN 'Single-seller' ELSE 'Multi-seller' END AS seller_type,
       EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400 AS actual_delivery_days,
       EXTRACT(EPOCH FROM (o.order_estimated_delivery_date - o.order_purchase_timestamp)) / 86400 AS estimated_delivery_days,
       CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
            THEN 1 ELSE 0 END AS is_late
FROM public.orders o JOIN order_summary s ON o.order_id = s.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;

CREATE OR REPLACE VIEW public.shipping_risk_analysis AS
WITH single_item_orders AS (
    SELECT order_id FROM public.order_items GROUP BY order_id HAVING COUNT(*) = 1
), shipping_data AS (
    SELECT o.order_id, oi.seller_id,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
           EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - oi.shipping_limit_date)) / 86400 AS days_after_limit,
           CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                THEN 1 ELSE 0 END AS is_late
    FROM public.orders o JOIN public.order_items oi ON o.order_id = oi.order_id
    JOIN single_item_orders s ON o.order_id = s.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_carrier_date IS NOT NULL
      AND oi.shipping_limit_date IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
-- Groups use the numeric days_after_limit, not label text. The "1." to "4." prefixes
-- keep the groups in severity order when sorted alphabetically.
SELECT order_id, seller_id, order_month, days_after_limit, is_late,
       CASE WHEN days_after_limit <= 0 THEN '1. Within limit'
            WHEN days_after_limit <= 1 THEN '2. Up to 1 day late'
            WHEN days_after_limit <= 3 THEN '3. 1-3 days late'
            ELSE '4. More than 3 days late' END AS shipping_delay_group
FROM shipping_data;

CREATE OR REPLACE VIEW public.seller_performance_analysis AS
WITH single_item_orders AS (
    SELECT order_id FROM public.order_items GROUP BY order_id HAVING COUNT(*) = 1
)
SELECT oi.seller_id, COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE o.order_delivered_carrier_date > oi.shipping_limit_date) AS after_limit_orders,
       ROUND(COUNT(*) FILTER (WHERE o.order_delivered_carrier_date > oi.shipping_limit_date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS after_limit_rate
FROM public.orders o JOIN public.order_items oi ON o.order_id = oi.order_id
JOIN single_item_orders s ON o.order_id = s.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND oi.shipping_limit_date IS NOT NULL
GROUP BY oi.seller_id;

-- ===================== Dashboard-specific view =====================
-- Same eligible order grain and shipping-delay definition as seller_performance_analysis,
-- limited to purchases in the dashboard reporting window (2017-01-01 inclusive to
-- 2018-09-01 exclusive). The >= 30 order threshold is applied when ranking (see 06).
CREATE OR REPLACE VIEW public.seller_performance_dashboard AS
WITH single_item_orders AS (
    SELECT order_id FROM public.order_items GROUP BY order_id HAVING COUNT(*) = 1
)
SELECT oi.seller_id, COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE o.order_delivered_carrier_date > oi.shipping_limit_date) AS after_limit_orders,
       ROUND(COUNT(*) FILTER (WHERE o.order_delivered_carrier_date > oi.shipping_limit_date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS after_limit_rate
FROM public.orders o JOIN public.order_items oi ON o.order_id = oi.order_id
JOIN single_item_orders s ON o.order_id = s.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND oi.shipping_limit_date IS NOT NULL
  AND o.order_purchase_timestamp >= DATE '2017-01-01'
  AND o.order_purchase_timestamp < DATE '2018-09-01'
GROUP BY oi.seller_id;
