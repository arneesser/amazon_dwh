import pandas as pd
from sqlalchemy import text
import hashlib

def incremental_load(df: pd.DataFrame, table_name: str, engine, schema: str="bronze", key_cols=None, filename=""):
    """
    Incremental load using hash-based comparison for staging tables.

    - Computes a deterministic MD5 hash on key columns to detect new rows.
    - Inserts only new rows into the table.
    - Logs ETL audit via `log_etl_audit`.

    Args:
        df (pd.DataFrame): DataFrame to load.
        table_name (str): Target table name.
        engine: SQLAlchemy engine.
        schema (str): Target schema (default 'bronze').
        key_cols (list): List of columns used to generate business key hash.
        filename (str): Source filename for audit logging.
    """
    if not key_cols:
        raise ValueError("You must provide key_cols to generate business key hash.")

    # Step 1: Compute hash for each row in df
    def make_hash(df, key_cols):
        keys_str = df[key_cols].fillna("NULL").astype(str)
        concat_keys = keys_str.apply(lambda row: "|".join(row.values), axis=1)
        return concat_keys.map(lambda x: hashlib.md5(x.encode()).hexdigest())

    df["tmp_business_key"] = make_hash(df, key_cols)

    # Step 2: Fetch existing hashes from destination table 
    try:
        existing_query = f"SELECT {', '.join(key_cols)} FROM {schema}.{table_name}"
        existing = pd.read_sql(existing_query, engine)
        if not existing.empty:
            existing["tmp_business_key"] = make_hash(existing, key_cols)
            existing_keys = set(existing["tmp_business_key"])
        else:
            existing_keys = set()
    except Exception:
        existing_keys = set()

    # Step 3: Identify new rows 
    new_rows = df[~df["tmp_business_key"].isin(existing_keys)]

    if new_rows.empty:
        print(f"No new rows to load into {schema}.{table_name}.")
        try:
            log_etl_audit(engine, schema, table_name, 0, "no_new_rows", filename)
        except Exception:
            pass
        return

    # Step 4: Insert new rows in bulk 
    new_rows_to_insert = new_rows.drop(columns=["tmp_business_key"])
    try:
        new_rows_to_insert.to_sql(
            table_name,
            engine,
            schema=schema,
            if_exists='append',
            index=False,
            method='multi',
            chunksize=5000
        )
        inserted_count = len(new_rows_to_insert)
        print(f"Loaded {inserted_count} new rows into {schema}.{table_name}")
        log_etl_audit(engine, schema, table_name, inserted_count, "success", filename)

    except Exception as e:
        print(f"Error inserting rows: {e}")
        log_etl_audit(engine, schema, table_name, 0, "failure", filename)


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
