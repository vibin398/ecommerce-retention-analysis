-- ============================================================
--        ECOMMERCE DATA ANALYSIS PROJECT — FINAL SQL FILE
--        PostgreSQL | Schema: ecommerce
--        Ordered: Schema → Data Quality → Finance → Reviews
--                 → Performance → Retention → Cohort → Strategy
-- ============================================================

SET search_path TO ecommerce;


-- ============================================================
-- SECTION 1: SCHEMA CREATION
-- ============================================================

CREATE TABLE customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix INT,
    customer_city            TEXT,
    customer_state           CHAR(2)
);

CREATE TABLE orders (
    order_id                        TEXT PRIMARY KEY,
    customer_id                     TEXT REFERENCES customers(customer_id),
    order_status                    TEXT,
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

CREATE TABLE order_items (
    order_id      TEXT REFERENCES orders(order_id),
    product_id    TEXT,
    price         NUMERIC,
    frieght_value NUMERIC   -- original spelling preserved from source data
);

CREATE TABLE order_payments (
    order_id      TEXT REFERENCES orders(order_id),
    payment_value NUMERIC
);

CREATE TABLE orders_reviews (
    review_id            TEXT PRIMARY KEY,
    order_id             TEXT REFERENCES orders(order_id),
    review_score         INT,
    review_creation_date TIMESTAMP
);

CREATE TABLE products (
    product_id            TEXT PRIMARY KEY,
    product_category_name TEXT
);

CREATE TABLE category_transalation (   -- original spelling preserved
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);


-- ============================================================
-- SECTION 2: DATA QUALITY — NULL CHECKS
-- ============================================================

-- 2.1 Null checks on critical orders columns
SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL)                 AS null_order_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL)              AS null_customer_id,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS null_purchase_ts,
    COUNT(*) FILTER (WHERE order_status IS NULL)             AS null_order_status
FROM orders;


-- ============================================================
-- SECTION 3: DATA QUALITY — LIFECYCLE ANOMALY DETECTION
-- ============================================================

-- 3.1 Detect timestamp sequence violations
SELECT
    COUNT(*) FILTER (WHERE order_approved_at < order_purchase_timestamp)              AS approved_before_purchase,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date < order_approved_at)          AS shipped_before_approved,
    COUNT(*) FILTER (WHERE order_delivered_customer_date < order_delivered_carrier_date) AS delivered_before_shipped
FROM orders;

-- 3.2 Create enriched view with lifecycle anomaly flag
CREATE VIEW orders_enriched AS
SELECT *,
    CASE
        WHEN order_delivered_carrier_date < order_approved_at
          OR order_delivered_customer_date < order_delivered_carrier_date
        THEN TRUE
        ELSE FALSE
    END AS lifecycle_anomaly_flag
FROM orders;

-- 3.3 Count anomalous orders
SELECT COUNT(*)
FROM orders_enriched
WHERE lifecycle_anomaly_flag = TRUE;

-- 3.4 Summary: total orders, anomaly count, anomaly percentage
-- Result: 99,441 total | 1,382 anomalies | 1.39%
SELECT
    COUNT(*)                                                                              AS total_orders,
    SUM(CASE WHEN lifecycle_anomaly_flag THEN 1 ELSE 0 END)                              AS anomaly_order,
    ROUND(100.00 * SUM(CASE WHEN lifecycle_anomaly_flag THEN 1 ELSE 0 END) / COUNT(*), 2) AS percentage_anomaly
FROM orders_enriched;


-- ============================================================
-- SECTION 4: DATA QUALITY — ORDER ITEMS PRICE CHECKS
-- ============================================================

-- 4.1 Check for negative or zero prices
-- Result: 0 negative prices | 0 negative freight | 0 zero-price items
SELECT
    COUNT(*) FILTER (WHERE price < 0)         AS negative_price,
    COUNT(*) FILTER (WHERE frieght_value < 0) AS negative_frieght,
    COUNT(*) FILTER (WHERE price = 0)         AS zero_price_items
FROM order_items;


