-- ============================================================================
-- 02_load_data.sql
-- Load demo data from CSV files in the Git repository
-- ============================================================================
-- 
-- ⚠️  IMPORTANT: Run this script manually in Snowsight using "Run All" (Ctrl+Shift+Enter)
--     Do NOT use EXECUTE IMMEDIATE FROM for this file.
--
-- ============================================================================

USE DATABASE CUSTOMER_INTELLIGENCE_DB;
USE SCHEMA PUBLIC;

-- ============================================================================
-- CREATE FILE FORMAT FOR CSV PARSING
-- ============================================================================
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE;

-- ============================================================================
-- CLEAR EXISTING DATA
-- ============================================================================
TRUNCATE TABLE IF EXISTS CUSTOMERS;
TRUNCATE TABLE IF EXISTS USAGE_EVENTS;
TRUNCATE TABLE IF EXISTS SUPPORT_TICKETS;
TRUNCATE TABLE IF EXISTS CHURN_EVENTS;

-- ============================================================================
-- LOAD DATA FROM CSV FILES
-- ============================================================================

-- Load CUSTOMERS
INSERT INTO CUSTOMERS (customer_id, signup_date, plan_type, company_size, industry, status, monthly_revenue)
SELECT 
    $1::VARCHAR,
    $2::DATE,
    $3::VARCHAR,
    $4::VARCHAR,
    $5::VARCHAR,
    $6::VARCHAR,
    $7::DECIMAL(10,2)
FROM @customer_intelligence_demo/branches/main/demo_customers.csv
(FILE_FORMAT => csv_format);

-- Load USAGE_EVENTS
INSERT INTO USAGE_EVENTS (event_id, customer_id, event_date, feature_used, session_duration_minutes, actions_count)
SELECT 
    $1::VARCHAR,
    $2::VARCHAR,
    $3::DATE,
    $4::VARCHAR,
    $5::INTEGER,
    $6::INTEGER
FROM @customer_intelligence_demo/branches/main/demo_usage_events.csv
(FILE_FORMAT => csv_format);

-- Load SUPPORT_TICKETS
INSERT INTO SUPPORT_TICKETS (ticket_id, customer_id, created_date, category, priority, status, resolution_time_hours, satisfaction_score, ticket_text)
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
FROM @customer_intelligence_demo/branches/main/demo_support_tickets.csv
(FILE_FORMAT => csv_format);

-- Load CHURN_EVENTS
INSERT INTO CHURN_EVENTS (churn_id, customer_id, churn_date, churn_reason, days_since_signup, final_plan_type, final_monthly_revenue)
SELECT 
    $1::VARCHAR,
    $2::VARCHAR,
    $3::DATE,
    $4::VARCHAR,
    $5::INTEGER,
    $6::VARCHAR,
    $7::DECIMAL(10,2)
FROM @customer_intelligence_demo/branches/main/demo_churn_events.csv
(FILE_FORMAT => csv_format);

-- ============================================================================
-- VERIFY DATA LOADED
-- ============================================================================
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;
