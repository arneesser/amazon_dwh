drop view if exists  gold.v_top_reviews_month;

CREATE OR REPLACE VIEW gold.v_top_reviews_month AS
SELECT
    p.brand,
    t.year,
    t.month,
    t.month_name,
    COUNT(*) AS total_reviews,
    ROUND(AVG(f.rating), 2) AS avg_rating
FROM silver.fact_reviews f
JOIN silver.dim_products p ON f.product_key = p.product_key
JOIN silver.dim_time t ON f.time_key = t.time_key
WHERE p.brand IS NOT NULL
GROUP BY p.brand, t.year, t.month, t.month_name
ORDER BY t.month, t.year, t.month_name, total_reviews DESC;
