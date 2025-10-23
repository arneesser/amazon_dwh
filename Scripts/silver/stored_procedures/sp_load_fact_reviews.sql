-- DROP PROCEDURE IF EXISTS silver.sp_load_fact_reviews();

CREATE OR REPLACE PROCEDURE silver.sp_load_fact_reviews()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_inserted INT := 0;
    v_updated INT := 0;
BEGIN
    -- STEP 1: Insert new reviews (SCD1 insert)
    WITH inserted AS (
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
            md5(r.reviewerid || r.unixreviewtime || r.asin || r.reviewtext || r.overall::TEXT || r.summary) AS review_hash,
            p.product_key,
            u.user_key,
            t.time_key,
            r.overall::SMALLINT AS rating,
            r.helpful,
            r.reviewtext,
            r.summary
        FROM post_bronze.reviews r
        JOIN silver.dim_products p ON r.asin = p.asin
        JOIN silver.dim_time t ON r.unixreviewtime = t.unix_review_time
        JOIN silver.dim_users u ON r.reviewerid = u.reviewer_id
        LEFT JOIN silver.fact_reviews f 
            ON f.review_hash = md5(r.reviewerid || r.unixreviewtime || r.asin || r.reviewtext || r.overall::TEXT || r.summary)
        WHERE f.review_hash IS NULL
        RETURNING 1 AS inserted_flag
    )
    SELECT COALESCE(COUNT(*), 0) INTO v_inserted
    FROM inserted;

    -- STEP 2: Update existing reviews if any data changed (SCD Type 1)
    WITH updated AS (
        UPDATE silver.fact_reviews f
        SET
            product_key = p.product_key,
            user_key = u.user_key,
            time_key = t.time_key,
            rating = r.overall::SMALLINT,
            helpful = r.helpful,
            review_text = r.reviewtext,
            summary = r.summary
        FROM post_bronze.reviews r
        JOIN silver.dim_products p ON r.asin = p.asin
        JOIN silver.dim_time t ON r.unixreviewtime = t.unix_review_time
        JOIN silver.dim_users u ON r.reviewerid = u.reviewer_id
        WHERE f.review_hash = md5(r.reviewerid || r.unixreviewtime || r.asin || r.reviewtext || r.overall::TEXT || r.summary)
          AND (
              f.rating IS DISTINCT FROM r.overall::SMALLINT OR
              f.helpful IS DISTINCT FROM r.helpful OR
              f.review_text IS DISTINCT FROM r.reviewtext OR
              f.summary IS DISTINCT FROM r.summary OR
              f.product_key IS DISTINCT FROM p.product_key OR
              f.user_key IS DISTINCT FROM u.user_key OR
              f.time_key IS DISTINCT FROM t.time_key
          )
        RETURNING 1 AS updated_flag
    )
    SELECT COALESCE(COUNT(*), 0) INTO v_updated
    FROM updated;

    -- STEP 3: Audit log
    INSERT INTO silver.etl_audit_log (
        procedure_name,
        load_timestamp,
        rows_inserted,
        rows_updated,
        status
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
            procedure_name,
            load_timestamp,
            rows_inserted,
            rows_updated,
            status
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
