-- ============================================================================
-- 02_load_data.sql
-- Load demo data from CSV files in the Git repository using Snowpark
-- ============================================================================

USE DATABASE CUSTOMER_INTELLIGENCE_DB;
USE SCHEMA PUBLIC;

-- ============================================================================
-- CREATE STORED PROCEDURE TO LOAD CSV DATA FROM GIT REPO
-- ============================================================================
CREATE OR REPLACE PROCEDURE load_csv_from_git(
    table_name VARCHAR,
    csv_filename VARCHAR,
    columns ARRAY
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'load_csv'
AS
$$
import csv
from io import StringIO

def load_csv(session, table_name: str, csv_filename: str, columns: list) -> str:
    """Load CSV data from Git repo stage into a table."""
    
    # Read the CSV file from the Git repository stage
    stage_path = f"@customer_intelligence_demo/branches/main/{csv_filename}"
    
    try:
        # Get file content from stage
        result = session.sql(f"SELECT $1 FROM {stage_path}").collect()
        
        if not result:
            return f"Error: No data found in {csv_filename}"
        
        # Parse CSV content and build INSERT statements
        rows_inserted = 0
        batch_size = 100
        values_batch = []
        
        # Skip header row (first row)
        for i, row in enumerate(result):
            if i == 0:  # Skip header
                continue
                
            # Parse the CSV row
            line = row[0]
            reader = csv.reader(StringIO(line))
            for parsed_row in reader:
                # Escape single quotes and format values
                formatted_values = []
                for val in parsed_row:
                    if val is None or val == '' or val.upper() == 'NULL':
                        formatted_values.append('NULL')
                    else:
                        # Escape single quotes
                        escaped_val = val.replace("'", "''")
                        formatted_values.append(f"'{escaped_val}'")
                
                values_batch.append(f"({', '.join(formatted_values)})")
                
                # Execute batch insert
                if len(values_batch) >= batch_size:
                    cols_str = ', '.join(columns)
                    values_str = ', '.join(values_batch)
                    insert_sql = f"INSERT INTO {table_name} ({cols_str}) VALUES {values_str}"
                    session.sql(insert_sql).collect()
                    rows_inserted += len(values_batch)
                    values_batch = []
        
        # Insert remaining rows
        if values_batch:
            cols_str = ', '.join(columns)
            values_str = ', '.join(values_batch)
            insert_sql = f"INSERT INTO {table_name} ({cols_str}) VALUES {values_str}"
            session.sql(insert_sql).collect()
            rows_inserted += len(values_batch)
        
        return f"Successfully loaded {rows_inserted} rows into {table_name}"
        
    except Exception as e:
        return f"Error loading {csv_filename}: {str(e)}"
$$;

-- ============================================================================
-- LOAD ALL CSV FILES
-- ============================================================================

-- Clear existing data (optional - comment out to append)
TRUNCATE TABLE IF EXISTS CUSTOMERS;
TRUNCATE TABLE IF EXISTS USAGE_EVENTS;
TRUNCATE TABLE IF EXISTS SUPPORT_TICKETS;
TRUNCATE TABLE IF EXISTS CHURN_EVENTS;

-- Load customers
CALL load_csv_from_git(
    'CUSTOMERS',
    'demo_customers.csv',
    ARRAY_CONSTRUCT('customer_id', 'signup_date', 'plan_type', 'company_size', 'industry', 'status', 'monthly_revenue')
);

-- Load usage events
CALL load_csv_from_git(
    'USAGE_EVENTS',
    'demo_usage_events.csv',
    ARRAY_CONSTRUCT('event_id', 'customer_id', 'event_date', 'feature_used', 'session_duration_minutes', 'actions_count')
);

-- Load support tickets
CALL load_csv_from_git(
    'SUPPORT_TICKETS',
    'demo_support_tickets.csv',
    ARRAY_CONSTRUCT('ticket_id', 'customer_id', 'created_date', 'category', 'priority', 'status', 'resolution_time_hours', 'satisfaction_score', 'ticket_text')
);

-- Load churn events
CALL load_csv_from_git(
    'CHURN_EVENTS',
    'demo_churn_events.csv',
    ARRAY_CONSTRUCT('churn_id', 'customer_id', 'churn_date', 'churn_reason', 'days_since_signup', 'final_mrr')
);

-- ============================================================================
-- VERIFY DATA LOADED
-- ============================================================================
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;
