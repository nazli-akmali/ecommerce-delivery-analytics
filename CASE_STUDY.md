# Case Study: Delivery Delays in Brazilian E-commerce

[← Back to README](README.md) · [Interactive dashboard](https://public.tableau.com/views/ecom_17944888496740/Dashboard1)

## 1. Problem framing

When a marketplace misses a delivery estimate, the customer experiences one broken promise, but the delay can come from several places: the seller preparing the order, the handover to the carrier, or transport. A single late-delivery rate tells an operations team that a problem exists, not where to look.

I framed the analysis around questions that point to where to investigate:

| Question | Approach |
| --- | --- |
| How often are orders delivered after the estimated date? | Late-order count and rate among delivered orders with valid dates |
| Does reliability vary by month? | Monthly cohorts by purchase date |
| Is late carrier handover associated with late delivery? | Compare four shipping-delay groups on single-item orders |
| Which sellers warrant a closer look? | Rank late-shipment rates above a minimum-volume threshold |
| Does order complexity matter? | Compare single/multi-item and single/multi-seller orders |

**Scope:** orders purchased from 2017-01-01 (inclusive) to 2018-09-01 (exclusive). **Tools:** PostgreSQL for exploration, validation and reporting views; Tableau Public for the dashboard.

## 2. KPI definitions

| KPI | Definition |
| --- | --- |
| Late delivery | `order_delivered_customer_date::date > order_estimated_delivery_date::date` |
| Late-delivery rate | late deliveries ÷ delivered orders with both dates present |
| Actual delivery time | purchase timestamp → customer delivery timestamp, in days |
| Late shipment | carrier handover timestamp strictly after `shipping_limit_date` |
| Days after limit | (carrier handover − shipping limit) in days; ≤ 0 means on time |
| Seller late-shipment rate | late shipments ÷ eligible orders for that seller |

Late delivery is compared by **calendar day**, because customers experience the estimate as a date. Late shipment is compared by **timestamp**, because the shipping limit is an exact deadline. The two measures answer different questions and are kept separate throughout: a *late shipment* is a missed seller deadline, while a *late delivery* is a missed customer promise.

## 3. Data preparation

The analysis uses the orders table (one row per order, with all timestamps) and the order-items table (one row per item, with seller and shipping limit). Script [02](sql/02_initial_data_exploration.sql) checks:

- **Order statuses:** the KPIs use `delivered` orders only.
- **Missing timestamps:** delivered orders without a customer delivery or carrier handover date are excluded where that date is needed.
- **Join grain:** one order can have several items and sellers. Joining items to orders multiplies rows, so counting joined rows as orders inflates totals. Items are summarised per order before joining back, and the script confirms that joined rows equal distinct orders afterwards.
- **Orders without items** and the distribution of items and sellers per order.

## 4. Analytical decisions

**Single-item orders for shipping and seller analysis.** A multi-item order can have several shipping limits and sellers, but only one carrier handover timestamp at order level. Restricting to delivered single-item orders gives an unambiguous link between one handover, one deadline and one seller. The cost is that these results describe a subset of orders, not the whole marketplace.

**Shipping-delay groups.** Days after limit is grouped numerically: within limit (≤ 0), up to 1 day, 1–3 days, more than 3 days. Grouping uses the number, never the label text, so the order of the groups can't drift.

**Minimum volume for sellers.** A seller with three orders and two late shipments shows 67%, which says little. Only sellers with at least **30 eligible orders** in the reporting window are ranked, and the threshold is applied *before* selecting the top 10. Thirty orders reduces, but does not remove, the noise in a rate.

**Reporting views.** Script [03](sql/03_reporting_views.sql) fixes the grain of each Tableau data source: one row per month, per order, per eligible order or per seller. General views cover the full history; a separate dashboard view limits seller results to the reporting window.

## 5. Findings

### A. Overall reliability and monthly variation

The dashboard reports **96,203 delivered orders**, a **6.79%** late-delivery rate and an average delivery time of **12.54 days**.

The monthly rate is far from stable. **March 2018 reached 18.96%**, about **2.8×** the overall rate, and November 2017 was also elevated at around 12%. The data shows *when* these spikes happened, but not *why*.

### B. Late shipment and late delivery

| Shipping-delay group | Late-delivery rate |
| --- | ---: |
| Within limit | 5.57% |
| Up to 1 day late | 11.55% |
| 1–3 days late | 18.12% |
| More than 3 days late | 41.85% |

The late-delivery rate rises steadily with the size of the shipping delay. Orders handed over more than three days late were late **41.85%** of the time against **5.57%** for on-time handovers, about **7.5×** as often. That makes shipping-deadline compliance a useful early signal to monitor. These are unadjusted comparisons, and route, carrier, region and product can affect both shipping and delivery.

### C. Seller late-shipment rates

Among sellers with at least 30 eligible orders, the ten highest late-shipment rates range from **48.57% to 90.32%**. These are the highest rates within that eligible population. They identify sellers to review first, not proof of poor seller performance on every dimension.

## 6. Dashboard design

The dashboard reads top to bottom as an argument:

1. **KPI cards:** volume, late-delivery rate, average delivery time.
2. **Monthly trend:** variability, with the March 2018 peak annotated.
3. **Shipping-delay comparison:** the rising late-delivery rate across the four groups.
4. **Key insight:** the 7.5× comparison in one sentence.
5. **Top 10 sellers:** late-shipment rates with the 30-order threshold stated.
6. **Methodology note:** which populations each chart uses.

Aggregate rates are weighted (`SUM(late) / SUM(delivered)`), not averages of monthly percentages. Details are in [tableau_calculations.md](tableau_calculations.md).

## 7. Business implications

These are recommendations and open questions. None of them was implemented or tested in this project.

- **Investigate the March 2018 spike** by region, carrier, product mix and order volume, to separate operational causes from changes in the order mix.
- **Monitor shipping-deadline compliance** as an early-warning metric, with particular attention to handovers more than three days late.
- **Prioritise seller follow-up** using late-shipment rate *and* order volume together, and review each seller's context before drawing conclusions.
- **Explore earlier alerts** for orders that pass their shipping limit without a handover, and test whether they identify at-risk orders in time to act.
- **Link delivery to customer outcomes** by analysing how late deliveries relate to review scores and repeat purchases (the Olist reviews and customers tables).

Any intervention should be evaluated against a comparison group, because the associations here don't show which change would work.

## 8. Limitations

- Shipping-delay and seller results use **delivered single-item orders** only, and may not generalise to multi-item or undelivered orders.
- Comparisons are **unadjusted** for region, carrier, product category and seasonality.
- The shipping limit is a seller deadline, not the customer-facing estimate.
- Monthly figures are **purchase-month cohorts**; deliveries can fall in a later month.
- The seller views require a carrier handover date but not a customer delivery date, so their eligible population can be slightly larger than the shipping-delay view's.
- The data is historical (2017–2018) and observational: the associations do not establish causality.
- The cleaned SQL was checked on an empty schema and with synthetic rows, but **not re-run against the full Olist data** in its current form. See [Validation status](README.md#validation-status).

## 9. Next steps

1. Re-run the dashboard validation queries in scripts 04–06 against a fresh import and record the results.
2. Add region (customer and seller state) and product category to test whether the March 2018 spike and the seller differences persist within segments.
3. Bring in review scores to quantify how late delivery relates to customer satisfaction.
4. Extend the shipping analysis to multi-item orders using the latest shipping limit per order.
