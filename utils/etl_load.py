import pandas as pd
from sqlalchemy import text
import hashlib

def incremental_load(df: pd.DataFrame, table_name: str, engine, schema: str="bronze", key_cols=None, filename=""):
    """
    Incremental load for Bronze/staging tables without a primary key.

    - Generates a temporary business key hash for incremental loading.
    - Inserts only new rows into the table.
    - Does NOT persist the business key in the table.
    - Handles missing key columns and null values.
    - Logs ETL audit (calls the log_etl_audit function).

    Args:
        df (pd.DataFrame): DataFrame to load.
        table_name (str): Target table name.
        engine: SQLAlchemy engine.
        schema (str): Target schema name (default 'bronze').
        key_cols (list): List of columns to generate temporary business key.
        filename (str): Source filename for audit logging.
    """

    if not key_cols:
        raise ValueError("You must provide key_cols (list) to generate temporary business key")

    # Helper to normalize key values
    def normalize_value(v):
        if pd.isna(v) or str(v).strip().lower() in ["nan", "none", "null", ""]:
            return "NULL"
        return str(v).strip()

    # Create deterministic hash key 
    def make_key(row):
        key_str = "_".join([normalize_value(row[c]) for c in key_cols])
        return hashlib.md5(key_str.encode()).hexdigest()

    df["tmp_business_key"] = df.apply(make_key, axis=1)

    #  Fetch existing keys from DB 
    try:
        existing = pd.read_sql(f"SELECT {', '.join(key_cols)} FROM {schema}.{table_name}", engine)
        if not existing.empty:
            existing["tmp_business_key"] = existing.apply(make_key, axis=1)
            existing_keys = set(existing["tmp_business_key"])
        else:
            existing_keys = set()
    except Exception:
        existing_keys = set()

    # Filter new unique rows
    new_rows = df[~df["tmp_business_key"].isin(existing_keys)]

    if new_rows.empty:
        print(f"No new rows to load into {schema}.{table_name}.")
        try:
            log_etl_audit(engine, schema, table_name, 0, "no_new_rows", filename)
        except Exception:
            pass
        return

    new_rows_to_insert = new_rows.drop(columns=["tmp_business_key"])

    # Insert new rows into table
    inserted_count = 0
    columns = ", ".join(new_rows_to_insert.columns)
    placeholders = ", ".join([f":{c}" for c in new_rows_to_insert.columns])
    insert_sql = f"INSERT INTO {schema}.{table_name} ({columns}) VALUES ({placeholders})"

    with engine.begin() as conn:
        for row in new_rows_to_insert.to_dict(orient="records"):
            conn.execute(text(insert_sql), row)
            inserted_count += 1

    print(f"Loaded {inserted_count} new rows into {schema}.{table_name}")
    log_etl_audit(engine, schema, table_name, inserted_count, "success", filename)


def log_etl_audit(engine, schema, table_name, row_count, status, filename):
    """
    Logs ETL load details into the etl_audit_log table.
    Args:
        engine: SQLAlchemy engine connected to the database.
        schema (str): Target schema name.
        table_name (str): Target table name.
        filename (str): Source filename.
        row_count (int): Number of rows loaded.
        status (str): Load status ("success", "no_new_rows", "failure").
    """
    row_count = int(row_count) 

    insert_log = text("""
        INSERT INTO bronze.etl_audit_log (schema_name, table_name, filename, row_count, status)
        VALUES (:schema_name, :table_name, :filename, :row_count, :status);
    """)

    with engine.begin() as conn:
        conn.execute(insert_log, {
            "schema_name": schema,
            "table_name": table_name,
            "filename": filename,
            "row_count": row_count,
            "status": status,
        })
