-- DROP PROCEDURE silver.sp_load_dim_products();

CREATE OR REPLACE PROCEDURE silver.sp_load_dim_products()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_inserted INT := 0;
    v_updated INT := 0;
BEGIN
    -- 1. Insert new rows (deduplicated by asin)
    INSERT INTO silver.dim_products (
        metadataid, asin, category, salesrank, imurl, categories, title,
        description, price, related, brand
    )
    SELECT 
        sub.metadataid,
        sub.asin,
        sub.category,
        sub.salesrank,
        sub.imurl,
        sub.categories,
        sub.title,
        sub.description,
        sub.price,
        sub.related,
        sub.brand
    FROM (
        SELECT DISTINCT ON (m.asin)
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
            m.brand
        FROM post_bronze.metadata m
        ORDER BY m.asin, m.metadataid DESC
    ) sub
    LEFT JOIN silver.dim_products d ON sub.asin = d.asin
    WHERE d.asin IS NULL;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    -- 2. Update existing rows if any column has changed
    UPDATE silver.dim_products d
    SET 
        metadataid = sub.metadataid,
        category = sub.category,
        salesrank = sub.salesrank,
        imurl = sub.imurl,
        categories = sub.categories,
        title = sub.title,
        description = sub.description,
        price = sub.price,
        related = sub.related,
        brand = sub.brand
    FROM (
        SELECT DISTINCT ON (m.asin)
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
            m.brand
        FROM post_bronze.metadata m
        ORDER BY m.asin, m.metadataid DESC
    ) sub
    WHERE d.asin = sub.asin
      AND (
            d.metadataid IS DISTINCT FROM sub.metadataid OR
            d.category IS DISTINCT FROM sub.category OR
            d.salesrank IS DISTINCT FROM sub.salesrank OR
            d.imurl IS DISTINCT FROM sub.imurl OR
            d.categories IS DISTINCT FROM sub.categories OR
            d.title IS DISTINCT FROM sub.title OR
            d.description IS DISTINCT FROM sub.description OR
            d.price IS DISTINCT FROM sub.price OR
            d.related IS DISTINCT FROM sub.related OR
            d.brand IS DISTINCT FROM sub.brand
      );

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    -- 3. Audit log
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
