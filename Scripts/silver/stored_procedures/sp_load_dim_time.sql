-- DROP PROCEDURE IF EXISTS silver.sp_load_dim_time;

CREATE OR REPLACE PROCEDURE silver.sp_load_dim_time()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_inserted INT := 0;
BEGIN
    -- Step 1: Identify new timestamps directly
    WITH new_timestamps AS (
        SELECT
            r.unixreviewtime,
            to_timestamp(r.unixreviewtime)::timestamptz AS review_timestamp,
            to_timestamp(r.unixreviewtime)::date AS review_date,
            EXTRACT(YEAR FROM to_timestamp(r.unixreviewtime))::int AS year,
            EXTRACT(QUARTER FROM to_timestamp(r.unixreviewtime))::int AS quarter,
            EXTRACT(MONTH FROM to_timestamp(r.unixreviewtime))::int AS month,
            TRIM(TO_CHAR(to_timestamp(r.unixreviewtime), 'Month')) AS month_name,
            EXTRACT(DAY FROM to_timestamp(r.unixreviewtime))::int AS day,
            EXTRACT(DOW FROM to_timestamp(r.unixreviewtime))::int AS weekday,
            TRIM(TO_CHAR(to_timestamp(r.unixreviewtime), 'Day')) AS weekday_name,
            TO_NUMBER(TO_CHAR(to_timestamp(r.unixreviewtime), 'IW'), '99') AS week_of_year
        FROM post_bronze.reviews r
        LEFT JOIN silver.dim_time t
            ON t.unix_review_time = r.unixreviewtime
        WHERE t.unix_review_time IS NULL
        GROUP BY r.unixreviewtime
    )
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
    SELECT
        review_timestamp,
        review_date,
        year,
        quarter,
        month,
        month_name,
        day,
        weekday,
        weekday_name,
        week_of_year,
        unixreviewtime
    FROM new_timestamps
    ON CONFLICT (unix_review_time) DO NOTHING;

    -- Step 2: Capture number of inserted rows
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    -- Step 3: Audit log
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
        0,
        CASE WHEN v_inserted = 0 THEN 'no_changes' ELSE 'success' END
    );

    RAISE NOTICE 'Load complete for silver.dim_time: % inserted, 0 updated', v_inserted;

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
            COALESCE(v_inserted, 0),
            0,
            'failure'
        );
        RAISE NOTICE 'Error during silver.sp_load_dim_time: %', SQLERRM;
END;
$procedure$;
