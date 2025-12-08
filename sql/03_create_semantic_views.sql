-- ============================================================================
-- 03_create_semantic_views.sql
-- Creates Semantic Views for Cortex Analyst tools
-- Reference: https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view
-- ============================================================================

USE DATABASE CUSTOMER_INTELLIGENCE_DB;
USE SCHEMA PUBLIC;

-- ============================================================================
-- CUSTOMER_BEHAVIOR_ANALYST Semantic View
-- Used by: DATA_ANALYST_AGENT
-- Purpose: AI-powered customer behavior analytics for usage patterns, 
--          churn analysis, customer segmentation, and retention insights
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW CUSTOMER_BEHAVIOR_ANALYST
  COMMENT = 'AI-powered customer behavior analytics model for natural language queries about usage patterns, churn analysis, customer segmentation, and retention insights across the complete customer lifecycle.'
  
  TABLES (
    -- CUSTOMERS table
    CUSTOMERS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS
      PRIMARY KEY (CUSTOMER_ID)
      COMMENT = 'Customer master data including demographics, plan type, and revenue',
    
    -- USAGE_EVENTS table
    USAGE_EVENTS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS
      COMMENT = 'Customer product usage events and session data',
    
    -- SUPPORT_TICKETS table
    SUPPORT_TICKETS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS
      COMMENT = 'Customer support tickets and satisfaction data',
    
    -- CHURN_EVENTS table
    CHURN_EVENTS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS
      COMMENT = 'Customer churn events with reasons and final revenue'
  )
  
  RELATIONSHIPS (
    -- Customer to Usage Events
    CUSTOMER_TO_USAGE AS 
      USAGE_EVENTS (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
    
    -- Customer to Support Tickets
    CUSTOMER_TO_SUPPORT AS 
      SUPPORT_TICKETS (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
    
    -- Customer to Churn Events
    CUSTOMER_TO_CHURN AS 
      CHURN_EVENTS (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID)
  )
  
  DIMENSIONS (
    -- CUSTOMERS dimensions
    CUSTOMERS.CUSTOMER_ID AS CUSTOMERS.CUSTOMER_ID
      WITH SYNONYMS = ('customer identifier', 'account id', 'client id')
      COMMENT = 'Unique identifier for each customer in the database',
    
    CUSTOMERS.COMPANY_SIZE AS CUSTOMERS.COMPANY_SIZE
      WITH SYNONYMS = ('business size', 'organization size')
      COMMENT = 'The size of the customer company: small, medium, or large',
    
    CUSTOMERS.INDUSTRY AS CUSTOMERS.INDUSTRY
      WITH SYNONYMS = ('sector', 'vertical', 'business type')
      COMMENT = 'The industry or sector in which the customer operates',
    
    CUSTOMERS.PLAN_TYPE AS CUSTOMERS.PLAN_TYPE
      WITH SYNONYMS = ('subscription', 'tier', 'pricing plan')
      COMMENT = 'The subscription plan level: starter, professional, enterprise',
    
    CUSTOMERS.STATUS AS CUSTOMERS.STATUS
      WITH SYNONYMS = ('customer status', 'account status')
      COMMENT = 'Whether customer is active or churned',
    
    CUSTOMERS.SIGNUP_DATE AS CUSTOMERS.SIGNUP_DATE
      WITH SYNONYMS = ('registration date', 'join date')
      COMMENT = 'Date when the customer signed up for the service',
    
    -- USAGE_EVENTS dimensions
    USAGE_EVENTS.EVENT_ID AS USAGE_EVENTS.EVENT_ID
      COMMENT = 'Unique identifier for usage events',
    
    USAGE_EVENTS.CUSTOMER_ID AS USAGE_EVENTS.CUSTOMER_ID
      COMMENT = 'Customer who triggered the usage event',
    
    USAGE_EVENTS.FEATURE_USED AS USAGE_EVENTS.FEATURE_USED
      WITH SYNONYMS = ('product feature', 'functionality')
      COMMENT = 'The feature or functionality used: integrations, collaboration, report_generation',
    
    USAGE_EVENTS.EVENT_DATE AS USAGE_EVENTS.EVENT_DATE
      WITH SYNONYMS = ('activity date', 'usage date')
      COMMENT = 'Date when the usage event occurred',
    
    -- SUPPORT_TICKETS dimensions
    SUPPORT_TICKETS.TICKET_ID AS SUPPORT_TICKETS.TICKET_ID
      COMMENT = 'Unique identifier for support tickets',
    
    SUPPORT_TICKETS.CUSTOMER_ID AS SUPPORT_TICKETS.CUSTOMER_ID
      COMMENT = 'Customer who submitted the support ticket',
    
    SUPPORT_TICKETS.CATEGORY AS SUPPORT_TICKETS.CATEGORY
      WITH SYNONYMS = ('ticket type', 'issue category')
      COMMENT = 'Category of the support ticket: billing, performance, data_export, etc.',
    
    SUPPORT_TICKETS.PRIORITY AS SUPPORT_TICKETS.PRIORITY
      WITH SYNONYMS = ('urgency', 'importance')
      COMMENT = 'Priority level: high, medium, low',
    
    SUPPORT_TICKETS.STATUS AS SUPPORT_TICKETS.STATUS
      WITH SYNONYMS = ('ticket status')
      COMMENT = 'Current state: pending, closed, resolved',
    
    SUPPORT_TICKETS.TICKET_TEXT AS SUPPORT_TICKETS.TICKET_TEXT
      COMMENT = 'The text content of the support ticket',
    
    SUPPORT_TICKETS.CREATED_DATE AS SUPPORT_TICKETS.CREATED_DATE
      COMMENT = 'Date when the support ticket was created',
    
    -- CHURN_EVENTS dimensions
    CHURN_EVENTS.CHURN_ID AS CHURN_EVENTS.CHURN_ID
      COMMENT = 'Unique identifier for churn events',
    
    CHURN_EVENTS.CUSTOMER_ID AS CHURN_EVENTS.CUSTOMER_ID
      COMMENT = 'Customer who churned',
    
    CHURN_EVENTS.CHURN_REASON AS CHURN_EVENTS.CHURN_REASON
      WITH SYNONYMS = ('cancellation reason', 'departure reason')
      COMMENT = 'Why customer churned: business_closure, missing_features, competitor_switch',
    
    CHURN_EVENTS.FINAL_PLAN_TYPE AS CHURN_EVENTS.FINAL_PLAN_TYPE
      COMMENT = 'Plan type at time of churn',
    
    CHURN_EVENTS.CHURN_DATE AS CHURN_EVENTS.CHURN_DATE
      WITH SYNONYMS = ('cancellation date', 'departure date')
      COMMENT = 'Date when customer churned'
  )
  
  FACTS (
    -- CUSTOMERS facts
    CUSTOMERS.MONTHLY_REVENUE AS CUSTOMERS.MONTHLY_REVENUE
      WITH SYNONYMS = ('MRR', 'monthly recurring revenue')
      COMMENT = 'Monthly revenue generated by the customer',
    
    -- USAGE_EVENTS facts
    USAGE_EVENTS.SESSION_DURATION_MINUTES AS USAGE_EVENTS.SESSION_DURATION_MINUTES
      WITH SYNONYMS = ('session length', 'time spent')
      COMMENT = 'Duration of user session in minutes',
    
    USAGE_EVENTS.ACTIONS_COUNT AS USAGE_EVENTS.ACTIONS_COUNT
      WITH SYNONYMS = ('activity count', 'interactions')
      COMMENT = 'Number of actions taken during the session',
    
    -- SUPPORT_TICKETS facts
    SUPPORT_TICKETS.RESOLUTION_TIME_HOURS AS SUPPORT_TICKETS.RESOLUTION_TIME_HOURS
      WITH SYNONYMS = ('time to resolve', 'resolution duration')
      COMMENT = 'Time taken to resolve the ticket in hours',
    
    SUPPORT_TICKETS.SATISFACTION_SCORE AS SUPPORT_TICKETS.SATISFACTION_SCORE
      WITH SYNONYMS = ('CSAT', 'customer satisfaction')
      COMMENT = 'Customer satisfaction rating (1-5)',
    
    -- CHURN_EVENTS facts
    CHURN_EVENTS.DAYS_SINCE_SIGNUP AS CHURN_EVENTS.DAYS_SINCE_SIGNUP
      WITH SYNONYMS = ('customer tenure', 'lifetime days')
      COMMENT = 'Number of days customer was active before churning',
    
    CHURN_EVENTS.FINAL_MONTHLY_REVENUE AS CHURN_EVENTS.FINAL_MONTHLY_REVENUE
      WITH SYNONYMS = ('lost revenue', 'churned MRR')
      COMMENT = 'Monthly revenue at time of churn'
  )
  
  METRICS (
    -- Customer metrics
    CUSTOMERS.TOTAL_CUSTOMERS AS COUNT(CUSTOMERS.CUSTOMER_ID)
      WITH SYNONYMS = ('customer count', 'number of customers')
      COMMENT = 'Total number of customers in the system',
    
    CUSTOMERS.ACTIVE_CUSTOMERS AS COUNT(CASE WHEN CUSTOMERS.STATUS = 'active' THEN CUSTOMERS.CUSTOMER_ID END)
      WITH SYNONYMS = ('current customers', 'active accounts')
      COMMENT = 'Total number of active customers',
    
    CUSTOMERS.CHURNED_CUSTOMERS AS COUNT(CASE WHEN CUSTOMERS.STATUS = 'churned' THEN CUSTOMERS.CUSTOMER_ID END)
      WITH SYNONYMS = ('lost customers', 'cancelled accounts')
      COMMENT = 'Total number of churned customers',
    
    CUSTOMERS.ARPU AS AVG(CUSTOMERS.MONTHLY_REVENUE)
      WITH SYNONYMS = ('average revenue per user', 'avg MRR')
      COMMENT = 'Average monthly revenue per customer',
    
    CUSTOMERS.TOTAL_MRR AS AVG(CUSTOMERS.MONTHLY_REVENUE) * COUNT(CUSTOMERS.CUSTOMER_ID)
      WITH SYNONYMS = ('total monthly recurring revenue')
      COMMENT = 'Total monthly recurring revenue across all customers',
    
    -- Usage metrics
    USAGE_EVENTS.AVG_SESSION_DURATION AS AVG(USAGE_EVENTS.SESSION_DURATION_MINUTES)
      WITH SYNONYMS = ('average session time', 'avg time spent')
      COMMENT = 'Average time customers spend in each session',
    
    USAGE_EVENTS.ENGAGEMENT_SCORE AS AVG(USAGE_EVENTS.ACTIONS_COUNT) * COUNT(USAGE_EVENTS.EVENT_ID)
      WITH SYNONYMS = ('engagement level', 'activity score')
      COMMENT = 'Composite score measuring customer product engagement',
    
    USAGE_EVENTS.UNIQUE_ACTIVE_CUSTOMERS AS COUNT(DISTINCT USAGE_EVENTS.CUSTOMER_ID)
      WITH SYNONYMS = ('active users', 'engaged customers')
      COMMENT = 'Number of unique customers with usage activity',
    
    -- Support metrics
    SUPPORT_TICKETS.TOTAL_SUPPORT_TICKETS AS COUNT(SUPPORT_TICKETS.TICKET_ID)
      WITH SYNONYMS = ('ticket count', 'support volume')
      COMMENT = 'Total number of support tickets',
    
    SUPPORT_TICKETS.AVG_RESOLUTION_TIME AS AVG(SUPPORT_TICKETS.RESOLUTION_TIME_HOURS)
      WITH SYNONYMS = ('average resolution time', 'mean time to resolve')
      COMMENT = 'Average time to resolve customer support tickets',
    
    SUPPORT_TICKETS.AVG_SUPPORT_SATISFACTION AS AVG(SUPPORT_TICKETS.SATISFACTION_SCORE)
      WITH SYNONYMS = ('average CSAT', 'satisfaction rating')
      COMMENT = 'Average customer satisfaction score across support interactions',
    
    -- Churn metrics
    CHURN_EVENTS.TOTAL_CHURN_EVENTS AS COUNT(CHURN_EVENTS.CUSTOMER_ID)
      WITH SYNONYMS = ('churn count', 'cancellations')
      COMMENT = 'Total number of churn events',
    
    CHURN_EVENTS.AVG_CUSTOMER_LIFETIME AS AVG(CHURN_EVENTS.DAYS_SINCE_SIGNUP)
      WITH SYNONYMS = ('average tenure', 'mean customer lifetime')
      COMMENT = 'Average number of days customers stay before churning',
    
    CHURN_EVENTS.REVENUE_AT_RISK AS SUM(CHURN_EVENTS.FINAL_MONTHLY_REVENUE)
      WITH SYNONYMS = ('lost MRR', 'churned revenue')
      COMMENT = 'Total monthly revenue lost from churned customers'
  );

-- Verify the semantic view was created
DESCRIBE SEMANTIC VIEW CUSTOMER_BEHAVIOR_ANALYST;


-- ============================================================================
-- STRATEGIC_RESEARCH_ANALYST Semantic View
-- Used by: RESEARCH_AGENT
-- Purpose: Executive-level market intelligence for strategic business analysis,
--          competitive positioning, and market opportunity identification
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW STRATEGIC_RESEARCH_ANALYST
  COMMENT = 'Comprehensive strategic research and analytics platform for executive-level business intelligence queries. Enables natural language analysis of customer lifecycle patterns, market segmentation, competitive positioning, and strategic business metrics.'
  
  TABLES (
    -- CUSTOMERS table
    CUSTOMERS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS
      PRIMARY KEY (CUSTOMER_ID)
      COMMENT = 'Customer master data for strategic analysis',
    
    -- USAGE_EVENTS table
    USAGE_EVENTS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS
      PRIMARY KEY (EVENT_ID)
      COMMENT = 'Platform usage data for engagement analysis',
    
    -- SUPPORT_TICKETS table
    SUPPORT_TICKETS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS
      PRIMARY KEY (TICKET_ID)
      COMMENT = 'Support interactions for service quality analysis',
    
    -- CHURN_EVENTS table
    CHURN_EVENTS AS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS
      PRIMARY KEY (CHURN_ID)
      COMMENT = 'Churn data for retention and risk analysis'
  )
  
  RELATIONSHIPS (
    -- Customer to Usage Events
    CUSTOMER_TO_USAGE AS 
      USAGE_EVENTS (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
    
    -- Customer to Support Tickets
    CUSTOMER_TO_SUPPORT AS 
      SUPPORT_TICKETS (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
    
    -- Customer to Churn Events
    CUSTOMER_TO_CHURN AS 
      CHURN_EVENTS (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID)
  )
  
  DIMENSIONS (
    -- CUSTOMERS dimensions
    CUSTOMERS.CUSTOMER_ID AS CUSTOMERS.CUSTOMER_ID
      WITH SYNONYMS = ('account id', 'client id')
      COMMENT = 'Unique identifier for each customer',
    
    CUSTOMERS.COMPANY_SIZE AS CUSTOMERS.COMPANY_SIZE
      WITH SYNONYMS = ('organization size', 'business scale')
      COMMENT = 'Company size category: small, medium, large',
    
    CUSTOMERS.INDUSTRY AS CUSTOMERS.INDUSTRY
      WITH SYNONYMS = ('vertical', 'sector', 'market segment')
      COMMENT = 'Industry vertical the customer operates in',
    
    CUSTOMERS.PLAN_TYPE AS CUSTOMERS.PLAN_TYPE
      WITH SYNONYMS = ('subscription tier', 'service level')
      COMMENT = 'Subscription plan: starter, professional, enterprise',
    
    CUSTOMERS.STATUS AS CUSTOMERS.STATUS
      WITH SYNONYMS = ('account status', 'customer state')
      COMMENT = 'Active or churned status',
    
    CUSTOMERS.SIGNUP_DATE AS CUSTOMERS.SIGNUP_DATE
      WITH SYNONYMS = ('acquisition date', 'onboarding date')
      COMMENT = 'Date customer was acquired',
    
    -- USAGE_EVENTS dimensions
    USAGE_EVENTS.EVENT_ID AS USAGE_EVENTS.EVENT_ID
      COMMENT = 'Unique event identifier',
    
    USAGE_EVENTS.CUSTOMER_ID AS USAGE_EVENTS.CUSTOMER_ID
      COMMENT = 'Customer associated with usage event',
    
    USAGE_EVENTS.FEATURE_USED AS USAGE_EVENTS.FEATURE_USED
      WITH SYNONYMS = ('product capability', 'platform feature')
      COMMENT = 'Product feature utilized',
    
    USAGE_EVENTS.EVENT_DATE AS USAGE_EVENTS.EVENT_DATE
      WITH SYNONYMS = ('activity date')
      COMMENT = 'Date of platform activity',
    
    -- SUPPORT_TICKETS dimensions
    SUPPORT_TICKETS.TICKET_ID AS SUPPORT_TICKETS.TICKET_ID
      COMMENT = 'Unique ticket identifier',
    
    SUPPORT_TICKETS.CUSTOMER_ID AS SUPPORT_TICKETS.CUSTOMER_ID
      COMMENT = 'Customer who submitted ticket',
    
    SUPPORT_TICKETS.CATEGORY AS SUPPORT_TICKETS.CATEGORY
      WITH SYNONYMS = ('issue type', 'ticket category')
      COMMENT = 'Type of support issue',
    
    SUPPORT_TICKETS.PRIORITY AS SUPPORT_TICKETS.PRIORITY
      WITH SYNONYMS = ('urgency level')
      COMMENT = 'Ticket priority level',
    
    SUPPORT_TICKETS.STATUS AS SUPPORT_TICKETS.STATUS
      COMMENT = 'Current ticket status',
    
    SUPPORT_TICKETS.TICKET_TEXT AS SUPPORT_TICKETS.TICKET_TEXT
      COMMENT = 'Ticket description text',
    
    SUPPORT_TICKETS.CREATED_DATE AS SUPPORT_TICKETS.CREATED_DATE
      COMMENT = 'Ticket creation date',
    
    -- CHURN_EVENTS dimensions
    CHURN_EVENTS.CHURN_ID AS CHURN_EVENTS.CHURN_ID
      COMMENT = 'Unique churn event identifier',
    
    CHURN_EVENTS.CUSTOMER_ID AS CHURN_EVENTS.CUSTOMER_ID
      COMMENT = 'Churned customer identifier',
    
    CHURN_EVENTS.CHURN_REASON AS CHURN_EVENTS.CHURN_REASON
      WITH SYNONYMS = ('departure reason', 'cancellation cause')
      COMMENT = 'Reason for customer departure',
    
    CHURN_EVENTS.FINAL_PLAN_TYPE AS CHURN_EVENTS.FINAL_PLAN_TYPE
      COMMENT = 'Subscription tier at time of churn',
    
    CHURN_EVENTS.CHURN_DATE AS CHURN_EVENTS.CHURN_DATE
      WITH SYNONYMS = ('departure date', 'cancellation date')
      COMMENT = 'Date of customer churn'
  )
  
  FACTS (
    -- CUSTOMERS facts
    CUSTOMERS.MONTHLY_REVENUE AS CUSTOMERS.MONTHLY_REVENUE
      WITH SYNONYMS = ('MRR', 'recurring revenue')
      COMMENT = 'Monthly recurring revenue per customer',
    
    -- USAGE_EVENTS facts
    USAGE_EVENTS.SESSION_DURATION_MINUTES AS USAGE_EVENTS.SESSION_DURATION_MINUTES
      WITH SYNONYMS = ('session time', 'engagement duration')
      COMMENT = 'Session duration in minutes',
    
    USAGE_EVENTS.ACTIONS_COUNT AS USAGE_EVENTS.ACTIONS_COUNT
      WITH SYNONYMS = ('activity volume', 'interaction count')
      COMMENT = 'Number of actions per session',
    
    -- SUPPORT_TICKETS facts
    SUPPORT_TICKETS.RESOLUTION_TIME_HOURS AS SUPPORT_TICKETS.RESOLUTION_TIME_HOURS
      WITH SYNONYMS = ('resolution duration', 'time to close')
      COMMENT = 'Hours to resolve ticket',
    
    SUPPORT_TICKETS.SATISFACTION_SCORE AS SUPPORT_TICKETS.SATISFACTION_SCORE
      WITH SYNONYMS = ('CSAT score', 'satisfaction rating')
      COMMENT = 'Customer satisfaction score (1-5)',
    
    -- CHURN_EVENTS facts
    CHURN_EVENTS.DAYS_SINCE_SIGNUP AS CHURN_EVENTS.DAYS_SINCE_SIGNUP
      WITH SYNONYMS = ('customer lifetime', 'tenure days')
      COMMENT = 'Days from signup to churn',
    
    CHURN_EVENTS.FINAL_MONTHLY_REVENUE AS CHURN_EVENTS.FINAL_MONTHLY_REVENUE
      WITH SYNONYMS = ('lost revenue', 'churned MRR')
      COMMENT = 'Revenue lost at churn'
  )
  
  METRICS (
    -- Customer metrics
    CUSTOMERS.TOTAL_CUSTOMERS AS COUNT(CUSTOMERS.CUSTOMER_ID)
      WITH SYNONYMS = ('customer base', 'total accounts')
      COMMENT = 'Total number of customers',
    
    CUSTOMERS.ACTIVE_CUSTOMERS AS COUNT(CASE WHEN CUSTOMERS.STATUS = 'active' THEN CUSTOMERS.CUSTOMER_ID END)
      WITH SYNONYMS = ('current customers')
      COMMENT = 'Number of active customers',
    
    CUSTOMERS.AVERAGE_REVENUE_PER_USER AS AVG(CUSTOMERS.MONTHLY_REVENUE)
      WITH SYNONYMS = ('ARPU', 'avg revenue')
      COMMENT = 'Average revenue per customer',
    
    CUSTOMERS.TOTAL_MRR AS SUM(CUSTOMERS.MONTHLY_REVENUE)
      WITH SYNONYMS = ('total recurring revenue', 'aggregate MRR')
      COMMENT = 'Total monthly recurring revenue',
    
    -- Usage metrics
    USAGE_EVENTS.AVERAGE_SESSION_DURATION AS AVG(USAGE_EVENTS.SESSION_DURATION_MINUTES)
      WITH SYNONYMS = ('avg session time')
      COMMENT = 'Average customer session duration',
    
    USAGE_EVENTS.TOTAL_PLATFORM_ACTIONS AS SUM(USAGE_EVENTS.ACTIONS_COUNT)
      WITH SYNONYMS = ('total activity', 'aggregate actions')
      COMMENT = 'Total actions taken across all sessions',
    
    USAGE_EVENTS.UNIQUE_ACTIVE_USERS AS COUNT(DISTINCT USAGE_EVENTS.CUSTOMER_ID)
      WITH SYNONYMS = ('active user count', 'engaged customers')
      COMMENT = 'Number of unique customers with platform activity',
    
    -- Support metrics
    SUPPORT_TICKETS.AVERAGE_RESOLUTION_TIME AS AVG(SUPPORT_TICKETS.RESOLUTION_TIME_HOURS)
      WITH SYNONYMS = ('avg time to resolve')
      COMMENT = 'Average ticket resolution time',
    
    SUPPORT_TICKETS.AVERAGE_SATISFACTION AS AVG(SUPPORT_TICKETS.SATISFACTION_SCORE)
      WITH SYNONYMS = ('avg CSAT', 'mean satisfaction')
      COMMENT = 'Average customer satisfaction with support',
    
    -- Churn metrics
    CHURN_EVENTS.CHURNED_CUSTOMERS AS COUNT(CHURN_EVENTS.CUSTOMER_ID)
      WITH SYNONYMS = ('lost customers', 'departed accounts')
      COMMENT = 'Number of churned customers',
    
    CHURN_EVENTS.AVERAGE_CUSTOMER_LIFETIME AS AVG(CHURN_EVENTS.DAYS_SINCE_SIGNUP)
      WITH SYNONYMS = ('avg tenure', 'mean lifetime')
      COMMENT = 'Average customer lifetime before churn',
    
    CHURN_EVENTS.TOTAL_REVENUE_AT_RISK AS SUM(CHURN_EVENTS.FINAL_MONTHLY_REVENUE)
      WITH SYNONYMS = ('total lost revenue', 'churned MRR total')
      COMMENT = 'Total revenue lost from churned customers'
  );

-- Verify the semantic view was created
DESCRIBE SEMANTIC VIEW STRATEGIC_RESEARCH_ANALYST;

-- ============================================================================
-- Show all semantic views
-- ============================================================================
SHOW SEMANTIC VIEWS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;

