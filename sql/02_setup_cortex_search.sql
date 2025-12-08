-- ============================================================================
-- 02_setup_cortex_search.sql
-- Creates Cortex Search services for the agents
-- ============================================================================

-- TODO: Update YOUR_WAREHOUSE with your actual warehouse name

-- ============================================================================
-- SUPPORT TICKETS SEARCH SERVICE
-- Used by CONTENT_AGENT for customer feedback and support analysis
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE BUILD_2025.PUBLIC.SUPPORT_TICKETS_SEARCH
ON ticket_text
ATTRIBUTES customer_id, ticket_id, category, priority, status, created_date
WAREHOUSE = YOUR_WAREHOUSE
TARGET_LAG = '1 hour'
AS (
    SELECT 
        ticket_id,
        customer_id,
        category,
        priority,
        status,
        created_date,
        ticket_text
    FROM BUILD_2025.PUBLIC.SUPPORT_TICKETS
);

-- ============================================================================
-- CUSTOMERS SEARCH SERVICE (Optional)
-- Used by RESEARCH_AGENT for customer segment analysis
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE BUILD_2025.PUBLIC.CUSTOMERS_SEARCH
ON industry
ATTRIBUTES customer_id, plan_type, company_size, status, monthly_revenue
WAREHOUSE = YOUR_WAREHOUSE
TARGET_LAG = '1 hour'
AS (
    SELECT 
        customer_id,
        plan_type,
        company_size,
        industry,
        status,
        monthly_revenue
    FROM BUILD_2025.PUBLIC.CUSTOMERS
);

-- Verify search services created
SHOW CORTEX SEARCH SERVICES IN SCHEMA BUILD_2025.PUBLIC;

