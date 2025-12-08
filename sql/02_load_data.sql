-- ============================================================================
-- 02_load_data.sql
-- Load demo data from CSV files in the Git repository
-- ============================================================================

USE DATABASE CUSTOMER_INTELLIGENCE_DB;
USE SCHEMA PUBLIC;

-- ============================================================================
-- CREATE FILE FORMAT FOR CSV PARSING
-- ============================================================================
CREATE OR REPLACE FILE FORMAT CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE;

-- ============================================================================
-- LOAD DATA USING INSERT...SELECT FROM STAGED FILES
-- ============================================================================

-- Clear existing data
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS;

-- Load CUSTOMERS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS (customer_id, signup_date, plan_type, company_size, industry, status, monthly_revenue)
SELECT 
    $1::VARCHAR,           -- customer_id
    $2::DATE,              -- signup_date
    $3::VARCHAR,           -- plan_type
    $4::VARCHAR,           -- company_size
    $5::VARCHAR,           -- industry
    $6::VARCHAR,           -- status
    $7::DECIMAL(10,2)      -- monthly_revenue
FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_customers.csv
(FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

-- Load USAGE_EVENTS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS (event_id, customer_id, event_date, feature_used, session_duration_minutes, actions_count)
SELECT 
    $1::VARCHAR,           -- event_id
    $2::VARCHAR,           -- customer_id
    $3::DATE,              -- event_date
    $4::VARCHAR,           -- feature_used
    $5::INTEGER,           -- session_duration_minutes
    $6::INTEGER            -- actions_count
FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_usage_events.csv
(FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

-- Load SUPPORT_TICKETS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS (ticket_id, customer_id, created_date, category, priority, status, resolution_time_hours, satisfaction_score, ticket_text)
SELECT 
    $1::VARCHAR,           -- ticket_id
    $2::VARCHAR,           -- customer_id
    $3::DATE,              -- created_date
    $4::VARCHAR,           -- category
    $5::VARCHAR,           -- priority
    $6::VARCHAR,           -- status
    $7::INTEGER,           -- resolution_time_hours
    $8::INTEGER,           -- satisfaction_score
    $9::VARCHAR            -- ticket_text
FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_support_tickets.csv
(FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

-- Load CHURN_EVENTS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS (churn_id, customer_id, churn_date, churn_reason, days_since_signup, final_plan_type, final_monthly_revenue)
SELECT 
    $1::VARCHAR,           -- churn_id
    $2::VARCHAR,           -- customer_id
    $3::DATE,              -- churn_date
    $4::VARCHAR,           -- churn_reason
    $5::INTEGER,           -- days_since_signup
    $6::VARCHAR,           -- final_plan_type
    $7::DECIMAL(10,2)      -- final_monthly_revenue
FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_churn_events.csv
(FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

-- ============================================================================
-- VERIFY DATA LOADED
-- ============================================================================
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS;
