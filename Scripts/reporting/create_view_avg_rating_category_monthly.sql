drop view if exists  gold.v_avg_rating_per_category_month;

CREATE OR REPLACE VIEW gold.v_avg_rating_per_category_month AS
SELECT
    p.category,
    t.year,
    t.month,
    ROUND(AVG(f.rating), 2) AS avg_rating,
    COUNT(f.review_id) AS review_count
FROM silver.fact_reviews f
JOIN silver.dim_products p ON f.product_key = p.product_key
JOIN silver.dim_time t ON f.time_key = t.time_key
WHERE p.category IS NOT NULL
GROUP BY p.category, t.year, t.month
ORDER BY t.year DESC, t.month DESC, p.category ASC;
