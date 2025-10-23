DROP TABLE IF EXISTS bronze.reviews;

CREATE table if not EXISTS bronze.reviews (       
    reviewerid TEXT NOT NULL,
    asin TEXT,
    reviewername TEXT,
    helpful TEXT,                          
    reviewText TEXT,
    overall FLOAT,
    summary TEXT,
    unixreviewtime BIGINT,
    reviewTime TEXT,
    batch_timestamp TIMESTAMP,
    filename TEXT
);