-- ============================================================
-- SECTION 5: DATA QUALITY — ORDERS WITHOUT PAYMENTS
-- ============================================================

-- 5.1 Count orders with no matching payment record
-- Result: 1 order without payment
SELECT COUNT(*) AS order_without_payment
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- 5.2 Retrieve the specific order(s) without payment
-- Result: order_id = bfbd0f9bdef84302105ad712db648a6c
SELECT o.*
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;


-- ============================================================
-- SECTION 6: FINANCIAL DISCREPANCY ANALYSIS
-- ============================================================

-- 6.1 Spot check: expected revenue for the identified order
-- Result: 143.46
SELECT
    SUM(price + frieght_value) AS expected_revenue
FROM order_items
WHERE order_id = 'bfbd0f9bdef84302105ad712db648a6c';

-- 6.2 Naive mismatch count using triple JOIN (inflated due to many-to-many)
-- Result: 12,500 (incorrect — many-to-many join issue)
SELECT COUNT(*) AS mismatched_orders
FROM (
    SELECT
        o.order_id,
        SUM(oi.price + oi.frieght_value) AS total_order_value,
        SUM(p.payment_value)             AS total_payment_value
    FROM orders o
    LEFT JOIN order_items oi    ON o.order_id = oi.order_id
    LEFT JOIN order_payments p  ON o.order_id = p.order_id
    GROUP BY o.order_id
) t
WHERE ROUND(total_order_value, 2) <> ROUND(total_payment_value, 2);

-- 6.3 Correct mismatch count using separate CTEs (avoids many-to-many)
-- Result: 576 mismatched orders
WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + frieght_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT COUNT(*) AS mismatched_orders
FROM item_totals i
LEFT JOIN payment_totals p ON i.order_id = p.order_id
WHERE ROUND(i.total_order_value, 2) <> ROUND(p.total_payment_value, 2);

-- 6.4 Mismatch count + total absolute difference
-- Result: 576 mismatched orders | 3,271.95 total absolute difference
WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + frieght_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS mismatched_orders,
    ROUND(SUM(ABS(i.total_order_value - p.total_payment_value)), 2) AS total_absolute_difference
FROM item_totals i
LEFT JOIN payment_totals p ON i.order_id = p.order_id
WHERE ROUND(i.total_order_value, 2) <> ROUND(p.total_payment_value, 2);

-- 6.5 Total platform revenue from payments
-- Result: 16,008,872.12
SELECT ROUND(SUM(payment_value), 2) AS total_revenue
FROM order_payments;


-- ============================================================
-- SECTION 7: REVIEW DATA QUALITY
-- ============================================================

-- 7.1 Check for invalid review scores (outside 1–5 range)
-- Result: 0 invalid scores
SELECT COUNT(*) FILTER (WHERE review_score < 1 OR review_score > 5) AS invalid_review_score
FROM orders_reviews;

-- 7.2 Reviews written before delivery was made to customer
SELECT
    COUNT(*) FILTER (WHERE r.review_creation_date < o.order_delivered_customer_date) AS review_before_delivery
FROM orders o
LEFT JOIN orders_reviews r ON o.order_id = r.order_id;

-- 7.3 Average hours between review creation and delivery date
-- (where review was written before delivery)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - r.review_creation_date)) / 3600), 2)
    AS avg_hours_difference
FROM orders_reviews r
JOIN orders o ON r.order_id = o.order_id
WHERE r.review_creation_date < o.order_delivered_customer_date;

-- 7.4 Reviews written before carrier pickup date
SELECT
    COUNT(*) FILTER (WHERE r.review_creation_date < o.order_delivered_carrier_date) AS review_before_carrier
FROM orders_reviews r
JOIN orders o ON r.order_id = o.order_id;

-- 7.5 Delivered orders with no review at all
SELECT COUNT(*) AS delivered_without_review
FROM (
    SELECT o.order_id
    FROM orders o
    LEFT JOIN orders_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
    HAVING COUNT(r.review_id) = 0
) t;

