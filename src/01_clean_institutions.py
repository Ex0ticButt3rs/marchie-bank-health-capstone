"""Flatten fdic_institutions.json into clean.institutions using pandas."""
import pandas as pd
import numpy as np
import json
from postgres_connection import get_connection
from psycopg2.extras import execute_values
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "capstone_data"
SOURCE_FILE = DATA_DIR / "fdic_institutions.json"

CREATE_TABLE_SQL = """
CREATE SCHEMA IF NOT EXISTS clean;
CREATE TABLE IF NOT EXISTS clean.institutions (
    fdic_certificate_number       INTEGER PRIMARY KEY,
    institution_name              TEXT NOT NULL,
    headquarters_city             TEXT,
    headquarters_state_code       TEXT,
    headquarters_zip_code         TEXT,
    total_assets_thousands        BIGINT,
    total_deposits_thousands      BIGINT,
    is_active                     BOOLEAN NOT NULL,
    charter_class_code            TEXT,
    holding_company_name          TEXT,
    federal_reserve_rssd_id       TEXT,
    established_date              DATE,
    end_date                      DATE,
    website_address               TEXT,
    api_record_id                 TEXT
);
"""

def main():
    with open(SOURCE_FILE) as f:
        records = json.load(f)

    df = pd.json_normalize(records)

    # 1 Map JSON keys (prefixed with 'data_') to SQL columns
    df = df.rename(columns={
        'data_CERT': 'fdic_certificate_number',
        'data_NAME': 'institution_name',
        'data_CITY': 'headquarters_city',
        'data_STALP': 'headquarters_state_code',
        'data_ZIP': 'headquarters_zip_code',
        'data_ASSET': 'total_assets_thousands',
        'data_DEP': 'total_deposits_thousands',
        'data_ACTIVE': 'is_active',
        'data_BKCLASS': 'charter_class_code',
        'data_NAMEHCR': 'holding_company_name',
        'data_FED_RSSD': 'federal_reserve_rssd_id',
        'data_ESTYMD': 'established_date',
        'data_ENDEFYMD': 'end_date',
        'data_WEBADDR': 'website_address',
        'data_ID': 'api_record_id'
    })

    cols = ['fdic_certificate_number', 'institution_name', 'headquarters_city', 'headquarters_state_code',
        'headquarters_zip_code', 'total_assets_thousands', 'total_deposits_thousands', 'is_active', 'charter_class_code',
        'holding_company_name', 'federal_reserve_rssd_id', 'established_date', 'end_date', 'website_address', 'api_record_id']

    # Add missing columns as NaN if they weren't in JSON
    for col in cols:
        if col not in df.columns:
            df[col] = np.nan
    df = df[cols]

    # 2 Data Transformation
    df['is_active'] = df['is_active'] == 1
    df['fdic_certificate_number'] = df['fdic_certificate_number'].astype(int)

    # Parse dates and null out the 12/31/9999 placeholder
    for date_col in ['established_date', 'end_date']:
        # errors='coerce' parameter tells Pandas to convert any unparseable or invalid date string into NaT (Not a Time)
        df[date_col] = pd.to_datetime(df[date_col], format='%m/%d/%Y', errors='coerce')
        df.loc[df[date_col].dt.year == 9999, date_col] = pd.NaT

    # Trim text and replace empty strings with NaN (which becomes NULL)
    for text_col in ['charter_class_code', 'holding_company_name', 'website_address']:
        df[text_col] = df[text_col].astype(str).str.strip().replace({'': np.nan, 'nan': np.nan})

    # 3 Bulk Insert
    # Finds every NaN in DataFrame and swaps for Python's None object which psycopg2 correctly translates to SQL NULL
    # execute_values requires each row to be a tuple
    rows = [tuple(x) for x in df.replace({np.nan: None}).to_numpy()]

    with get_connection() as db_connect, db_connect.cursor() as cursor_object:
        cursor_object.execute(CREATE_TABLE_SQL)
        cursor_object.execute("TRUNCATE clean.institutions;")
        execute_values(cursor_object, f"INSERT INTO clean.institutions ({', '.join(cols)}) VALUES %s", rows)
        db_connect.commit()

    print(f"clean.institutions loaded: {len(df)} rows")

if __name__ == "__main__":
    main()