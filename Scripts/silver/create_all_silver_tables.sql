-- =========================================
-- Table: silver.dim_products
-- =========================================
DROP TABLE IF EXISTS silver.dim_products CASCADE;

CREATE TABLE IF NOT EXISTS silver.dim_products (
    product_key SERIAL PRIMARY KEY,
    metadataid TEXT,
    asin TEXT UNIQUE NOT NULL,
    category TEXT,
    salesrank JSONB,
    imurl TEXT,
    categories JSONB,
    title TEXT,
    description TEXT,
    price NUMERIC(10,2),
    related JSONB,
    brand TEXT
);

-- Unique index on asin
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_products_asin
    ON silver.dim_products(asin);

-- =========================================
-- Table: silver.dim_time
-- =========================================
DROP TABLE IF EXISTS silver.dim_time CASCADE;

CREATE TABLE IF NOT EXISTS silver.dim_time (
    time_key SERIAL PRIMARY KEY,
    review_timestamp TIMESTAMPTZ,
    review_date DATE,
    "year" INT,
    quarter INT,
    month INT,
    month_name TEXT,
    day INT,
    weekday INT,
    weekday_name TEXT,
    week_of_year INT,
    unix_review_time BIGINT NOT NULL UNIQUE
);

-- Indexes for faster lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_time_unix_review_time
    ON silver.dim_time(unix_review_time);

CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_time_review_timestamp
    ON silver.dim_time(review_timestamp);

-- =========================================
-- Table: silver.dim_users
-- =========================================
DROP TABLE IF EXISTS silver.dim_users CASCADE;

CREATE TABLE IF NOT EXISTS silver.dim_users (
    user_key SERIAL PRIMARY KEY,
    reviewer_id TEXT NOT NULL,
    reviewer_name TEXT
);

-- Index for fast joins/lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_users_reviewer_id
    ON silver.dim_users(reviewer_id);

-- =========================================
-- Table: silver.fact_reviews
-- =========================================
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

-- Indexes for faster joins
CREATE UNIQUE INDEX IF NOT EXISTS idx_silver_fact_reviews_review_hash
    ON silver.fact_reviews(review_hash);

CREATE INDEX IF NOT EXISTS idx_silver_fact_reviews_product_key
    ON silver.fact_reviews(product_key);

CREATE INDEX IF NOT EXISTS idx_silver_fact_reviews_user_key
    ON silver.fact_reviews(user_key);

CREATE INDEX IF NOT EXISTS idx_silver_fact_reviews_time_key
    ON silver.fact_reviews(time_key);

-- =========================================
-- Table: silver.etl_audit_log
-- =========================================
DROP TABLE IF EXISTS silver.etl_audit_log;

CREATE TABLE IF NOT EXISTS silver.etl_audit_log (
    id SERIAL PRIMARY KEY,
    procedure_name TEXT,
    load_timestamp TIMESTAMPTZ DEFAULT NOW(),
    rows_inserted INT,
    rows_updated INT,
    status TEXT
);
