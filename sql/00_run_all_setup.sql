-- ============================================================================
-- 00_run_all_setup.sql
-- Master setup script using Snowflake Git Integration
-- Reference: https://docs.snowflake.com/en/developer-guide/git/git-overview
-- ============================================================================
--
-- Run this script in Snowsight to set up the entire demo.
--
-- PREREQUISITE: Push all changes to GitHub first, then run this script.
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
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/02_load_data.sql;

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
-- OPTIONAL: REFRESH FROM GIT
-- ============================================================================
-- To pull latest changes:
-- ALTER GIT REPOSITORY customer_intelligence_demo FETCH;
