-- DROP PROCEDURE IF EXISTS silver.sp_load_dim_time();

CREATE OR REPLACE PROCEDURE silver.sp_load_dim_time()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_inserted INT := 0;
    v_updated INT := 0;  
BEGIN
    -- 1. Insert new timestamps (SCD Type 1)
    WITH inserted AS (
        INSERT INTO silver.dim_time (
            review_timestamp,
            review_date,
            "year",
            quarter,
            "month",
            month_name,
            "day",
            weekday,
            weekday_name,
            week_of_year,
            unix_review_time
        )
        SELECT DISTINCT
            to_timestamp(unixreviewtime)::timestamptz AS review_timestamp,
            (to_timestamp(unixreviewtime)::timestamptz)::date AS review_date,
            EXTRACT(YEAR FROM to_timestamp(unixreviewtime)::timestamptz)::int AS "year",
            EXTRACT(QUARTER FROM to_timestamp(unixreviewtime)::timestamptz)::int AS quarter,
            EXTRACT(MONTH FROM to_timestamp(unixreviewtime)::timestamptz)::int AS "month",
            TRIM(TO_CHAR(to_timestamp(unixreviewtime)::timestamptz, 'Month')) AS month_name,
            EXTRACT(DAY FROM to_timestamp(unixreviewtime)::timestamptz)::int AS "day",
            EXTRACT(DOW FROM to_timestamp(unixreviewtime)::timestamptz)::int AS weekday,
            TRIM(TO_CHAR(to_timestamp(unixreviewtime)::timestamptz, 'Day')) AS weekday_name,
            TO_NUMBER(TO_CHAR(to_timestamp(unixreviewtime)::timestamptz, 'IW'), '99') AS week_of_year,
            unixreviewtime AS unix_review_time
        FROM post_bronze.reviews r
        WHERE unixreviewtime IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM silver.dim_time t
              WHERE t.review_timestamp = to_timestamp(r.unixreviewtime)::timestamptz
          )
        RETURNING 1 AS inserted_flag
    )
    SELECT COALESCE(COUNT(*), 0) INTO v_inserted
    FROM inserted;


    -- 2. Audit log
    INSERT INTO silver.etl_audit_log (
        procedure_name,
        load_timestamp,
        rows_inserted,
        rows_updated,
        status
    )
    VALUES (
        'silver.sp_load_dim_time',
        NOW(),
        v_inserted,
        v_updated,
        'success'
    );

    RAISE NOTICE 'Load complete for silver.dim_time: % inserted, % updated', v_inserted, v_updated;

EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO silver.etl_audit_log (
            procedure_name,
            load_timestamp,
            rows_inserted,
            rows_updated,
            status
        )
        VALUES (
            'silver.sp_load_dim_time',
            NOW(),
            v_inserted,
            v_updated,
            'failure'
        );
        RAISE NOTICE 'Error during silver.sp_load_dim_time: %', SQLERRM;
END;
$procedure$;
