-- 05 · Shipping delay analysis
-- Purpose : relate carrier handover timing (vs shipping_limit_date) to late customer delivery.
-- Requires: queries 3 and 4 use shipping_risk_analysis from 03_reporting_views.sql.
-- Shipping-limit compliance uses carrier handover timestamp vs shipping_limit_date.
-- Single-item orders avoid ambiguous item-level deadlines on multi-item orders.

-- 1. Overall shipping deadline compliance for eligible single-item delivered orders
WITH single_item_orders AS (
    SELECT order_id FROM public.order_items GROUP BY order_id HAVING COUNT(*) = 1
)
SELECT COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE o.order_delivered_carrier_date > oi.shipping_limit_date) AS after_limit_orders,
       ROUND(COUNT(*) FILTER (WHERE o.order_delivered_carrier_date > oi.shipping_limit_date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS after_limit_rate
FROM public.orders o JOIN public.order_items oi ON o.order_id = oi.order_id
JOIN single_item_orders s ON o.order_id = s.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL AND oi.shipping_limit_date IS NOT NULL;

-- 2. Customer late-delivery risk: within vs after shipping limit
WITH single_item_orders AS (
    SELECT order_id FROM public.order_items GROUP BY order_id HAVING COUNT(*) = 1
)
SELECT CASE WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
            THEN 'Within shipping limit' ELSE 'After shipping limit' END AS shipping_status,
       COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) AS late_orders,
       ROUND(COUNT(*) FILTER (WHERE o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
             * 100.0 / NULLIF(COUNT(*), 0), 2) AS late_delivery_rate
FROM public.orders o JOIN public.order_items oi ON o.order_id = oi.order_id
JOIN single_item_orders s ON o.order_id = s.order_id
WHERE o.order_status = 'delivered' AND o.order_delivered_carrier_date IS NOT NULL
  AND oi.shipping_limit_date IS NOT NULL AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- 3. Shipping delay severity and customer late-delivery rate (all eligible dates)
SELECT shipping_delay_group, COUNT(*) AS total_orders, SUM(is_late) AS late_orders,
       ROUND(AVG(is_late) * 100, 2) AS late_delivery_rate
FROM public.shipping_risk_analysis
GROUP BY shipping_delay_group ORDER BY shipping_delay_group;

-- 4. Dashboard validation: purchases Jan 2017–Aug 2018
SELECT shipping_delay_group, COUNT(*) AS total_orders, SUM(is_late) AS late_orders,
       ROUND(AVG(is_late) * 100, 2) AS late_delivery_rate
FROM public.shipping_risk_analysis
WHERE order_month >= DATE '2017-01-01' AND order_month < DATE '2018-09-01'
GROUP BY shipping_delay_group ORDER BY shipping_delay_group;
-- Associations here are descriptive, not evidence of causation.
