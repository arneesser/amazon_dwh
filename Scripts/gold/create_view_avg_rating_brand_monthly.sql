DROP VIEW IF EXISTS gold.v_avg_rating_per_brand_month;

CREATE OR REPLACE VIEW gold.v_avg_rating_per_brand_month AS
SELECT
    p.brand,
    t.year,
    t.month,
    ROUND(AVG(f.rating), 2) AS avg_rating,
    COUNT(f.review_id) AS review_count
FROM silver.fact_reviews f
JOIN silver.dim_products p ON f.product_key = p.product_key
JOIN silver.dim_time t ON f.time_key = t.time_key
WHERE p.brand IS NOT NULL
GROUP BY p.brand, t.year, t.month
ORDER BY t.year DESC, t.month DESC, p.brand ASC;
