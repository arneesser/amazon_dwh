from .preprocess_reviews import preprocess_df
from .schema_checks_reviews import  schema_check_df
from python.utils.etl_load import incremental_load

from sqlalchemy import create_engine
from os import path
import pandas as pd


# Initialize database engine
engine = create_engine("postgresql+psycopg2://postgres:admin@localhost:5432/AmazonDB")

# Load CSV files
file_path = r"raw_data\reviews_Clothing_Shoes_and_Jewelry_5.csv"
df_reviews = pd.read_csv(file_path, index_col=0)
filename= path.basename(file_path)


if __name__ == "__main__":
    
    # Preprocess reviews data
    processed_df = preprocess_df(df_reviews, filename=filename)

    # Perform schema integrity checks
    try:
        schema_check_df(processed_df)

    except ValueError as e:
        print(f"Schema Check Failed: {e}")
        exit(1)

    else:
        print("Schema integrity checks passed. Proceed to load into DB.")

        incremental_load(
        df=processed_df,
        table_name="reviews",
        engine=engine,
        schema="bronze",
        key_cols=["reviewerid", "asin", "unixreviewtime"],
        filename=filename
        )

        
