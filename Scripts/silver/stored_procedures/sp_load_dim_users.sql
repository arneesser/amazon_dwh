-- DROP PROCEDURE IF EXISTS silver.sp_load_dim_users();

CREATE OR REPLACE PROCEDURE silver.sp_load_dim_users()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_inserted INT := 0;
    v_updated  INT := 0;
BEGIN
    /*
      STEP 0: Deduplicate reviewer records from post_bronze.reviews
      -------------------------------------------------------------
      - Keep only one row per reviewer_id
      - Prefer rows where reviewer_name is NOT NULL or NOT empty
      - If multiple remain, take the most recent by unixreviewtime
    */
    CREATE TEMP TABLE tmp_deduped AS
    WITH ranked AS (
        SELECT
            reviewerid AS reviewer_id,
            NULLIF(TRIM(reviewername), '') AS reviewer_name,
            unixreviewtime,
            ROW_NUMBER() OVER (
                PARTITION BY reviewerid
                ORDER BY
                    CASE 
                        WHEN NULLIF(TRIM(reviewername), '') IS NOT NULL THEN 0 ELSE 1
                    END,
                    unixreviewtime DESC
            ) AS rn
        FROM post_bronze.reviews
        WHERE reviewerid IS NOT NULL
    )
    SELECT
        reviewer_id,
        reviewer_name 
    FROM ranked
    WHERE rn = 1;

    RAISE NOTICE 'Temporary deduplicated user table created.';

    /*
      STEP 1: Insert new users (not yet in dim_users)
    */
    WITH inserted AS (
        INSERT INTO silver.dim_users (reviewer_id, reviewer_name)
        SELECT d.reviewer_id, d.reviewer_name
        FROM tmp_deduped d
        LEFT JOIN silver.dim_users u
               ON u.reviewer_id = d.reviewer_id
        WHERE u.reviewer_id IS NULL
        RETURNING 1 AS inserted_flag
    )
    SELECT COALESCE(COUNT(*), 0) INTO v_inserted
    FROM inserted;

    /*
      STEP 2: Update existing users if reviewer_name changed
    */
    WITH updated AS (
        UPDATE silver.dim_users u
        SET reviewer_name = d.reviewer_name
        FROM tmp_deduped d
        WHERE u.reviewer_id = d.reviewer_id
          AND u.reviewer_name IS DISTINCT FROM d.reviewer_name
        RETURNING 1 AS updated_flag
    )
    SELECT COALESCE(COUNT(*), 0) INTO v_updated
    FROM updated;

    /*
      STEP 3: Clean up and log
    */
    DROP TABLE IF EXISTS tmp_deduped;

    INSERT INTO silver.etl_audit_log (
        procedure_name,
        load_timestamp,
        rows_inserted,
        rows_updated,
        status
    )
    VALUES (
        'silver.sp_load_dim_users',
        NOW(),
        v_inserted,
        v_updated,
        CASE
            WHEN v_inserted = 0 AND v_updated = 0 THEN 'no_changes'
            ELSE 'success'
        END
    );

    RAISE NOTICE 'Dim Users Load Complete: % inserted, % updated', v_inserted, v_updated;

EXCEPTION
    WHEN OTHERS THEN
        -- Ensure cleanup on failure
        DROP TABLE IF EXISTS tmp_deduped;

        INSERT INTO silver.etl_audit_log (
            procedure_name,
            load_timestamp,
            rows_inserted,
            rows_updated,
            status
        )
        VALUES (
            'silver.sp_load_dim_users',
            NOW(),
            v_inserted,
            v_updated,
            'failure'
        );

        RAISE NOTICE 'Error during silver.sp_load_dim_users: %', SQLERRM;
END;
$procedure$;
