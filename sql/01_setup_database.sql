-- ============================================================================
-- 01_setup_database.sql
-- Creates the database, schema, and tables for the demo
-- ============================================================================

-- Create database
CREATE DATABASE IF NOT EXISTS CUSTOMER_INTELLIGENCE_DB;
USE DATABASE CUSTOMER_INTELLIGENCE_DB;

-- Create schema
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- ============================================================================
-- CUSTOMERS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id VARCHAR(50) PRIMARY KEY,
    signup_date DATE NOT NULL,
    plan_type VARCHAR(20) NOT NULL,
    company_size VARCHAR(20) NOT NULL,
    industry VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    monthly_revenue DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- USAGE_EVENTS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE USAGE_EVENTS (
    event_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    event_date DATE NOT NULL,
    feature_used VARCHAR(50) NOT NULL,
    session_duration_minutes INTEGER NOT NULL,
    actions_count INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- SUPPORT_TICKETS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE SUPPORT_TICKETS (
    ticket_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    created_date DATE NOT NULL,
    category VARCHAR(30) NOT NULL,
    priority VARCHAR(10) NOT NULL,
    status VARCHAR(20) NOT NULL,
    resolution_time_hours INTEGER,
    satisfaction_score INTEGER,
    ticket_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- CHURN_EVENTS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE CHURN_EVENTS (
    churn_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    churn_date DATE NOT NULL,
    churn_reason VARCHAR(50) NOT NULL,
    days_since_signup INTEGER NOT NULL,
    final_plan_type VARCHAR(20),
    final_monthly_revenue DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- VERIFY SETUP
-- ============================================================================
SHOW TABLES IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;

-- Verify data loaded
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;
