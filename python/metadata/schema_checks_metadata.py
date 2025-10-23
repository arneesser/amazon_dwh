import pandas as pd
from python.utils.config import metadata_cols

def schema_check_df(df: pd.DataFrame) -> pd.DataFrame:
    """
    Perform schema integrity checks on the metadata DataFrame.

    Args:
        df (pd.DataFrame): Input DataFrame containing metadata.

    Checks:
    - Ensures required columns exist.
    - Saves a CSV report for column existence.
    - Returns the original DataFrame unchanged.
    """

    schema_checks = []
    for col in metadata_cols:
        if col in df.columns:
            schema_checks.append({"check": f"Column '{col}' exists", "pass": True, "error_message": ""})
        else:
            schema_checks.append({"check": f"Column '{col}' exists", "pass": False, "error_message": f"Missing column '{col}'"})

    missing_cols = [col for col in metadata_cols if col not in df.columns]
    schema_report_df = pd.DataFrame(schema_checks)
    
    schema_report_df.to_csv(r"results\metadata_schema_report.csv", index=False)

    if missing_cols:
        raise ValueError(f"Missing required columns: {', '.join(missing_cols)}")

    print(f"Total rows in DataFrame: {len(df)}")
    print("Schema integrity check passed.")

    return df
