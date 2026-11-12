-- Synthetic logic checks (made-up rows, not Olist data).
-- Run after 01_create_tables.sql and 03_reporting_views.sql on an EMPTY database:
-- it truncates both source tables before and after the checks.
-- Expected: g0 Within limit; g1, g2 Up to 1 day late; g3, g4 1-3 days late; g5 More than 3 days late;
--           "multi" excluded; g2 not late (delivered on the estimated calendar day).
--           Dashboard top 10 = sBig only (sSmall < 30 orders, sOld outside the window);
--           full-history top 10 = sBig and sOld.
TRUNCATE public.orders, public.order_items;
-- Boundary cases for shipping groups (handover minus limit): 0d, +12h, +1d exactly, +2d, +3d exactly, +5d
INSERT INTO public.orders VALUES
 ('g0','c','delivered','2017-03-01'::timestamp,'2017-03-01'::timestamp,'2017-03-05'::timestamp,'2017-03-10'::timestamp,'2017-03-12'),
 ('g1','c','delivered','2017-03-01'::timestamp,'2017-03-01'::timestamp,'2017-03-05 12:00','2017-03-13'::timestamp,'2017-03-12'),
 ('g2','c','delivered','2017-03-01'::timestamp,'2017-03-01'::timestamp,'2017-03-06'::timestamp,'2017-03-12 23:00','2017-03-12'),
 ('g3','c','delivered','2017-03-01'::timestamp,'2017-03-01'::timestamp,'2017-03-07'::timestamp,'2017-03-14'::timestamp,'2017-03-12'),
 ('g4','c','delivered','2017-03-01'::timestamp,'2017-03-01'::timestamp,'2017-03-08'::timestamp,'2017-03-14'::timestamp,'2017-03-12'),
 ('g5','c','delivered','2017-03-01'::timestamp,'2017-03-01'::timestamp,'2017-03-10'::timestamp,'2017-03-20'::timestamp,'2017-03-12'),
 ('multi','c','delivered','2017-03-01'::timestamp,'2017-03-01'::timestamp,'2017-03-10'::timestamp,'2017-03-20'::timestamp,'2017-03-12');
INSERT INTO public.order_items VALUES
 ('g0',1,'p','sA','2017-03-05'::timestamp,10,1),('g1',1,'p','sA','2017-03-05'::timestamp,10,1),('g2',1,'p','sA','2017-03-05'::timestamp,10,1),
 ('g3',1,'p','sA','2017-03-05'::timestamp,10,1),('g4',1,'p','sA','2017-03-05'::timestamp,10,1),('g5',1,'p','sA','2017-03-05'::timestamp,10,1),
 ('multi',1,'p','sA','2017-03-05'::timestamp,10,1),('multi',2,'p','sA','2017-03-05'::timestamp,10,1);
SELECT 'groups' AS test, order_id, round(days_after_limit::numeric,2) AS d, shipping_delay_group, is_late
FROM public.shipping_risk_analysis ORDER BY order_id;
-- Threshold + window: seller sBig has 30 eligible orders in window (all late) ; sSmall 29 (all late);
-- sOld has 40 late orders but purchased in 2016 (outside dashboard window)
INSERT INTO public.orders
SELECT 'big'||i,'c','delivered','2017-06-01'::timestamp,'2017-06-01'::timestamp,'2017-06-09'::timestamp,'2017-06-15'::timestamp,'2017-06-20'::timestamp FROM generate_series(1,30) i
UNION ALL SELECT 'small'||i,'c','delivered','2017-06-01'::timestamp,'2017-06-01'::timestamp,'2017-06-09'::timestamp,'2017-06-15'::timestamp,'2017-06-20'::timestamp FROM generate_series(1,29) i
UNION ALL SELECT 'old'||i,'c','delivered','2016-10-01'::timestamp,'2016-10-01'::timestamp,'2016-10-09'::timestamp,'2016-10-15'::timestamp,'2016-10-20'::timestamp FROM generate_series(1,40) i;
INSERT INTO public.order_items
SELECT 'big'||i,1,'p','sBig','2017-06-05'::timestamp,10::numeric,1::numeric FROM generate_series(1,30) i
UNION ALL SELECT 'small'||i,1,'p','sSmall','2017-06-05'::timestamp,10::numeric,1::numeric FROM generate_series(1,29) i
UNION ALL SELECT 'old'||i,1,'p','sOld','2016-10-05'::timestamp,10::numeric,1::numeric FROM generate_series(1,40) i;
SELECT 'dashboard_top10' AS test, seller_id, total_orders, after_limit_rate
FROM public.seller_performance_dashboard WHERE total_orders >= 30
ORDER BY after_limit_rate DESC, seller_id ASC LIMIT 10;
SELECT 'fullhistory_top10' AS test, seller_id, total_orders, after_limit_rate
FROM public.seller_performance_analysis WHERE total_orders >= 30
ORDER BY after_limit_rate DESC, seller_id ASC LIMIT 10;
TRUNCATE public.orders, public.order_items;
