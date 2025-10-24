-- DROP PROCEDURE silver.sp_load_dim_products();

CREATE OR REPLACE PROCEDURE silver.sp_load_dim_products()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_inserted INT := 0;
    v_updated INT := 0;
BEGIN
    -- Step 1: Deduplicate metadata per ASIN and compute hash once
    WITH ranked AS (
        SELECT
            m.metadataid,
            m.asin,
            (SELECT key FROM jsonb_each_text(m.salesrank::JSONB) LIMIT 1) AS category,
            m.salesrank::JSONB AS salesrank,
            m.imurl,
            m.categories::JSONB AS categories,
            m.title,
            m.description,
            m.price::NUMERIC(10,2) AS price,
            m.related::JSONB AS related,
            m.brand,
            ROW_NUMBER() OVER (PARTITION BY m.asin ORDER BY m.metadataid DESC) AS rn
        FROM post_bronze.metadata m
    ),
    latest_metadata AS (
        SELECT *,
               md5(concat_ws('|', metadataid, asin, title, description, price::text, brand, imurl)) AS metadata_hash
        FROM ranked
        WHERE rn = 1
    ),
		-- Step 1: insert new rows or update based on duplicate asin and different hash
    upsert AS (
        INSERT INTO silver.dim_products (
            metadataid, asin, category, salesrank, imurl, categories,
            title, description, price, related, brand, metadata_hash
        )
        SELECT
            lm.metadataid, lm.asin, lm.category, lm.salesrank, lm.imurl, lm.categories,
            lm.title, lm.description, lm.price, lm.related, lm.brand, lm.metadata_hash
        FROM latest_metadata lm
        ON CONFLICT (asin) DO UPDATE
        SET 
            metadataid = EXCLUDED.metadataid,
            category = EXCLUDED.category,
            salesrank = EXCLUDED.salesrank,
            imurl = EXCLUDED.imurl,
            categories = EXCLUDED.categories,
            title = EXCLUDED.title,
            description = EXCLUDED.description,
            price = EXCLUDED.price,
            related = EXCLUDED.related,
            brand = EXCLUDED.brand,
            metadata_hash = EXCLUDED.metadata_hash
        WHERE silver.dim_products.metadata_hash IS DISTINCT FROM EXCLUDED.metadata_hash
        RETURNING xmax = 0 AS inserted_flag
    )
    SELECT
        COALESCE(SUM(CASE WHEN inserted_flag THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN NOT inserted_flag THEN 1 ELSE 0 END), 0)
    INTO v_inserted, v_updated
    FROM upsert;

    -- Step 2: Audit log
    INSERT INTO silver.etl_audit_log (
        procedure_name, load_timestamp, rows_inserted, rows_updated, status
    )
    VALUES ('silver.sp_load_dim_products', NOW(), v_inserted, v_updated, 'success');

    RAISE NOTICE 'Silver Dim Products Load Complete: % inserted, % updated', v_inserted, v_updated;

EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO silver.etl_audit_log (
            procedure_name, load_timestamp, rows_inserted, rows_updated, status
        )
        VALUES ('silver.sp_load_dim_products', NOW(), v_inserted, v_updated, 'failure');
        RAISE NOTICE 'Error during silver.sp_load_dim_products: %', SQLERRM;
END;
$procedure$
;
