drop table if exists bronze.etl_audit_log;

CREATE TABLE IF NOT EXISTS bronze.etl_audit_log (
        id SERIAL PRIMARY KEY,
        schema_name TEXT,
        table_name TEXT,
        load_timestamp TIMESTAMPTZ DEFAULT NOW(),
        filename TEXT,
        row_count INT,
        status TEXT
);