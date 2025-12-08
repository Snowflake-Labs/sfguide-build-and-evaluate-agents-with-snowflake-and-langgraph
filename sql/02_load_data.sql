-- ============================================================================
-- 02_load_data.sql
-- Creates stored procedure to load demo data from CSV files
-- ============================================================================

CREATE OR REPLACE PROCEDURE CUSTOMER_INTELLIGENCE_DB.PUBLIC.load_demo_data()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
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
    SELECT $1, $2, $3, $4, $5, $6, $7
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_customers.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    -- Load USAGE_EVENTS
    INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS (event_id, customer_id, event_date, feature_used, session_duration_minutes, actions_count)
    SELECT $1, $2, $3, $4, $5, $6
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_usage_events.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    -- Load SUPPORT_TICKETS
    INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS (ticket_id, customer_id, created_date, category, priority, status, resolution_time_hours, satisfaction_score, ticket_text)
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_support_tickets.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    -- Load CHURN_EVENTS
    INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS (churn_id, customer_id, churn_date, churn_reason, days_since_signup, final_plan_type, final_monthly_revenue)
    SELECT $1, $2, $3, $4, $5, $6, $7
    FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo/branches/main/demo_churn_events.csv
    (FILE_FORMAT => CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format);

    RETURN 'Data loaded successfully';
END;
$$
