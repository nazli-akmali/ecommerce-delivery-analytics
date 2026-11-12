# Tableau Calculations & Dashboard Configuration

[← Back to README](README.md) · [Interactive dashboard](https://public.tableau.com/views/ecom_17944888496740/Dashboard1)

These notes document the Tableau Public implementation for the Olist e-commerce operations and customer-experience analysis. Field names below reflect the submitted calculations; ensure they match the connected data source.

## KPI calculated fields

### Late Delivery Rate (%) — aggregated monthly view
```tableau
SUM([Late Orders]) / SUM([Delivered Orders]) * 100
```
Uses a **weighted** ratio across the selected monthly records. Prefer this to `AVG([Late Delivery Rate])` for a multi-month aggregate. Guard against a zero denominator if the data scope could be empty.

### Overall Avg Actual Delivery Days — aggregated monthly view
```tableau
SUM([Avg Actual Delivery Days] * [Delivered Orders]) / SUM([Delivered Orders])
```
Weights monthly means by delivered-order count. Because the SQL monthly view rounds the means to two decimal places, this may differ slightly from the exact order-level mean.

### Late Delivery Rate (%) — order-level view
```tableau
AVG([Is Late]) * 100
```
Valid when each record represents exactly one order and `[Is Late]` is numeric 0/1. The similarly named KPI above is for the *monthly aggregated* data source; do not confuse the two formulas.

## Seller performance

### After Limit Rate (30+ Orders)
```tableau
IF [Total Orders] >= 30 THEN
    [After Limit Rate]
END
```
Returns `NULL` for sellers with fewer than 30 eligible orders; it does not remove those sellers from the data source. Use a suitable non-null filter if needed.

### Top 10 Sellers Filter — table calculation
```tableau
INDEX() <= 10
```
Sort sellers by `[After Limit Rate]` descending **after applying the >=30-order eligibility rule**; set `Compute Using` to the seller dimension and retain `True`. `INDEX()` follows the displayed sort order; it does not rank sellers by itself. When tied, Tableau's order may differ from the SQL tie-breaker (`seller_id ASC`) unless the same secondary sort is applied.

## KPI labels and chart labels

**KPI label insertion** (Tableau markup, not a formula):
```text
<AGG(Overall Late Delivery Rate)>
```

**Late delivery rate label** (Tableau markup, not a formula):
```text
<AGG(Late Delivery Rate (%))>%
```

If the calculated field already has percentage formatting, avoid appending another `%` or multiplying by 100 twice.

## Tooltips

### Monthly delivery performance
```text
<MONTH(Order Month)>

Delivered Orders: <SUM(Delivered Orders)>
Late Deliveries: <SUM(Late Orders)>
Late Delivery Rate: <AVG(Late Delivery Rate)>%
```
`AVG([Late Delivery Rate])` is appropriate for a single month with one underlying monthly record; for a combined set of months, use the weighted KPI formula above.

### Shipping delay risk
```text
<Shipping Delay Group>

Total Orders: <CNTD(Order Id)>
Late Delivery Rate: <AGG(Late Delivery Rate (%))>%
```
`CNTD([Order Id])` counts unique orders. The shipping risk view is already one row per eligible single-item order, so this is also a defensive check against duplication.

## Data source and interpretation notes

- `monthly_delivery_performance` is **one row per month**.
- `order_structure_analysis` and `shipping_risk_analysis` are **one row per qualifying order**.
- `seller_performance_dashboard` is **one row per seller**, restricted to purchases from **2017-01-01 (inclusive)** to **2018-09-01 (exclusive)**.
- The seller >=30 threshold must be applied **before** selecting the top 10. Do not rank the unfiltered sellers first.
- `After Limit Rate` refers to **carrier handover after the shipping deadline**, not customer delivery after the estimated date.
- Tooltip tokens such as `<AGG(...)>` are Tableau-rendered field placeholders, not executable calculations.

## Filters and reporting window

- The general SQL views cover the full order history. The dashboard reports purchases from **January 2017 to August 2018**, so the monthly and shipping-risk data sources need a filter on `Order Month` for that range (`seller_performance_dashboard` already applies it in SQL).
- Seller ranking order of operations: keep sellers with `Total Orders >= 30` (non-null `After Limit Rate (30+ Orders)`), sort by `After Limit Rate` descending, then keep `INDEX() <= 10`.
- To check the dashboard against SQL, compare it with the `Dashboard validation` queries in `sql/04`–`sql/06`.

## Seller ID display

Olist seller IDs are 32-character hashes, which take up a lot of space in the Top 10 chart. A display-only option that leaves the data unchanged:

```tableau
LEFT([Seller Id], 8) + "…"
```

Use it as the row label and keep the full `[Seller Id]` in the tooltip. Alternatively, alias the ten visible sellers as `Seller 1`–`Seller 10` by rank.

