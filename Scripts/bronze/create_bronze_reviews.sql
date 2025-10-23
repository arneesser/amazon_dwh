DROP TABLE IF EXISTS bronze.reviews;

CREATE table if not EXISTS bronze.reviews (       
    reviewerid TEXT NOT NULL,
    asin TEXT NOT NULL,
    reviewername TEXT,
    helpful TEXT,                          
    reviewText TEXT,
    overall FLOAT NOT NULL,
    summary TEXT,
    unixreviewtime BIGINT NOT NULL,
    reviewTime TEXT NOT null,
    batch_timestamp TIMESTAMP,
    filename TEXT
);
