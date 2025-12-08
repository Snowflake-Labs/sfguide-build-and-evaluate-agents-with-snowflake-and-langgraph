-- ============================================================================
-- 02_load_data.sql
-- Load demo data from CSV files uploaded via Snowsight
-- ============================================================================

USE DATABASE CUSTOMER_INTELLIGENCE_DB;
USE SCHEMA PUBLIC;

-- ============================================================================
-- STEP 1: CREATE INTERNAL STAGE FOR CSV UPLOADS
-- ============================================================================
CREATE OR REPLACE STAGE demo_data_stage
    FILE_FORMAT = (
        TYPE = CSV
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        NULL_IF = ('', 'NULL', 'null')
    );

-- ============================================================================
-- STEP 2: UPLOAD CSV FILES VIA SNOWSIGHT
-- ============================================================================
-- In Snowsight:
-- 1. Go to Data > Databases > CUSTOMER_INTELLIGENCE_DB > PUBLIC > Stages
-- 2. Click on DEMO_DATA_STAGE
-- 3. Click "+ Files" button (top right)
-- 4. Upload these 4 files from the repo:
--    - demo_customers.csv
--    - demo_usage_events.csv
--    - demo_support_tickets.csv
--    - demo_churn_events.csv
--
-- Or use SnowSQL CLI:
--   PUT file://demo_customers.csv @demo_data_stage;
--   PUT file://demo_usage_events.csv @demo_data_stage;
--   PUT file://demo_support_tickets.csv @demo_data_stage;
--   PUT file://demo_churn_events.csv @demo_data_stage;
-- ============================================================================

-- Verify files are uploaded (should show 4 files)
LS @demo_data_stage;

-- ============================================================================
-- STEP 3: LOAD DATA FROM STAGE INTO TABLES
-- ============================================================================

-- Load customers
COPY INTO CUSTOMERS (customer_id, signup_date, plan_type, company_size, industry, status, monthly_revenue)
FROM @demo_data_stage/demo_customers.csv
ON_ERROR = CONTINUE;

-- Load usage events
COPY INTO USAGE_EVENTS (event_id, customer_id, event_date, feature_used, session_duration_minutes, actions_count)
FROM @demo_data_stage/demo_usage_events.csv
ON_ERROR = CONTINUE;

-- Load support tickets
COPY INTO SUPPORT_TICKETS (ticket_id, customer_id, created_date, category, priority, status, resolution_time_hours, satisfaction_score, ticket_text)
FROM @demo_data_stage/demo_support_tickets.csv
ON_ERROR = CONTINUE;

-- Load churn events
COPY INTO CHURN_EVENTS (churn_id, customer_id, churn_date, churn_reason, days_since_signup, final_mrr)
FROM @demo_data_stage/demo_churn_events.csv
ON_ERROR = CONTINUE;

-- ============================================================================
-- VERIFY DATA LOADED
-- ============================================================================
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;

