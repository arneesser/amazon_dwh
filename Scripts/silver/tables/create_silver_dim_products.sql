DROP TABLE IF EXISTS silver.dim_products cascade;

CREATE TABLE IF NOT EXISTS silver.dim_products (
    product_key SERIAL PRIMARY KEY,
    metadataid TEXT,
    asin TEXT UNIQUE NOT NULL,
    category TEXT,
    salesrank JSONB,
    imurl TEXT,
    categories JSONB,
    title TEXT,
    description TEXT,
    price NUMERIC(10,2),
    related JSONB,
    brand TEXT
);

create UNIQUE INDEX IF NOT EXISTS idx_dim_products_asin
    ON silver.dim_products(asin);
