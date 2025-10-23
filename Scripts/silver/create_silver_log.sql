drop table if exists silver.etl_audit_log;

CREATE TABLE IF NOT EXISTS silver.etl_audit_log (
        id SERIAL PRIMARY KEY,
        procedure_name TEXT,
        load_timestamp TIMESTAMPTZ DEFAULT NOW(),
        rows_inserted INT,
        rows_updated INT,
        status TEXT
    );