-- ============================================================================
-- 06_setup_cortex_agents.sql
-- Creates the three Cortex Agents for the multi-agent demo
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
USE DATABASE SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS AGENTS;
USE SCHEMA AGENTS;

-- ============================================================================
-- CONTENT_AGENT
-- Tools: Cortex Search + Generic UDF
-- ============================================================================

CREATE AGENT IF NOT EXISTS CONTENT_AGENT
  COMMENT = 'Customer feedback and sentiment analysis specialist'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    system: |
      The Content Agent analyzes customer feedback, support interactions, and satisfaction trends.
      Key Capabilities: Sentiment analysis, pattern recognition, churn risk evaluation.

    response: |
      Response Structure:
      1. EXECUTIVE SUMMARY (2-3 sentences)
      2. KEY INSIGHTS (3-5 bullet points)
      3. RECOMMENDED ACTIONS

  tools:
    - tool_spec:
        type: cortex_search
        name: CUSTOMER_FEEDBACK_SEARCH
        description: Semantic search across customer support tickets to find complaints and patterns.
    - tool_spec:
        type: generic
        name: CUSTOMER_CONTENT_ANALYZER
        description: AI analysis of customer feedback providing sentiment and recommendations.
        input_schema:
          type: object
          properties:
            customer_ids_string:
              type: string
              description: Comma-separated list of customer IDs to analyze
            analysis_type:
              type: string
              description: Type of analysis to perform
          required:
            - customer_ids_string

  tool_resources:
    CUSTOMER_FEEDBACK_SEARCH:
      search_service: "CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS_SEARCH"
      id_column: "ticket_id"
      title_column: "ticket_text"
    CUSTOMER_CONTENT_ANALYZER:
      type: function
      execution_environment:
        type: warehouse
        warehouse: COMPUTE_WH
      identifier: "CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_CONTENT_V2"
  $$;

-- ============================================================================
-- DATA_ANALYST_AGENT  
-- Tools: Cortex Analyst + Generic UDF
-- ============================================================================

CREATE AGENT IF NOT EXISTS DATA_ANALYST_AGENT
  COMMENT = 'Customer behavior and analytics specialist'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    system: |
      Expert analyst for customer engagement, usage patterns, and churn prediction.

    response: |
      Response Structure:
      1. EXECUTIVE SUMMARY
      2. KEY INSIGHTS
      3. RECOMMENDED ACTIONS

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: BUSINESS_INTELLIGENCE_ANALYST
        description: Natural language to SQL for customer behavior analytics.
    - tool_spec:
        type: generic
        name: CUSTOMER_BEHAVIOR_ANALYZER
        description: AI analysis of customer behavior patterns and churn risk.
        input_schema:
          type: object
          properties:
            customer_ids_string:
              type: string
              description: Comma-separated list of customer IDs
            segment_name:
              type: string
              description: Name of the customer segment
          required:
            - customer_ids_string

  tool_resources:
    BUSINESS_INTELLIGENCE_ANALYST:
      semantic_view: "CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMER_BEHAVIOR_ANALYST"
    CUSTOMER_BEHAVIOR_ANALYZER:
      type: function
      execution_environment:
        type: warehouse
        warehouse: COMPUTE_WH
      identifier: "CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_BEHAVIOR_SEGMENT_V2"
  $$;

-- ============================================================================
-- RESEARCH_AGENT
-- Tools: Cortex Analyst + Generic UDF
-- ============================================================================

CREATE AGENT IF NOT EXISTS RESEARCH_AGENT
  COMMENT = 'Market intelligence and strategic analysis specialist'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    system: |
      Strategic research specialist for executive-level business analysis.

    response: |
      Response Structure:
      1. EXECUTIVE SUMMARY
      2. KEY INSIGHTS
      3. RECOMMENDED ACTIONS

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: STRATEGIC_MARKET_ANALYST
        description: Executive market intelligence converting questions into business analysis.
    - tool_spec:
        type: generic
        name: CUSTOMER_SEGMENT_INTELLIGENCE
        description: AI analysis of customer segments for strategic insights.
        input_schema:
          type: object
          properties:
            customer_ids_string:
              type: string
              description: Comma-separated list of customer IDs
            segment_name:
              type: string
              description: Name of the segment for analysis
          required:
            - customer_ids_string

  tool_resources:
    STRATEGIC_MARKET_ANALYST:
      semantic_view: "CUSTOMER_INTELLIGENCE_DB.PUBLIC.STRATEGIC_RESEARCH_ANALYST"
    CUSTOMER_SEGMENT_INTELLIGENCE:
      type: function
      execution_environment:
        type: warehouse
        warehouse: COMPUTE_WH
      identifier: "CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_SEGMENT_V2"
  $$;

-- Verify agents created
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
