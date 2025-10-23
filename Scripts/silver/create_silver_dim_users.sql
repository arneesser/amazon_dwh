DROP TABLE IF EXISTS silver.dim_users cascade;

CREATE TABLE IF NOT EXISTS silver.dim_users (
    user_key SERIAL PRIMARY KEY,
    reviewer_id TEXT NOT NULL,
    reviewer_name TEXT
);

-- Index for fast joins and lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_users_reviewer_id
    ON silver.dim_users(reviewer_id);
