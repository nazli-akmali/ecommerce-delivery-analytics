-- 06 · Seller performance
-- Purpose : seller activity, late-shipment (after shipping limit) rates and the top 10 ranking.
-- Requires: queries 3 to 6 use views from 03_reporting_views.sql.
-- Note    : the >= 30 eligible-order threshold is applied in WHERE, before ORDER BY / LIMIT,
--           so sellers below the threshold can never enter the top 10.
-- 1. Distribution of distinct orders per seller (source-level activity)
WITH seller_orders AS (
    SELECT seller_id, COUNT(DISTINCT order_id) AS total_orders
    FROM public.order_items WHERE seller_id IS NOT NULL GROUP BY seller_id
)
SELECT COUNT(*) AS total_sellers, ROUND(AVG(total_orders), 2) AS avg_orders_per_seller,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_orders) AS median_orders_per_seller,
       MAX(total_orders) AS max_orders_per_seller,
       COUNT(*) FILTER (WHERE total_orders < 10) AS sellers_under_10_orders
FROM seller_orders;

-- 2. Coverage of sellers with >= 30 distinct source orders
-- Multi-seller orders may be counted for more than one seller here.
WITH seller_orders AS (
    SELECT seller_id, COUNT(DISTINCT order_id) AS total_orders
    FROM public.order_items WHERE seller_id IS NOT NULL GROUP BY seller_id
)
SELECT COUNT(*) AS total_sellers,
       COUNT(*) FILTER (WHERE total_orders >= 30) AS sellers_with_30_plus_orders,
       ROUND(COUNT(*) FILTER (WHERE total_orders >= 30) * 100.0 / NULLIF(COUNT(*), 0), 2) AS eligible_seller_percentage,
       SUM(total_orders) FILTER (WHERE total_orders >= 30) AS eligible_seller_order_attributions,
       ROUND(SUM(total_orders) FILTER (WHERE total_orders >= 30) * 100.0
             / NULLIF(SUM(total_orders), 0), 2) AS eligible_attribution_share
FROM seller_orders;

-- 3. Top 10 eligible sellers, full-history analytical view
SELECT seller_id, total_orders, after_limit_orders, after_limit_rate
FROM public.seller_performance_analysis
WHERE total_orders >= 30
ORDER BY after_limit_rate DESC, seller_id ASC LIMIT 10;

-- 4. Dashboard validation: top 10 from the dashboard view (Jan 2017–Aug 2018)
SELECT seller_id, total_orders, after_limit_orders, after_limit_rate
FROM public.seller_performance_dashboard
WHERE total_orders >= 30
ORDER BY after_limit_rate DESC, seller_id ASC LIMIT 10;

-- 5. Shipping delays concentrated among top 10 sellers by ABSOLUTE delay count
-- Distinct from ranking sellers by delay RATE; no >=30 restriction in this check.
WITH ranked AS (
    SELECT seller_id, total_orders, after_limit_orders,
           ROW_NUMBER() OVER (ORDER BY after_limit_orders DESC, seller_id) AS seller_rank
    FROM public.seller_performance_analysis
)
SELECT SUM(after_limit_orders) AS all_after_limit_orders,
       SUM(after_limit_orders) FILTER (WHERE seller_rank <= 10) AS top_10_after_limit_orders,
       ROUND(SUM(after_limit_orders) FILTER (WHERE seller_rank <= 10) * 100.0
             / NULLIF(SUM(after_limit_orders), 0), 2) AS top_10_delay_share,
       SUM(total_orders) AS all_orders,
       SUM(total_orders) FILTER (WHERE seller_rank <= 10) AS top_10_orders,
       ROUND(SUM(total_orders) FILTER (WHERE seller_rank <= 10) * 100.0
             / NULLIF(SUM(total_orders), 0), 2) AS top_10_order_share,
       ROUND(SUM(after_limit_orders) FILTER (WHERE seller_rank <= 10) * 100.0
             / NULLIF(SUM(total_orders) FILTER (WHERE seller_rank <= 10), 0), 2) AS top_10_after_limit_rate
FROM ranked;

-- 6. Coverage of the eligible seller population (full history)
SELECT SUM(total_orders) AS eligible_orders, SUM(after_limit_orders) AS after_limit_orders,
       ROUND(SUM(after_limit_orders) * 100.0 / NULLIF(SUM(total_orders), 0), 2) AS overall_after_limit_rate,
       COUNT(*) AS sellers_with_eligible_orders,
       COUNT(*) FILTER (WHERE total_orders >= 30) AS sellers_with_30_plus_orders
FROM public.seller_performance_analysis;
