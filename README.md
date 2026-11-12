# E-commerce Delivery Performance Analytics

**PostgreSQL · SQL · Tableau Public**

A self-directed analysis of delivery reliability in the public **Olist Brazilian E-Commerce** dataset (orders purchased January 2017 – August 2018). It looks at when deliveries miss their estimated date, how late carrier handovers are associated with late deliveries, and which sellers have the highest late-shipment rates.

**[Interactive dashboard on Tableau Public](https://public.tableau.com/views/ecom_17944888496740/Dashboard1)** · [Portfolio page](https://nazli-akmali.github.io/ecommerce-delivery/) · [Case study](CASE_STUDY.md) · [SQL scripts](sql/) · [Tableau calculations](tableau_calculations.md)

## Business problem

For a marketplace, a missed delivery estimate is a broken promise to the customer, and the delay can start at several points: with the seller, at carrier handover or in transit. The goal was to find patterns an operations team could act on or investigate further, not only to report one overall late-delivery rate.

## Analytical questions

1. How reliable are estimated delivery dates, and how does that change month to month?
2. How is missing the carrier handover deadline associated with late customer delivery?
3. Which sellers, with enough volume to compare, most often miss their shipping deadline?
4. Do multi-item or multi-seller orders show different delivery outcomes?

## Workflow

1. **Explore and validate** the order and order-item tables: statuses, missing timestamps, join grain ([02](sql/02_initial_data_exploration.sql)).
2. **Build reporting views** that fix the grain of each analysis ([03](sql/03_reporting_views.sql)).
3. **Define KPIs and analyse** delivery performance, shipping delays, sellers and order structure ([04](sql/04_delivery_performance_analysis.sql)–[07](sql/07_order_structure_analysis.sql)).
4. **Build the Tableau dashboard** on the views and cross-check its figures against SQL validation queries ([Tableau calculations](tableau_calculations.md)).

## Key findings

| Metric (Jan 2017 – Aug 2018) | Result |
| --- | ---: |
| Delivered orders | **96,203** |
| Late-delivery rate | **6.79%** |
| Average actual delivery time | **12.54 days** |
| Peak monthly late-delivery rate | **18.96%** (March 2018, ~2.8× overall) |

**Late shipment is strongly associated with late delivery.** Among eligible single-item delivered orders:

| Carrier handover vs shipping deadline | Late-delivery rate |
| --- | ---: |
| Within limit | 5.57% |
| Up to 1 day late | 11.55% |
| 1–3 days late | 18.12% |
| More than 3 days late | 41.85% |

Orders handed over more than three days late had a **~7.5×** higher late-delivery rate than orders handed over on time.

**Late-shipment rates vary widely between sellers.** Among sellers with at least 30 eligible orders, the ten highest late-shipment rates range from **48.57% to 90.32%**.

All findings are descriptive associations from historical data. They do not establish causes. See the [case study](CASE_STUDY.md) for definitions, limitations and recommendations.

## Key definitions

- **Late delivery:** actual customer delivery *date* is after the estimated delivery *date* (calendar-day comparison).
- **Late shipment:** carrier handover *timestamp* is after the item's `shipping_limit_date`.
- **Eligible orders** (shipping-delay and seller analyses): delivered, single-item orders with the required timestamps, so each handover maps to exactly one seller and one deadline.
- **Seller ranking:** only sellers with at least 30 eligible orders; the threshold is applied before selecting the top 10.

## Repository structure

```text
.
├── README.md
├── CASE_STUDY.md                 problem framing, decisions, findings, limitations
├── tableau_calculations.md       calculated fields, filters, tooltips
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_initial_data_exploration.sql
│   ├── 03_reporting_views.sql    run before 05, 06, 07
│   ├── 04_delivery_performance_analysis.sql
│   ├── 05_shipping_delay_analysis.sql
│   ├── 06_seller_performance_analysis.sql
│   └── 07_order_structure_analysis.sql
└── tests/
    └── synthetic_logic_checks.sql
```

## Reproducing the analysis

The raw Olist CSVs are not included. Download the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and use the orders and order-items files.

1. Run `sql/01_create_tables.sql` in PostgreSQL.
2. Import `olist_orders_dataset.csv` into `public.orders` and `olist_order_items_dataset.csv` into `public.order_items`.
3. Run `sql/03_reporting_views.sql` to create the views.
4. Run the analysis scripts `02` and `04`–`07` in any order.

## Validation status

- **Checked:** all scripts run without errors, in the order above, on PostgreSQL 18 with an empty schema. This confirms syntax and that views exist before the queries that use them.
- **Checked:** `tests/synthetic_logic_checks.sql` uses made-up rows to confirm the shipping-delay group boundaries, the calendar-day definition of lateness, the exclusion of multi-item orders, the 30-order threshold before the top 10, and the dashboard date window.
- **Not re-checked here:** the cleaned scripts were not re-run against the full Olist data. The figures above come from the published dashboard. The `Dashboard validation` queries in scripts 04–06 reproduce them, so run those against your own import before treating the numbers as independently verified.
