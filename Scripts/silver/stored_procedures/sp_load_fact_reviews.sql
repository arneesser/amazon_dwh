-- DROP PROCEDURE IF EXISTS silver.sp_load_fact_reviews;

CREATE OR REPLACE PROCEDURE silver.sp_load_fact_reviews()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_inserted INT := 0;
    v_updated  INT := 0;
BEGIN
    -- STEP 1: Compute hashes and prepare review data
    WITH review_data AS (
        SELECT
            r.reviewerid,
            r.unixreviewtime,
            r.asin,
            r.reviewtext,
            r.overall::SMALLINT AS rating,
            r.helpful,
            r.summary,
            p.product_key,
            u.user_key,
            t.time_key,
            md5(r.reviewerid || r.unixreviewtime || r.asin || r.reviewtext || r.overall::TEXT || r.summary) AS review_hash
        FROM post_bronze.reviews r
        JOIN silver.dim_products p ON r.asin = p.asin
        JOIN silver.dim_users u ON r.reviewerid = u.reviewer_id
        JOIN silver.dim_time t ON r.unixreviewtime = t.unix_review_time
    ),
    -- STEP 2: Insert new reviews
    inserted AS (
        INSERT INTO silver.fact_reviews (
            review_hash,
            product_key,
            user_key,
            time_key,
            rating,
            helpful,
            review_text,
            summary
        )
        SELECT
            rd.review_hash,
            rd.product_key,
            rd.user_key,
            rd.time_key,
            rd.rating,
            rd.helpful,
            rd.reviewtext,
            rd.summary
        FROM review_data rd
        LEFT JOIN silver.fact_reviews f ON f.review_hash = rd.review_hash
        WHERE f.review_hash IS NULL
        RETURNING 1 AS inserted_flag
    ),
    -- STEP 3: Update existing reviews if any field changed
    updated AS (
        UPDATE silver.fact_reviews f
        SET
            product_key = rd.product_key,
            user_key = rd.user_key,
            time_key = rd.time_key,
            rating = rd.rating,
            helpful = rd.helpful,
            review_text = rd.reviewtext,
            summary = rd.summary
        FROM review_data rd
        WHERE f.review_hash = rd.review_hash
          AND (
              f.rating IS DISTINCT FROM rd.rating OR
              f.helpful IS DISTINCT FROM rd.helpful OR
              f.review_text IS DISTINCT FROM rd.reviewtext OR
              f.summary IS DISTINCT FROM rd.summary OR
              f.product_key IS DISTINCT FROM rd.product_key OR
              f.user_key IS DISTINCT FROM rd.user_key OR
              f.time_key IS DISTINCT FROM rd.time_key
          )
        RETURNING 1 AS updated_flag
    )
    -- STEP 4: Capture counts
    SELECT
        COALESCE(SUM(CASE WHEN i.inserted_flag = 1 THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN u.updated_flag = 1 THEN 1 ELSE 0 END), 0)
    INTO v_inserted, v_updated
    FROM inserted i
    FULL OUTER JOIN updated u ON true;

    -- STEP 5: Audit log
    INSERT INTO silver.etl_audit_log (
        procedure_name, load_timestamp, rows_inserted, rows_updated, status
    )
    VALUES (
        'silver.sp_load_fact_reviews',
        NOW(),
        v_inserted,
        v_updated,
        CASE 
            WHEN v_inserted = 0 AND v_updated = 0 THEN 'no_changes'
            ELSE 'success'
        END
    );

    RAISE NOTICE 'Fact Reviews Load Complete: % inserted, % updated', v_inserted, v_updated;

EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO silver.etl_audit_log (
            procedure_name, load_timestamp, rows_inserted, rows_updated, status
        )
        VALUES (
            'silver.sp_load_fact_reviews',
            NOW(),
            v_inserted,
            v_updated,
            'failure'
        );

        RAISE NOTICE 'Error during silver.sp_load_fact_reviews: %', SQLERRM;
END;
$procedure$;
