-- =========================================
-- Table: bronze.dq_checks
-- =========================================
DROP TABLE IF EXISTS bronze.dq_checks;

CREATE TABLE IF NOT EXISTS bronze.dq_checks (
    check_id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    check_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    rows_total INT NOT NULL,
    rows_valid INT NOT NULL,
    rows_flagged INT NOT NULL,
    check_type TEXT NOT NULL,
    filename TEXT NOT NULL
);

-- =========================================
-- Table: bronze.etl_audit_log
-- =========================================
DROP TABLE IF EXISTS bronze.etl_audit_log;

CREATE TABLE IF NOT EXISTS bronze.etl_audit_log (
    id SERIAL PRIMARY KEY,
    schema_name TEXT,
    table_name TEXT,
    load_timestamp TIMESTAMPTZ DEFAULT NOW(),
    filename TEXT,
    row_count INT,
    status TEXT
);

-- =========================================
-- Table: bronze.metadata
-- =========================================
DROP TABLE IF EXISTS bronze.metadata;

CREATE TABLE IF NOT EXISTS bronze.metadata (
    metadataid TEXT PRIMARY KEY,
    asin TEXT,
    salesrank TEXT,
    imurl TEXT,
    categories TEXT,
    title TEXT,
    description TEXT,
    price TEXT,
    related TEXT,
    brand TEXT,
    batch_timestamp TIMESTAMP,
    filename TEXT
);

-- =========================================
-- Table: bronze.reviews
-- =========================================
DROP TABLE IF EXISTS bronze.reviews;

CREATE table if not EXISTS bronze.reviews (       
    reviewerid TEXT,
    asin TEXT,
    reviewername TEXT,
    helpful TEXT,                          
    reviewText TEXT,
    overall FLOAT,
    summary TEXT,
    unixreviewtime BIGINT,
    reviewTime TEXT,
    batch_timestamp TIMESTAMP,
    filename TEXT
);
