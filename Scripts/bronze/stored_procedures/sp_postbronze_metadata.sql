-- DROP PROCEDURE bronze.sp_postbronze_metadata();

CREATE OR REPLACE PROCEDURE bronze.sp_postbronze_metadata()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_total INT;
    v_valid INT;
    v_flagged INT;
    v_filename TEXT;
    v_latest_ts TIMESTAMP;
    v_exists BOOLEAN;
BEGIN
    -- Capture the latest filename and batch timestamp from bronze safely
    SELECT filename, batch_timestamp
    INTO v_filename, v_latest_ts
    FROM bronze.metadata
    ORDER BY batch_timestamp DESC
    LIMIT 1;

    -- If no data found, skip
    IF v_filename IS NULL THEN
        RAISE NOTICE 'No records found in bronze.metadata — skipping.';
        RETURN;
    END IF;

    -- Check if this batch was already processed (by filename + timestamp)
    SELECT EXISTS (
        SELECT 1
        FROM post_bronze.metadata
        WHERE filename = v_filename
          AND batch_timestamp::timestamp = v_latest_ts
        UNION
        SELECT 1
        FROM post_bronze.flagged_metadata
        WHERE filename = v_filename
          AND batch_timestamp::timestamp = v_latest_ts
    )
    INTO v_exists;

    IF v_exists THEN
        RAISE NOTICE 'Batch for file "%" with timestamp % already processed. Skipping load.', v_filename, v_latest_ts;
        RETURN;
    END IF;

    -- Step 1: Insert valid rows
    INSERT INTO post_bronze.metadata (
        metadataid, asin, salesrank, imurl, categories, title, description,
        price, related, brand, batch_timestamp, filename
    )
    SELECT
        metadataid,
        asin,
        CASE WHEN TRIM(salesrank) IS NULL OR salesrank = '{}' THEN NULL ELSE salesrank::jsonb END AS salesrank,
        NULLIF(TRIM(imurl), '') AS imurl,
        CASE WHEN TRIM(categories) IS NULL OR categories = '[]' THEN NULL ELSE categories::jsonb END AS categories,
        NULLIF(TRIM(title), '') AS title,
        NULLIF(TRIM(description), '') AS description,
        CAST(NULLIF(price, '') AS NUMERIC(10,2)) AS price,
        CASE WHEN TRIM(related) IS NULL OR related = '{}' THEN NULL ELSE related::jsonb END AS related,
        NULLIF(TRIM(brand), '') AS brand,
        v_latest_ts AS batch_timestamp,
        v_filename
    FROM bronze.metadata
    WHERE metadataid ~ '^\d+$'
      AND NULLIF(TRIM(asin), '') IS NOT NULL;

    GET DIAGNOSTICS v_valid = ROW_COUNT;

    -- Step 2: Insert flagged rows
    INSERT INTO post_bronze.flagged_metadata (
        metadataid, asin, salesrank, imurl, categories, title, description,
        price, related, brand, batch_timestamp, filename
    )
    SELECT
        metadataid,
        asin,
        CASE WHEN TRIM(salesrank) IS NULL OR salesrank = '{}' THEN NULL ELSE salesrank::jsonb END AS salesrank,
        NULLIF(TRIM(imurl), '') AS imurl,
        CASE WHEN TRIM(categories) IS NULL OR categories = '[]' THEN NULL ELSE categories::jsonb END AS categories,
        NULLIF(TRIM(title), '') AS title,
        NULLIF(TRIM(description), '') AS description,
        CAST(NULLIF(price, '') AS NUMERIC(10,2)) AS price,
        CASE WHEN TRIM(related) IS NULL OR related = '{}' THEN NULL ELSE related::jsonb END AS related,
        NULLIF(TRIM(brand), '') AS brand,
        v_latest_ts AS batch_timestamp,
        v_filename
    FROM bronze.metadata
    WHERE metadataid !~ '^\d+$'
       OR NULLIF(TRIM(asin), '') IS NULL;

    GET DIAGNOSTICS v_flagged = ROW_COUNT;

    -- Step 3: Total rows in source
    SELECT COUNT(*) INTO v_total FROM bronze.metadata;

    -- Step 4: Insert DQ audit log
    INSERT INTO bronze.dq_checks (
        table_name,
        rows_total,
        rows_valid,
        rows_flagged,
        check_type,
        filename
    )
    VALUES (
        'metadata',
        v_total,
        v_valid,
        v_flagged,
        'post_bronze_metadata',
        v_filename
    );

    RAISE NOTICE 'Post-Bronze Metadata DQ complete. Total: %, Valid: %, Flagged: %',
        v_total, v_valid, v_flagged;

END;
$procedure$
;
