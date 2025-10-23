from .preprocess_metadata import preprocess_df
from .schema_checks_metadata import schema_check_df
from python.utils.etl_load import incremental_load

from sqlalchemy import create_engine
from os import path
import pandas as pd

# Database connection
engine = create_engine("postgresql+psycopg2://postgres:admin@localhost:5432/AmazonDB")

# Load CSV file
file_path = r"raw_data\metadata_category_clothing_shoes_and_jewelry_only_newprice.csv"
df_metadata = pd.read_csv(file_path)
filename= path.basename(file_path)

if __name__ == "__main__":
    # Preprocess metadata dataframe
    processed_df = preprocess_df(df_metadata, filename=filename)

    # Perform schema integrity checks
    try:
        schema_check_df(processed_df)
        
    except ValueError as e:
        print(f"Schema check Failed: {e}")
        exit(1)
    
    else:
        print("Schema checks passed. Proceed to load into DB.")
    
    incremental_load(
        df=processed_df,
        table_name="metadata",
        engine=engine,
        schema="bronze",
        key_cols=["metadataid", "asin"],
        filename=filename
    )

