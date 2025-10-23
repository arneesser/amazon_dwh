drop table if exists bronze.metadata; 

CREATE TABLE IF NOT EXISTS bronze.metadata (
 	metadataid TEXT PRIMARY KEY,
    asin TEXT,
    salesrank TEXT,
    imurl TEXT,
    categories TEXT,
    title TEXT,
    description TEXT,
    price TEXT,
    related TEXT,
    brand TEXT,
    batch_timestamp TIMESTAMP,
    filename TEXT
)
