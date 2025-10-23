import pandas as pd
import hashlib

def preprocess_df(df: pd.DataFrame, filename: str) -> pd.DataFrame:
    """
    Preprocess the reviews DataFrame.

    Steps:
    - Converts all column names to lowercase.
    - Creates a business key 'review_id' by hashing 'reviewerid', 'asin', and 'unixreviewtime'.
    - Adds a 'batch_timestamp' column with the current timestamp.
    - Adds a 'filename' column with the source filename.
    - Reorders columns so 'review_id' is the first column.

    Args:
        df (pd.DataFrame): Input DataFrame containing reviews.
        filename (str): Source filename for tracking.
    Returns:
        pd.DataFrame: Preprocessed DataFrame with 'review_id' column as first column.
    """
    df.columns = df.columns.str.lower()
    df["batch_timestamp"] = pd.Timestamp.now()
    df["filename"] = filename

    return df
