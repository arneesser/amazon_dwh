-- DROP PROCEDURE bronze.sp_postbronze_reviews();

CREATE OR REPLACE PROCEDURE bronze.sp_postbronze_reviews()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_total INT;
    v_valid INT;
    v_flagged INT;
    v_filename TEXT;
    v_batch_ts TIMESTAMP;
    v_exists BOOLEAN;
BEGIN
    -- STEP 1: Get latest batch filename and timestamp
    SELECT filename, batch_timestamp
    INTO v_filename, v_batch_ts
    FROM bronze.reviews
    ORDER BY batch_timestamp DESC
    LIMIT 1;

    -- If no data found, skip
    IF v_filename IS NULL THEN
        RAISE NOTICE 'No records found in bronze.reviews — skipping.';
        RETURN;
    END IF;

    -- STEP 2: Check if this batch was already processed
    SELECT EXISTS (
        SELECT 1
        FROM post_bronze.reviews
        WHERE filename = v_filename
          AND batch_timestamp = v_batch_ts
        UNION
        SELECT 1
        FROM post_bronze.flagged_reviews
        WHERE filename = v_filename
          AND batch_timestamp = v_batch_ts
    ) INTO v_exists;

    IF v_exists THEN
        RAISE NOTICE 'Batch for file "%" with timestamp % already processed. Skipping load.', v_filename, v_batch_ts;
        RETURN;
    END IF;

    RAISE NOTICE 'Processing new batch for file "%" (timestamp: %)', v_filename, v_batch_ts;

    -- STEP 3: Insert valid rows
    INSERT INTO post_bronze.reviews (
        reviewerid, asin, reviewername, helpful, reviewtext, overall, summary, unixreviewtime, reviewtime, batch_timestamp, filename
    )
    SELECT
        NULLIF(reviewerid, '') AS reviewerid,
        NULLIF(asin, '') AS asin,
        NULLIF(reviewername, '') AS reviewername,
        NULLIF(helpful::text, '') AS helpful,
        NULLIF(reviewtext, '') AS reviewtext,
        overall,
        NULLIF(summary, '') AS summary,
        unixreviewtime,
        NULLIF(reviewtime, '') AS reviewtime,
        v_batch_ts AS batch_timestamp,
        v_filename
    FROM bronze.reviews
    WHERE filename = v_filename
      AND reviewerid IS NOT NULL
      AND reviewerid <> 'NaN'
      AND asin IS NOT NULL
      AND asin <> 'NaN'
      AND unixreviewtime IS NOT NULL;

    GET DIAGNOSTICS v_valid = ROW_COUNT;

    -- STEP 4: Insert flagged rows
    INSERT INTO post_bronze.flagged_reviews (
        reviewerid, asin, reviewername, helpful, reviewtext, overall, summary, unixreviewtime, reviewtime, batch_timestamp, filename
    )
    SELECT
        NULLIF(reviewerid, '') AS reviewerid,
        NULLIF(asin, '') AS asin,
        NULLIF(reviewername, '') AS reviewername,
        NULLIF(helpful::text, '') AS helpful,
        NULLIF(reviewtext, '') AS reviewtext,
        overall,
        NULLIF(summary, '') AS summary,
        unixreviewtime,
        NULLIF(reviewtime, '') AS reviewtime,
        v_batch_ts AS batch_timestamp,
        v_filename
    FROM bronze.reviews
    WHERE filename = v_filename
      AND (
            reviewerid IS NULL OR reviewerid = 'NaN'
         OR asin IS NULL OR asin = 'NaN'
         OR unixreviewtime IS NULL
      );

    GET DIAGNOSTICS v_flagged = ROW_COUNT;

    -- STEP 5: Count total rows for this batch
    SELECT COUNT(*) INTO v_total
    FROM bronze.reviews
    WHERE filename = v_filename;

    -- STEP 6: Insert DQ audit record
    INSERT INTO bronze.dq_checks (
        table_name, rows_total, rows_valid, rows_flagged, check_type, filename
    )
    VALUES (
        'reviews',
        v_total,
        v_valid,
        v_flagged,
        'post_bronze_reviews',
        v_filename
    );

    RAISE NOTICE 'Post-Bronze Reviews DQ complete for "%": Total=%, Valid=%, Flagged=%',
        v_filename, v_total, v_valid, v_flagged;

END;
$procedure$
;
