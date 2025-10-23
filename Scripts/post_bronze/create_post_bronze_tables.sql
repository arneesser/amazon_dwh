-- Accepted reviews table
DROP TABLE IF EXISTS post_bronze.reviews;

CREATE TABLE IF NOT EXISTS post_bronze.reviews (
    reviewerid TEXT,
    asin TEXT,
    reviewername TEXT,
    helpful TEXT,
    reviewtext TEXT,
    overall INT,
    summary TEXT,
    unixreviewtime BIGINT,
    reviewtime TEXT,
    batch_timestamp TIMESTAMP DEFAULT NOW(),
    filename TEXT
);

	-- Index to speed up join on ASIN
CREATE INDEX idx_reviews_asin ON post_bronze.reviews(asin);

	-- Index to speed up join on reviewerid
CREATE INDEX idx_reviews_reviewerid ON post_bronze.reviews(reviewerid);

	-- Index to speed up join on unixreviewtime
CREATE INDEX idx_reviews_unixreviewtime ON post_bronze.reviews(unixreviewtime);
-- Flagged reviews table
DROP TABLE IF EXISTS post_bronze.flagged_reviews;

CREATE TABLE IF NOT EXISTS post_bronze.flagged_reviews (
    reviewerid TEXT,
    asin TEXT,
    reviewername TEXT,
    helpful TEXT,
    reviewtext TEXT,
    overall INT,
    summary TEXT,
    unixreviewtime BIGINT,
    reviewtime TEXT,
    batch_timestamp TIMESTAMP DEFAULT NOW(),
    filename TEXT
);

-- Accepted metadata table
DROP TABLE IF EXISTS post_bronze.metadata;

CREATE TABLE IF NOT EXISTS post_bronze.metadata (
    metadataid TEXT,
    asin TEXT,
    salesrank JSONB,
    imurl TEXT,
    categories JSONB,
    title TEXT,
    description TEXT,
    price NUMERIC(10,2),
    related JSONB,
    brand TEXT,
    batch_timestamp TIMESTAMP DEFAULT NOW(),
    filename TEXT
);

create UNIQUE INDEX IF NOT EXISTS idx_postbronze_metadataid
    ON post_bronze.metadata(metadataid);

create UNIQUE INDEX IF NOT EXISTS idx_postbronze_asin
    ON post_bronze.metadata(asin);


-- Flagged metadata table
DROP TABLE IF EXISTS post_bronze.flagged_metadata;

CREATE TABLE IF NOT EXISTS post_bronze.flagged_metadata (
    metadataid TEXT,
    asin TEXT,
    salesrank JSONB,
    imurl TEXT,
    categories JSONB,
    title TEXT,
    description TEXT,
    price NUMERIC(10,2),
    related JSONB,
    brand TEXT,
    batch_timestamp TIMESTAMP DEFAULT NOW(),
    filename TEXT
);
