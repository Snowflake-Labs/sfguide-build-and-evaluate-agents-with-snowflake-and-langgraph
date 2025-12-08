-- ============================================================================
-- 02_load_data.sql
-- Load demo data from CSV files in the Git repository
-- ============================================================================

EXECUTE AS CALLER

BEGIN
    -- Set context
    USE WAREHOUSE COMPUTE_WH;
    USE DATABASE CUSTOMER_INTELLIGENCE_DB;
    USE SCHEMA PUBLIC;

    -- Create file format
    CREATE OR REPLACE FILE FORMAT CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format
        TYPE = CSV
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        NULL_IF = ('', 'NULL', 'null')
        EMPTY_FIELD_AS_NULL = TRUE;

    -- Clear existing data
    TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS;
    TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS;
    TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS;
    TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS;

    -- Load CUSTOMERS
    INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS (customer_id, signup_date, plan_type, company_size, industry, status, monthly_revenue)
    SELECT 
        $1::VARCHAR,
        $2::DATE,
        $3::VARCHAR,
        $4::VARCHAR,
        $5::VARCHAR,
        $6::VARCHAR,
        $7::DECIMAL(10,2)
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_customers.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    -- Load USAGE_EVENTS
    INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS (event_id, customer_id, event_date, feature_used, session_duration_minutes, actions_count)
    SELECT 
        $1::VARCHAR,
        $2::VARCHAR,
        $3::DATE,
        $4::VARCHAR,
        $5::INTEGER,
        $6::INTEGER
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_usage_events.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    -- Load SUPPORT_TICKETS
    INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS (ticket_id, customer_id, created_date, category, priority, status, resolution_time_hours, satisfaction_score, ticket_text)
    SELECT 
        $1::VARCHAR,
        $2::VARCHAR,
        $3::DATE,
        $4::VARCHAR,
        $5::VARCHAR,
        $6::VARCHAR,
        $7::INTEGER,
        $8::INTEGER,
        $9::VARCHAR
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_support_tickets.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    -- Load CHURN_EVENTS
    INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS (churn_id, customer_id, churn_date, churn_reason, days_since_signup, final_plan_type, final_monthly_revenue)
    SELECT 
        $1::VARCHAR,
        $2::VARCHAR,
        $3::DATE,
        $4::VARCHAR,
        $5::INTEGER,
        $6::VARCHAR,
        $7::DECIMAL(10,2)
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_churn_events.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    -- Return verification
    RETURN 'Data loaded successfully';
END;
