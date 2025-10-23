DROP TABLE IF EXISTS silver.fact_reviews CASCADE;

CREATE TABLE IF NOT EXISTS silver.fact_reviews (
    review_id SERIAL PRIMARY KEY,
    review_hash TEXT UNIQUE NOT NULL,
    product_key BIGINT NOT NULL REFERENCES silver.dim_products(product_key),
    user_key BIGINT NOT NULL REFERENCES silver.dim_users(user_key),
    time_key BIGINT NOT NULL REFERENCES silver.dim_time(time_key),
    rating SMALLINT,
    helpful TEXT,
    review_text TEXT,
    summary TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_silver_fact_reviews_review_hash
    ON silver.fact_reviews(review_hash);

CREATE INDEX IF NOT EXISTS idx_silver_fact_reviews_product_key
    ON silver.fact_reviews(product_key);

CREATE INDEX IF NOT EXISTS idx_silver_fact_reviews_user_key
    ON silver.fact_reviews(user_key);

CREATE INDEX IF NOT EXISTS idx_silver_fact_reviews_time_key
    ON silver.fact_reviews(time_key);
