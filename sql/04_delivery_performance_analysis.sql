-- 04 · Delivery performance
-- Purpose : headline delivery KPIs, lateness severity and monthly trends.
-- Requires: 01_create_tables.sql and the imported Olist CSVs (no views needed).
-- Delivery lateness is defined by calendar date (not exact timestamp).
-- Analyses require delivered status and non-null actual/estimated dates.

-- 1. Overall delivery KPI
SELECT COUNT(*) AS valid_delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date) AS late_orders,
       ROUND(COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS late_delivery_rate
FROM public.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- 2. Severity among late orders only
SELECT ROUND(AVG(order_delivered_customer_date::date - order_estimated_delivery_date::date), 2) AS avg_days_late,
       MAX(order_delivered_customer_date::date - order_estimated_delivery_date::date) AS max_days_late,
       PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY order_delivered_customer_date::date - order_estimated_delivery_date::date
       ) AS median_days_late,
       PERCENTILE_CONT(0.9) WITHIN GROUP (
           ORDER BY order_delivered_customer_date::date - order_estimated_delivery_date::date
       ) AS p90_days_late
FROM public.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_delivered_customer_date::date > order_estimated_delivery_date::date;

-- 3. Monthly delivery volume and late-delivery rate (full history)
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS order_month,
       COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date) AS late_orders,
       ROUND(COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS late_delivery_rate
FROM public.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- 4. Focused monthly comparison, January–May 2018
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS order_month,
       COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date) AS late_orders,
       ROUND(COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS late_delivery_rate,
       ROUND((AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400))::numeric, 2) AS avg_actual_delivery_days,
       ROUND((AVG(EXTRACT(EPOCH FROM (order_estimated_delivery_date - order_purchase_timestamp)) / 86400))::numeric, 2) AS avg_estimated_delivery_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400
       ) AS median_actual_delivery_days
FROM public.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_purchase_timestamp >= DATE '2018-01-01'
  AND order_purchase_timestamp < DATE '2018-06-01'
GROUP BY 1 ORDER BY 1;

-- 5. Dashboard KPI validation: purchases Jan 2017–Aug 2018
SELECT COUNT(*) AS valid_delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date) AS late_orders,
       ROUND(COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS late_delivery_rate,
       ROUND((AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400))::numeric, 2) AS avg_delivery_days
FROM public.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_purchase_timestamp >= DATE '2017-01-01'
  AND order_purchase_timestamp < DATE '2018-09-01';
-- AVG uses exact durations; Tableau weighted averages of rounded monthly means may differ slightly.
