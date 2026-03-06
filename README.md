# Ecommerce Customer Retention Analysis
### End-to-End Data Analytics Project | PostgreSQL · Power BI · Statistical Analysis

> **Dataset:** Brazilian E-Commerce (Olist) &nbsp;|&nbsp; **Period:** Jan 2017 – Aug 2018 &nbsp;|&nbsp; **Year:** 2026

---

## The Central Question

> *"Is revenue growth structurally sustainable, or is it entirely dependent on new customer acquisition?"*

---

> 📥 **Download full Power BI file (.pbix):** [Google Drive Link] (https://drive.google.com/file/d/1wQoQI3DIbJJxRWMvD1DayvcHRuNtr2Tj/view?usp=sharing)


---

## Key Findings at a Glance

| Metric | Result |
|---|---|
| Total Platform Revenue | $16,008,872 |
| Total Orders Analysed | 99,441 |
| Repeat Customer Rate | 3.12% (2,997 customers) |
| Repeat Revenue Share | 5.81% of total revenue |
| Avg Spend — Repeat Customer | $308 |
| Avg Spend — One-Time Customer | $160 |
| Lifecycle Anomalies Detected | 1,382 orders (1.39%) |
| Financial Mismatches Found | 576 orders · $3,271.95 gap |
| Orders Without Payment | 1 order |
| Invalid Review Scores | 0 |

> Repeat customers spend nearly **2× more** than one-time buyers, yet represent only **3.12%** of the customer base — a significant retention gap and a major growth opportunity.

---

## Technology Stack

| Layer | Tool | Purpose |
|---|---|---|
| Database | PostgreSQL | Schema design, querying, views, indexes, materialized views |
| Analysis | SQL (Advanced) | CTEs, window functions, aggregations, EXPLAIN ANALYZE |
| Visualisation | Microsoft Power BI | Interactive dashboards, DAX measures, trend analysis |
| Data Source | Olist Brazilian Dataset | Real-world ecommerce transactions 2017–2018 |

---

## Dataset

The raw data is **not included** in this repository due to file size.

Download the Olist Brazilian E-Commerce dataset from Kaggle:

🔗 [https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

After downloading, load each CSV into the corresponding PostgreSQL table as defined in **Section 1** of `ecommerce_project_final.sql`.

---

## Database Schema

```
customers            → customer_id (PK), customer_unique_id, city, state
orders               → order_id (PK), customer_id (FK), status, timestamps
order_items          → order_id (FK), product_id, price, freight_value
order_payments       → order_id (FK), payment_value
orders_reviews       → review_id (PK), order_id (FK), review_score, review_creation_date
products             → product_id (PK), product_category_name
category_translation → product_category_name, product_category_name_english
```

---

## Project Structure & Analysis Phases

### Phase 1 — Data Quality & Integrity
Validated all raw data across four dimensions before any business analysis:

- **Null checks** on critical order fields (order_id, customer_id, timestamps, status)
- **Lifecycle anomaly detection** — flagged orders where carrier pickup preceded approval, or delivery preceded shipment → **1,382 anomalies (1.39%)**
- **Financial integrity** — item totals vs payment totals compared per order using isolated CTEs to avoid many-to-many join inflation → **576 mismatched orders, $3,271.95 total gap**
- **Review quality** — scores outside 1–5 range (0 found), reviews before delivery, delivered orders with no review

### Phase 2 — Revenue Analysis
- Total platform revenue: **$16,008,872**
- Monthly revenue trend with **3-month rolling average** to smooth seasonality
- **Month-over-month (MoM) growth %** using `LAG()` window function
- Monthly **Average Order Value (AOV)** tracked across the full 2017–2018 period

### Phase 3 — Customer Retention Analysis
- Repeat customer rate: **3.12%** made more than one purchase
- Repeat customers generate **5.81%** of total revenue despite being a tiny segment
- Repeat customers spend **$308** avg vs **$160** for one-time buyers — a **92.5% premium**
- **Category-level retention:** `bed_bath_table` and `sports_leisure` show highest repeat loyalty
- **State-level repeat rates:** AC (5.19%) and RO (4.17%) lead; most states cluster near 3%

### Phase 4 — Cohort Analysis
- First-purchase month identified per unique customer
- Cohort sizes tracked from Jan 2017 onward
- Month-number retention matrix built using `AGE()` to calculate months elapsed since first purchase
- Active customers per cohort per month tracked to identify drop-off patterns

### Phase 5 — Pareto / 80-20 Analysis
- Top customers by revenue ranked using **cumulative `SUM()` window function**
- Identified what % of customers drive 80% of total revenue
- Same analysis applied at **category level** to identify revenue-critical segments

### Phase 6 — Strategic Targeting (What If Analysis)

The key business question: *what happens to revenue if we grow the repeat customer rate from 3.12% to just 5%?*

| Metric | Value |
|---|---|
| Total Unique Customers | 96,095 |
| Current Repeat Customers | 2,997 |
| Current Repeat Rate | 3.12% |
| Avg Revenue per Repeat Customer | $314.99 |
| Target Repeat Customers at 5% | 4,805 |
| **Additional Revenue if 5% Achieved** | **$569,421.77** |

> A modest improvement of just **~1.88 percentage points** in repeat rate — converting roughly **1,808 more customers** into repeat buyers — would generate an additional **$569K in revenue** without acquiring a single new customer. This makes retention investment one of the highest-ROI levers available to the business.

### Phase 7 — Query Performance Optimisation
- Baseline `EXPLAIN ANALYZE` to capture pre-optimisation query plan
- Indexes created on `order_items(order_id)` and `order_payments(order_id)`
- **Materialized views** created for `order_item_totals` and `order_payment_totals`
- Final `EXPLAIN ANALYZE` confirms improved plan using MV sequential scans vs nested loops

---

## SQL File Reference

| Section | Description |
|---|---|
| Section 1 | Schema creation — all 7 tables |
| Section 2 | Null checks on orders |
| Section 3 | Lifecycle anomaly detection + `orders_enriched` VIEW |
| Section 4 | Price and freight quality checks |
| Section 5 | Orders without payment records |
| Section 6 | Financial discrepancy analysis (naive vs CTE approach) |
| Section 7 | Review data quality checks |
| Section 8 | Query performance optimisation (indexes + materialized views) |
| Section 9 | Revenue analysis — total, monthly, rolling, MoM |
| Section 10 | Customer retention — repeat rate, revenue share, avg spend |
| Section 11 | Cohort analysis |
| Section 12 | Pareto / 80-20 rule — customers and categories |
| Section 13 | Category-based retention analysis |
| Section 14 | Strategic target — 5% repeat rate revenue simulation |

---

## Power BI Dashboard

### Page 1 — Is Revenue Growth Structurally Sustainable?

| Visual | Insight |
|---|---|
| KPI Cards (5) | Total Revenue $15.79M · Repeat Rate 3.10% · Repeat Revenue 5.81% · Avg Spend Repeat $308 · Avg Spend One-Time $160 |
| Total Revenue Trend | Clear upward trajectory Jan → Oct 2017, plateau and slight decline through 2018 |
| Monthly Repeat Revenue Share | Volatile 1%–4.2% range; average 2.65% — confirms revenue is not retention-driven |
| Insight Banner | *"Only ~3% of customers return, contributing ~6% of revenue. Growth is acquisition-dependent."* |

### Page 2 — Customer Retention Deep Dive

| Visual | Insight |
|---|---|
| KPI Cards (4) | 2,997 Repeat Customers · $911.27K Repeat Revenue · 3.12% Rate · $304 Avg Spend |
| Top Categories by Repeat Revenue | `bed_bath_table` ($119K) leads, followed by `sports_leisure` ($89K) and `furniture_decor` ($81K) |
| Repeat Rate % by State | AC (5.19%) and RO (4.17%) are outlier high-retention states; SP large but average at 3.22% |
| New vs Repeat Revenue Trend | New customer revenue dominates throughout; repeat revenue % stays flat 2–4% |

---

## Notable Technical Decisions

### Many-to-Many Join Problem
An initial triple JOIN (`orders → order_items → order_payments`) inflated mismatch counts to **12,500**. The correct approach uses two **separate CTEs** — one aggregating item totals, one aggregating payment totals — before joining. This reduced the true mismatch count to **576**.

```sql
-- WRONG: triple join causes row multiplication → 12,500 (incorrect)
SELECT COUNT(*) FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_payments p ON o.order_id = p.order_id ...

-- CORRECT: aggregate separately first → 576 (accurate)
WITH item_totals AS (
    SELECT order_id, SUM(price + frieght_value) AS total_order_value
    FROM order_items GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS total_payment_value
    FROM order_payments GROUP BY order_id
)
SELECT COUNT(*) FROM item_totals i
LEFT JOIN payment_totals p ON i.order_id = p.order_id
WHERE ROUND(i.total_order_value,2) <> ROUND(p.total_payment_value,2);
```

### Cohort Month Calculation
Month number within cohort is calculated using:

```sql
EXTRACT(YEAR FROM AGE(activity_month, cohort_month)) * 12
+ EXTRACT(MONTH FROM AGE(activity_month, cohort_month)) AS month_number
```

This correctly handles year boundaries without relying on simple date subtraction.

### Materialized Views for Performance
The financial mismatch query was optimised using materialized views, eliminating repeated full-table aggregations on every execution:

```sql
CREATE MATERIALIZED VIEW order_item_totals AS
SELECT order_id, SUM(price + frieght_value) AS total_order_value
FROM order_items GROUP BY order_id;
```

---

## Business Recommendations

1. **Launch a post-purchase retention programme** targeting one-time buyers in high-loyalty categories (`bed_bath_table`, `sports_leisure`)
2. **Focus retention campaigns on high-repeat-rate states** (AC, RO, RJ) where the behaviour already exists and can be amplified
3. **Resolve the 576 financially mismatched orders** — these represent real payment reconciliation risk
4. **Address 1,382 lifecycle anomaly orders** to improve data pipeline reliability and prevent reporting distortions
5. **Build a VIP retention programme** for the top 20% of revenue-generating customers identified in the Pareto analysis

---

## How to Run

### Prerequisites
- PostgreSQL 13+
- Power BI Desktop — [Download here](https://powerbi.microsoft.com/desktop)
- Olist dataset — [Download from Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

### Steps

```bash
# 1. Create schema and tables
#    Run Section 1 of ecommerce_project_final.sql in pgAdmin or psql

# 2. Load Olist CSV data into each table
#    Use pgAdmin import or psql \copy command

# 3. Run Sections 2–14 in order to reproduce all analysis results

# 4. Open ecommerce-retention-analysis.pbix in Power BI Desktop
#    Update the data source connection to your PostgreSQL instance
#    Click Refresh
```

---

## File Structure

```
ecommerce-retention-analysis/
├── ecommerce_project_final.sql        # Complete SQL — all 14 sections
├── README.md                          # This file
├── screenshots/
│   ├── dashboard_page1.png            # Revenue sustainability dashboard
│   └── dashboard_page2.png            # Customer retention deep dive
└── .gitignore                         # Excludes CSVs and large files
```

---

## Links

| Resource | Link |
|---|---|
| 📊 Power BI Dashboard (.pbix) | [Google Drive](https://drive.google.com/file/d/1wQoQI3DIbJJxRWMvD1DayvcHRuNtr2Tj/view?usp=sharing)|
| 📦 Olist Dataset | [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) |

---

*Ecommerce Customer Retention Analysis · End-to-End Data Analytics Project · 2026*

