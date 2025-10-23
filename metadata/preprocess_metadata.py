import pandas as pd
import json
import ast

def preprocess_df(df: pd.DataFrame, filename: str) -> pd.DataFrame:
    """
    Preprocess the metadata DataFrame.

    Steps:
    - Lowercases column names.
    - Adds 'batch_timestamp' and 'filename'.
    - Safely converts JSON-like columns (salesrank, categories, related) to JSON strings.

    Args:
        df (pd.DataFrame): Input DataFrame containing metadata.
        filename (str): Source filename.
    """
    df.columns = df.columns.str.lower()
    df['batch_timestamp'] = pd.Timestamp.now()
    df['filename'] = filename

    df = df.fillna('')

    json_cols = ["salesrank", "categories", "related"]

    def safe_serialize(val, default):
        if val in ['', 'NaN', None]:
            return json.dumps(default)
        try:
            if isinstance(val, str):
                parsed = ast.literal_eval(val)
            else:
                parsed = val
            return json.dumps(parsed)
        except Exception:

            return json.dumps(default)

    for col in json_cols:
        df[col] = df[col].apply(lambda x: safe_serialize(x, {} if col != "categories" else []))

    return df
