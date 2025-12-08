-- ============================================================================
-- 00_run_all_setup.sql
-- Master setup script using Snowflake Git Integration
-- Reference: https://docs.snowflake.com/en/developer-guide/git/git-overview
-- ============================================================================
--
-- This script clones the GitHub repo into Snowflake and runs all setup scripts
-- directly from the Git repository.
--
-- BEFORE RUNNING: Update these placeholders:
--   - YOUR_WAREHOUSE: Your Snowflake warehouse name (in 02_setup_cortex_search.sql)
--
-- ============================================================================

-- ============================================================================
-- STEP 0: SET UP GIT INTEGRATION
-- ============================================================================

-- Use ACCOUNTADMIN role for setup (or a role with CREATE INTEGRATION privilege)
USE ROLE ACCOUNTADMIN;

-- Create a database for the demo if it doesn't exist
CREATE DATABASE IF NOT EXISTS CUSTOMER_INTELLIGENCE_DB;
USE DATABASE CUSTOMER_INTELLIGENCE_DB;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- Create API integration for GitHub (public repos don't need secrets)
CREATE API INTEGRATION IF NOT EXISTS github_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/Snowflake-Labs/')
  ENABLED = TRUE;

-- Create the Git repository object pointing to the snowflake-labs repo
CREATE OR REPLACE GIT REPOSITORY CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo
  API_INTEGRATION = github_api_integration
  ORIGIN = 'https://github.com/Snowflake-Labs/sfguide-build-and-evaluate-agents-with-snowflake-and-langgraph.git';

-- Fetch the latest from the remote repository
ALTER GIT REPOSITORY CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo FETCH;

-- View available branches
SHOW GIT BRANCHES IN CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo;

-- List files in the sql directory (main branch)
LS @CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo/branches/main/sql/;

-- ============================================================================
-- STEP 1: CREATE DATABASE, TABLES, AND LOAD DEMO DATA
-- ============================================================================
-- This script creates all tables and loads demo data from CSV files in the repo
EXECUTE IMMEDIATE FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo/branches/main/sql/01_setup_database.sql;

-- ============================================================================
-- STEP 2: CREATE CORTEX SEARCH SERVICES
-- ============================================================================
EXECUTE IMMEDIATE FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo/branches/main/sql/02_setup_cortex_search.sql;

-- ============================================================================
-- STEP 3: CREATE SEMANTIC VIEWS
-- ============================================================================
EXECUTE IMMEDIATE FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo/branches/main/sql/03_create_semantic_views.sql;

-- ============================================================================
-- STEP 4: CREATE UDFs (Tools for Agents)
-- ============================================================================
EXECUTE IMMEDIATE FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo/branches/main/sql/04_setup_udfs.sql;

-- ============================================================================
-- STEP 5: CREATE CORTEX AGENTS
-- ============================================================================
EXECUTE IMMEDIATE FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo/branches/main/sql/05_setup_cortex_agents.sql;

-- ============================================================================
-- VERIFICATION - Confirm setup completed successfully
-- ============================================================================

-- Check tables were created
SELECT 'TABLES' as check_type, COUNT(*) as count 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'PUBLIC' AND TABLE_CATALOG = 'CUSTOMER_INTELLIGENCE_DB';

-- Check data was loaded from CSV files
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS
UNION ALL
SELECT 'USAGE_EVENTS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS
UNION ALL
SELECT 'SUPPORT_TICKETS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS
UNION ALL
SELECT 'CHURN_EVENTS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS;

-- Check Cortex Search services
SHOW CORTEX SEARCH SERVICES IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;

-- Check Semantic Views
SHOW SEMANTIC VIEWS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;

-- Check UDFs
SHOW USER FUNCTIONS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;

-- Check Cortex Agents
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================
-- Next steps:
-- 1. Clone the repo locally: git clone https://github.com/Snowflake-Labs/sfguide-build-and-evaluate-agents-with-snowflake-and-langgraph.git
-- 2. Configure your .env file with Snowflake credentials
-- 3. Run: langgraph dev
-- 4. Open LangGraph Studio and test the multi-agent workflow
-- ============================================================================

SELECT '🎉 SETUP COMPLETE! Ready to run langgraph dev' as status;

-- ============================================================================
-- OPTIONAL: REFRESH FROM GIT
-- ============================================================================
-- To pull latest changes from the repo:
-- ALTER GIT REPOSITORY CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo FETCH;
--
-- To re-run a specific script after updates:
-- EXECUTE IMMEDIATE FROM @CUSTOMER_INTELLIGENCE_DB.PUBLIC.multi_agent_demo_repo/branches/main/sql/05_setup_cortex_agents.sql;
-- ============================================================================
