drop table if exists bronze.dq_checks;

CREATE TABLE IF NOT EXISTS bronze.dq_checks (
    check_id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    check_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    rows_total INT NOT NULL,
    rows_valid INT NOT NULL,
    rows_flagged INT NOT NULL,
    check_type TEXT NOT null,
    filename TEXT not null
);
