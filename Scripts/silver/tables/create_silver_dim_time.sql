DROP TABLE IF EXISTS silver.dim_time cascade;

CREATE TABLE silver.dim_time (
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
create UNIQUE INDEX IF NOT EXISTS idx_dim_time_unix_review_time
    ON silver.dim_time(unix_review_time);

CREATE unique INDEX IF NOT EXISTS idx_dim_time_review_timestamp
    ON silver.dim_time(review_timestamp);
