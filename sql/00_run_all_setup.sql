-- ============================================================================
-- 00_run_all_setup.sql
-- Master setup script using Snowflake Git Integration
-- Reference: https://docs.snowflake.com/en/developer-guide/git/git-overview
-- ============================================================================
--
-- Run this script in Snowsight to set up the entire demo.
--
-- WORKFLOW:
-- 1. Make changes in your GitHub Codespace/workspace
-- 2. Commit and sync changes to GitHub
-- 3. In Snowsight: Go to Data > Databases > CUSTOMER_INTELLIGENCE_DB > 
--    Git Repositories > customer_intelligence_demo > Click "Fetch" button
-- 4. Run this script (or individual EXECUTE IMMEDIATE statements)
--
-- ============================================================================

-- ============================================================================
-- STEP 0: SET UP GIT INTEGRATION
-- ============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS CUSTOMER_INTELLIGENCE_DB;
USE DATABASE CUSTOMER_INTELLIGENCE_DB;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- Create API integration for GitHub
CREATE API INTEGRATION IF NOT EXISTS github_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/Snowflake-Labs/')
    ENABLED = TRUE;

-- Clone the GitHub repository
CREATE OR REPLACE GIT REPOSITORY customer_intelligence_demo
    API_INTEGRATION = github_api_integration
    ORIGIN = 'https://github.com/Snowflake-Labs/sfguide-build-and-evaluate-agents-with-snowflake-and-langgraph.git';

-- Fetch latest from GitHub
ALTER GIT REPOSITORY customer_intelligence_demo FETCH;

-- Verify repository
SHOW GIT BRANCHES IN customer_intelligence_demo;
LS @customer_intelligence_demo/branches/main/sql/;

-- ============================================================================
-- STEP 1: CREATE DATABASE AND TABLES
-- ============================================================================
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/01_setup_database.sql;

-- ============================================================================
-- STEP 2: LOAD DEMO DATA FROM CSV FILES  
-- ============================================================================
-- NOTE: Data loading is embedded here because EXECUTE IMMEDIATE FROM 
--       doesn't reliably execute from Git stages for complex statements.

-- Create file format
CREATE OR REPLACE FILE FORMAT CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format
    TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null') EMPTY_FIELD_AS_NULL = TRUE;

-- Clear existing data
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS;

-- Load CUSTOMERS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS 
SELECT $1,$2,$3,$4,$5,$6,$7 FROM @customer_intelligence_demo/branches/main/demo_customers.csv (FILE_FORMAT=>csv_format);

-- Load USAGE_EVENTS  
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS
SELECT $1,$2,$3,$4,$5,$6 FROM @customer_intelligence_demo/branches/main/demo_usage_events.csv (FILE_FORMAT=>csv_format);

-- Load SUPPORT_TICKETS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS
SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9 FROM @customer_intelligence_demo/branches/main/demo_support_tickets.csv (FILE_FORMAT=>csv_format);

-- Load CHURN_EVENTS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS
SELECT $1,$2,$3,$4,$5,$6,$7 FROM @customer_intelligence_demo/branches/main/demo_churn_events.csv (FILE_FORMAT=>csv_format);

-- Verify data loaded
SELECT 'CUSTOMERS' as tbl, COUNT(*) as cnt FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS  
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;

-- ============================================================================
-- STEP 3: CREATE CORTEX SEARCH SERVICES
-- ============================================================================
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/03_setup_cortex_search.sql;

-- ============================================================================
-- STEP 4: CREATE SEMANTIC VIEWS
-- ============================================================================
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/04_create_semantic_views.sql;

-- ============================================================================
-- STEP 5: CREATE UDFs (Tools for Agents)
-- ============================================================================
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/05_setup_udfs.sql;

-- ============================================================================
-- STEP 6: CREATE CORTEX AGENTS
-- ============================================================================
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/06_setup_cortex_agents.sql;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check data loaded
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;

-- Check Cortex services
SHOW CORTEX SEARCH SERVICES IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;
SHOW SEMANTIC VIEWS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;
SHOW USER FUNCTIONS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================
SELECT '🎉 SETUP COMPLETE! Ready to run langgraph dev' as status;

-- ============================================================================
-- REFRESH FROM GIT (After making changes)
-- ============================================================================
-- Option 1: In Snowsight UI
--   Data > Databases > CUSTOMER_INTELLIGENCE_DB > Git Repositories > 
--   customer_intelligence_demo > Click "Fetch" button
--
-- Option 2: Via SQL (may not work in all environments)
--   ALTER GIT REPOSITORY customer_intelligence_demo FETCH;