-- 7.6 Total delivered orders (baseline for above)
SELECT COUNT(*) AS delivered_orders
FROM orders
WHERE order_status = 'delivered';


-- ============================================================
-- SECTION 8: QUERY PERFORMANCE OPTIMIZATION
-- ============================================================

-- 8.1 Baseline query plan (before indexes)
EXPLAIN ANALYZE
WITH item_totals AS (
    SELECT order_id, SUM(price + frieght_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT COUNT(*)
FROM item_totals i
JOIN payment_totals p ON i.order_id = p.order_id
WHERE ROUND(i.total_order_value, 2) <> ROUND(p.total_payment_value, 2);

-- 8.2 Same query using ABS threshold (alternative approach)
EXPLAIN ANALYZE
WITH item_totals AS (
    SELECT order_id, SUM(price + frieght_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT COUNT(*)
FROM item_totals i
JOIN payment_totals p ON i.order_id = p.order_id
WHERE ABS(i.total_order_value - p.total_payment_value) > 0.01;

-- 8.3 Create indexes to improve join performance
CREATE INDEX idx_order_items_order_id    ON order_items(order_id);
CREATE INDEX idx_order_payments_order_id ON order_payments(order_id);

-- 8.4 Re-run query after indexes to compare plan
EXPLAIN ANALYZE
WITH item_totals AS (
    SELECT order_id, SUM(price + frieght_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT COUNT(*)
FROM item_totals i
JOIN payment_totals p ON i.order_id = p.order_id
WHERE ABS(i.total_order_value - p.total_payment_value) > 0.01;

-- 8.5 Create materialized views for further optimization
CREATE MATERIALIZED VIEW order_item_totals AS
SELECT
    order_id,
    SUM(price + frieght_value) AS total_order_value
FROM order_items
GROUP BY order_id;

CREATE MATERIALIZED VIEW order_payment_totals AS
SELECT
    order_id,
    SUM(payment_value) AS total_payment_value
FROM order_payments
GROUP BY order_id;

-- 8.6 Query using materialized views (fastest plan)
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM order_item_totals i
JOIN order_payment_totals p ON i.order_id = p.order_id
WHERE ABS(i.total_order_value - p.total_payment_value) > 0.01;


-- ============================================================
-- SECTION 9: REVENUE ANALYSIS
-- ============================================================

-- 9.1 Simple total revenue
-- Result: 16,008,872.12
SELECT ROUND(SUM(payment_value), 2) AS total_revenue
FROM order_payments;

-- 9.2 Total revenue, total paid orders, average order value
WITH order_revenue AS (
    SELECT order_id, SUM(payment_value) AS order_total
    FROM order_payments
    GROUP BY order_id
)
SELECT
    ROUND(SUM(order_total), 2) AS total_revenue,
    COUNT(order_id)            AS total_paid_order,
    ROUND(AVG(order_total), 2) AS avg_order_value
FROM order_revenue;

-- 9.3 Monthly revenue, order count, and average order value
WITH order_revenue AS (
    SELECT
        o.order_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
        SUM(payment_value) AS order_total
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    GROUP BY o.order_id, purchase_month
)
SELECT
    purchase_month,
    ROUND(SUM(order_total), 2) AS monthly_revenue,
    COUNT(order_id)            AS monthly_orders,
    ROUND(AVG(order_total), 2) AS monthly_aov
FROM order_revenue
GROUP BY purchase_month
ORDER BY purchase_month;

-- 9.4 Monthly revenue with 3-month rolling average and MoM growth %
WITH monthly_metrics AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
        SUM(payment_value) AS monthly_revenue
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
),
monthly_with_lag AS (
    SELECT
        purchase_month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (ORDER BY purchase_month) AS prev_month_revenue
    FROM monthly_metrics
),
monthly_rolling AS (
    SELECT
        purchase_month,
        monthly_revenue,
        prev_month_revenue,
        ROUND(AVG(monthly_revenue) OVER (
            ORDER BY purchase_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS monthly_rolling_revenue
    FROM monthly_with_lag
)
SELECT
    purchase_month,
    monthly_rolling_revenue,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND((monthly_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0) * 100, 2) AS mom_growth_percent
FROM monthly_rolling
ORDER BY purchase_month;

-- 9.5 Monthly orders, revenue, and AOV (clean version)
WITH monthly_metrics AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
        COUNT(DISTINCT o.order_id)                       AS monthly_orders,
        SUM(p.payment_value)                             AS monthly_revenue
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    purchase_month,
    monthly_orders,
    ROUND(monthly_revenue, 2)                         AS monthly_revenue,
    ROUND(monthly_revenue / monthly_orders, 2)        AS monthly_aov
FROM monthly_metrics
ORDER BY purchase_month;


-- ============================================================
-- SECTION 10: CUSTOMER RETENTION ANALYSIS
-- ============================================================

-- 10.1 Repeat customer rate
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                                                                          AS total_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)                                                AS repeat_customers,
    ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2)            AS repeat_rate_percent
FROM customer_orders;

-- 10.2 Revenue from repeat customers vs all customers
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(p.payment_value)       AS total_revenue
    FROM orders o
    JOIN customers c        ON o.customer_id = c.customer_id
    JOIN order_payments p   ON o.order_id = p.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    ROUND(SUM(total_revenue), 2)                                                                         AS total_revenue_all,
    ROUND(SUM(CASE WHEN total_orders > 1 THEN total_revenue ELSE 0 END), 2)                              AS repeat_customer_revenue,
    ROUND(SUM(CASE WHEN total_orders > 1 THEN total_revenue ELSE 0 END) / SUM(total_revenue) * 100, 2)  AS repeat_revenue_percent
FROM customer_revenue;

-- 10.3 Average spend: one-time vs repeat customers
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(p.payment_value)       AS total_revenue
    FROM orders o
    JOIN customers c        ON o.customer_id = c.customer_id
    JOIN order_payments p   ON o.order_id = p.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    ROUND(AVG(CASE WHEN total_orders = 1 THEN total_revenue END), 2) AS avg_spend_onetime,
    ROUND(AVG(CASE WHEN total_orders > 1 THEN total_revenue END), 2) AS avg_spend_repeat_customer
FROM customer_revenue;


-- ============================================================
-- SECTION 11: COHORT ANALYSIS
-- ============================================================

-- 11.1 First purchase month per customer
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(DATE_TRUNC('month', o.order_purchase_timestamp)) AS first_purchase_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT *
FROM first_purchase
ORDER BY first_purchase_month;

-- 11.2 Cohort sizes by first purchase month
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(DATE_TRUNC('month', o.order_purchase_timestamp)) AS first_purchase_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    first_purchase_month,
    COUNT(*) AS cohort_size
FROM first_purchase
GROUP BY first_purchase_month
ORDER BY first_purchase_month;

-- 11.3 Full cohort retention: active customers per cohort per month number
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(DATE_TRUNC('month', o.order_purchase_timestamp)) AS cohort_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
customer_activity AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
),
cohort_raw AS (
    SELECT
        f.customer_unique_id,
        f.cohort_month,
        a.activity_month,
        EXTRACT(YEAR  FROM AGE(a.activity_month, f.cohort_month)) * 12 +
        EXTRACT(MONTH FROM AGE(a.activity_month, f.cohort_month))    AS month_number
    FROM first_purchase f
    JOIN customer_activity a ON f.customer_unique_id = a.customer_unique_id
)
SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_unique_id) AS active_customers
FROM cohort_raw
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;


-- ============================================================
-- SECTION 12: PARETO ANALYSIS (80/20 RULE)
-- ============================================================

-- 12.1 What % of customers drive 80% of revenue?
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(p.payment_value) AS total_revenue
    FROM orders o
    JOIN customers c        ON o.customer_id = c.customer_id
    JOIN order_payments p   ON o.order_id = p.order_id
    GROUP BY c.customer_unique_id
),
ranked_customers AS (
    SELECT
        customer_unique_id,
        total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER ()                             AS total_revenue_all
    FROM customer_revenue
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN cumulative_revenue <= total_revenue_all * 0.8 THEN 1 END) AS customers_contributing_80pct,
    ROUND(
        SUM(CASE WHEN cumulative_revenue <= total_revenue_all * 0.8 THEN 1 END)::NUMERIC
        / COUNT(*) * 100, 2
    ) AS percent_customers_of_80pct_revenue
FROM ranked_customers;

-- 12.2 What % of categories drive 80% of revenue?
WITH category_revenue AS (
    SELECT
        ct.product_category_name_english,
        SUM(oi.price + oi.frieght_value) AS total_revenue
    FROM order_items oi
    JOIN products p              ON oi.product_id = p.product_id
    JOIN category_transalation ct ON p.product_category_name = ct.product_category_name
    GROUP BY ct.product_category_name_english
),
ranked_categories AS (
    SELECT
        product_category_name_english,
        total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER ()                             AS total_revenue_all
    FROM category_revenue
),
category_with_percent AS (
    SELECT
        *,
        cumulative_revenue / total_revenue_all AS cumulative_percent
    FROM ranked_categories
)
SELECT
    COUNT(*) AS total_categories,
    COUNT(*) FILTER (WHERE cumulative_percent <= 0.8)  AS categories_for_80pct_revenue,
    ROUND(
        COUNT(*) FILTER (WHERE cumulative_percent <= 0.8)::NUMERIC / COUNT(*) * 100, 2
    ) AS percent_categories_80pct
FROM category_with_percent;


-- ============================================================
-- SECTION 13: CATEGORY-BASED RETENTION ANALYSIS
-- ============================================================

-- 13.1 Repeat customer rate per product category
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
category_customers AS (
    SELECT
        ct.product_category_name_english AS category,
        c.customer_unique_id
    FROM orders o
    JOIN customers c              ON o.customer_id = c.customer_id
    JOIN order_items oi           ON o.order_id = oi.order_id
    JOIN products p               ON oi.product_id = p.product_id
    JOIN category_transalation ct ON p.product_category_name = ct.product_category_name
    GROUP BY ct.product_category_name_english, c.customer_unique_id
),
category_repeat_analysis AS (
    SELECT
        cc.category,
        COUNT(*)                                               AS total_customers,
        SUM(CASE WHEN co.total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers
    FROM customer_orders co
    JOIN category_customers cc ON co.customer_unique_id = cc.customer_unique_id
    GROUP BY cc.category
)
SELECT
    category,
    total_customers,
    repeat_customers,
    ROUND(repeat_customers::NUMERIC / total_customers * 100, 2) AS repeat_customer_percent
FROM category_repeat_analysis
ORDER BY repeat_customer_percent DESC;


-- ============================================================
-- SECTION 14: STRATEGIC TARGET — GROW REPEAT CUSTOMER BASE
-- ============================================================

-- 14.1 Current state + what 5% repeat rate target means in revenue
WITH base_metrics AS (
    SELECT
        COUNT(*)                                                          AS total_customers,
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)                AS repeat_customers,
        AVG(CASE WHEN total_orders > 1 THEN total_revenue END)           AS avg_repeat_revenue
    FROM (
        SELECT
            c.customer_unique_id,
            COUNT(DISTINCT o.order_id) AS total_orders,
            SUM(p.payment_value)       AS total_revenue
        FROM orders o
        JOIN customers c        ON o.customer_id = c.customer_id
        JOIN order_payments p   ON o.order_id = p.order_id
        GROUP BY c.customer_unique_id
    ) t
)
SELECT
    total_customers,
    repeat_customers,
    ROUND(repeat_customers::NUMERIC / total_customers * 100, 2) AS current_repeat_percent,
    ROUND(avg_repeat_revenue, 2)                                AS avg_repeat_revenue,
    ROUND(total_customers * 0.05, 2)                            AS target_repeat_customers,
    ROUND(
        (total_customers * 0.05 - repeat_customers) * avg_repeat_revenue, 2
    )                                                           AS additional_repeat_revenue_if_5pct
FROM base_metrics;


-- ============================================================
-- END OF PROJECT
-- ============================================================
