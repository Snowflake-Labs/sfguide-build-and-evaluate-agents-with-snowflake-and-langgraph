#!/usr/bin/env python3
"""
Multi-Agent Churn Demo - Hour 1: Data Generation
Creates 4 tables with 10K realistic records for the churn analysis demo.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
from langchain_snowflake import create_session_from_env

from dotenv import load_dotenv

load_dotenv()

# Set seeds for reproducible results
random.seed(42)
np.random.seed(42)

def main():
    print("🚀 Starting Hour 1: Data Generation")
    print("=" * 50)
    
    # Initialize Snowflake session
    session = create_session_from_env()
    print(f"✅ Connected to Snowflake: {session.get_current_database()}.{session.get_current_schema()}")
    
    # Step 1: Create Tables
    print("\n📋 Step 1: Creating Tables...")
    create_tables(session)
    
    # Step 2: Generate and Insert Data
    print("\n📊 Step 2: Generating Data...")
    customers_data = generate_customers_data(10000)
    insert_customers_data(session, customers_data)
    
    usage_events_data = generate_usage_events(customers_data[:2000])  # Subset for speed
    insert_usage_events_data(session, usage_events_data)
    
    support_tickets_data = generate_support_tickets(customers_data)
    insert_support_tickets_data(session, support_tickets_data)
    
    churn_events_data = generate_churn_events(customers_data)
    insert_churn_events_data(session, churn_events_data)
    
    # Step 3: Validate Data
    print("\n🔍 Step 3: Validating Data...")
    validate_data(session)
    
    print("\n✅ Hour 1 Complete!")
    print("🎯 Ready for Hour 2: Custom UDFs")

def create_tables(session):
    """Create the 4 core tables."""
    
    # Grant ownership on the schema to the current role
    current_role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]
    session.sql(f"GRANT OWNERSHIP ON SCHEMA PUBLIC TO ROLE {current_role}").collect()
    print(f"✅ Granted ownership on schema PUBLIC to role {current_role}")
    
    tables = {
        "CUSTOMERS": """
            CREATE OR REPLACE TABLE CUSTOMERS (
                customer_id VARCHAR(50) PRIMARY KEY,
                signup_date DATE NOT NULL,
                plan_type VARCHAR(20) NOT NULL,
                company_size VARCHAR(20) NOT NULL,
                industry VARCHAR(30) NOT NULL,
                status VARCHAR(20) NOT NULL DEFAULT 'active',
                monthly_revenue DECIMAL(10,2),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
            )
        """,
        
        "USAGE_EVENTS": """
            CREATE OR REPLACE TABLE USAGE_EVENTS (
                event_id VARCHAR(50) PRIMARY KEY,
                customer_id VARCHAR(50) NOT NULL,
                event_date DATE NOT NULL,
                feature_used VARCHAR(50) NOT NULL,
                session_duration_minutes INTEGER NOT NULL,
                actions_count INTEGER NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
            )
        """,
        
        "SUPPORT_TICKETS": """
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
            )
        """,
        
        "CHURN_EVENTS": """
            CREATE OR REPLACE TABLE CHURN_EVENTS (
                churn_id VARCHAR(50) PRIMARY KEY,
                customer_id VARCHAR(50) NOT NULL,
                churn_date DATE NOT NULL,
                churn_reason VARCHAR(50) NOT NULL,
                days_since_signup INTEGER NOT NULL,
                final_plan_type VARCHAR(20) NOT NULL,
                final_monthly_revenue DECIMAL(10,2),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
            )
        """
    }
    
    for table_name, ddl in tables.items():
        session.sql(ddl).collect()
        print(f"✅ {table_name} table created")

def generate_customers_data(num_customers=10000):
    """Generate realistic customer data."""
    
    plan_types = ['starter', 'professional', 'enterprise', 'premium']
    plan_weights = [0.4, 0.35, 0.15, 0.1]
    
    company_sizes = ['small', 'medium', 'large', 'enterprise']
    size_weights = [0.5, 0.3, 0.15, 0.05]
    
    industries = [
        'technology', 'healthcare', 'finance', 'retail', 'manufacturing',
        'education', 'consulting', 'media', 'real_estate', 'non_profit'
    ]
    
    revenue_base = {
        'starter': {'small': 29, 'medium': 49, 'large': 99, 'enterprise': 199},
        'professional': {'small': 99, 'medium': 199, 'large': 399, 'enterprise': 799},
        'enterprise': {'small': 299, 'medium': 599, 'large': 1199, 'enterprise': 2399},
        'premium': {'small': 599, 'medium': 1199, 'large': 2399, 'enterprise': 4799}
    }
    
    customers = []
    start_date = datetime(2022, 1, 1)
    end_date = datetime(2024, 10, 1)
    
    for i in range(num_customers):
        customer_id = f"CUST_{i+1:06d}"
        
        # Generate signup date
        days_range = (end_date - start_date).days
        random_days = random.randint(0, days_range)
        signup_date = start_date + timedelta(days=random_days)
        
        # Select company size and correlated plan type
        company_size = np.random.choice(company_sizes, p=size_weights)
        
        if company_size == 'enterprise':
            plan_weights_adj = [0.1, 0.2, 0.4, 0.3]
        elif company_size == 'large':
            plan_weights_adj = [0.2, 0.4, 0.3, 0.1]
        elif company_size == 'medium':
            plan_weights_adj = [0.3, 0.4, 0.2, 0.1]
        else:  # small
            plan_weights_adj = [0.6, 0.3, 0.08, 0.02]
        
        plan_type = np.random.choice(plan_types, p=plan_weights_adj)
        industry = random.choice(industries)
        
        # Calculate revenue with variance
        base_revenue = revenue_base[plan_type][company_size]
        revenue_variance = random.uniform(0.8, 1.2)
        monthly_revenue = round(base_revenue * revenue_variance, 2)
        
        customers.append({
            'customer_id': customer_id,
            'signup_date': signup_date.strftime('%Y-%m-%d'),
            'plan_type': plan_type,
            'company_size': company_size,
            'industry': industry,
            'status': 'active',
            'monthly_revenue': monthly_revenue
        })
    
    print(f"✅ Generated {len(customers)} customer records")
    return customers

def generate_usage_events(customers_data, events_per_customer_avg=50):
    """Generate realistic usage events."""
    
    features = [
        'dashboard_view', 'report_generation', 'data_export', 'user_management',
        'api_calls', 'integrations', 'analytics', 'collaboration', 'mobile_app'
    ]
    
    plan_features = {
        'starter': ['dashboard_view', 'report_generation', 'mobile_app'],
        'professional': ['dashboard_view', 'report_generation', 'data_export', 'analytics', 'mobile_app'],
        'enterprise': ['dashboard_view', 'report_generation', 'data_export', 'user_management', 
                      'api_calls', 'integrations', 'analytics', 'collaboration'],
        'premium': features
    }
    
    usage_events = []
    event_counter = 1
    
    for customer in customers_data:
        customer_id = customer['customer_id']
        signup_date = datetime.strptime(customer['signup_date'], '%Y-%m-%d')
        plan_type = customer['plan_type']
        
        plan_multiplier = {'starter': 0.7, 'professional': 1.0, 'enterprise': 1.5, 'premium': 2.0}
        num_events = int(events_per_customer_avg * plan_multiplier[plan_type] * random.uniform(0.5, 1.5))
        
        end_date = min(datetime(2024, 10, 1), datetime.now())
        days_active = (end_date - signup_date).days
        
        if days_active <= 0:
            continue
        
        available_features = plan_features[plan_type]
        
        for _ in range(num_events):
            random_days = random.randint(0, days_active)
            event_date = signup_date + timedelta(days=random_days)
            
            feature_used = random.choice(available_features)
            
            base_duration = {
                'dashboard_view': 15, 'report_generation': 45, 'data_export': 30,
                'user_management': 20, 'api_calls': 5, 'integrations': 60,
                'analytics': 90, 'collaboration': 35, 'mobile_app': 10
            }
            
            duration = int(base_duration[feature_used] * random.uniform(0.3, 2.0))
            actions_count = random.randint(1, max(1, duration // 3))
            
            usage_events.append({
                'event_id': f"EVT_{event_counter:08d}",
                'customer_id': customer_id,
                'event_date': event_date.strftime('%Y-%m-%d'),
                'feature_used': feature_used,
                'session_duration_minutes': duration,
                'actions_count': actions_count
            })
            
            event_counter += 1
    
    print(f"✅ Generated {len(usage_events)} usage events")
    return usage_events

def generate_support_tickets(customers_data, tickets_per_customer_avg=3):
    """Generate realistic support tickets with text for sentiment analysis."""
    
    categories = [
        'billing', 'technical_issue', 'feature_request', 'account_access',
        'integration_help', 'data_export', 'performance', 'training', 'bug_report'
    ]
    
    priorities = ['low', 'medium', 'high', 'urgent']
    priority_weights = [0.4, 0.35, 0.2, 0.05]
    
    statuses = ['resolved', 'closed', 'pending']
    status_weights = [0.7, 0.25, 0.05]
    
    # Realistic ticket text templates by category
    ticket_templates = {
        'billing': [
            "I was charged twice this month and need a refund. This is very frustrating as it affects our budget.",
            "Can you help me understand the billing changes? The new pricing seems much higher than expected.",
            "My payment failed but I'm not sure why. Can you help me resolve this quickly?",
            "I need to downgrade my plan but can't find the option. The current cost is too high for our small team."
        ],
        'technical_issue': [
            "The dashboard is loading very slowly and sometimes crashes. This is impacting our daily operations.",
            "I can't export data - getting an error message every time I try. This is blocking our reporting.",
            "The mobile app keeps crashing when I try to view reports. Very disappointing experience.",
            "API calls are failing intermittently. Our integration is broken and customers are complaining."
        ],
        'feature_request': [
            "Would love to see dark mode added to the interface. Many of our team members have requested this.",
            "Can you add more export formats? We need Excel compatibility for our stakeholders.",
            "Real-time notifications would be amazing for our workflow. Currently we miss important updates.",
            "Better mobile experience would help our field team access data on the go."
        ],
        'account_access': [
            "I forgot my password and the reset email isn't coming through. Need access urgently.",
            "Can you help me add new team members to our account? The process isn't clear.",
            "My account seems to be locked after multiple login attempts. Please help unlock it.",
            "Need to transfer account ownership to a new admin. What's the process for this?"
        ],
        'integration_help': [
            "Having trouble connecting to Salesforce. The integration guide isn't clear enough.",
            "API documentation is confusing. Can someone walk me through the setup process?",
            "Webhook setup is failing. Getting authentication errors that I can't resolve.",
            "Need help with custom integration. Our development team is stuck on the implementation."
        ],
        'data_export': [
            "Large data exports are timing out. Need a solution for exporting our complete dataset.",
            "Export format is missing some columns we need. Can this be customized?",
            "Scheduled exports stopped working last week. Our automated reports are broken.",
            "Need help with bulk data migration. Moving to new system and need all historical data."
        ],
        'performance': [
            "System is very slow during peak hours. Reports take forever to load.",
            "Dashboard performance has degraded significantly over the past month.",
            "Query timeouts are happening frequently. This is impacting our productivity.",
            "Page load times are unacceptable. Considering switching to a competitor."
        ],
        'training': [
            "New team members need training on advanced features. Do you offer sessions?",
            "Looking for best practices documentation. Want to optimize our usage.",
            "Can you provide training materials for our specific use case?",
            "Onboarding process could be improved. New users are struggling to get started."
        ],
        'bug_report': [
            "Found a bug in the reporting module. Charts are showing incorrect data.",
            "Filter functionality is broken on the analytics page. Please investigate.",
            "Getting JavaScript errors in the browser console. Interface is unstable.",
            "Data synchronization issue - seeing stale data that should have updated hours ago."
        ]
    }
    
    support_tickets = []
    ticket_counter = 1
    
    # Generate tickets for subset of customers
    customers_with_tickets = random.sample(customers_data, min(len(customers_data), 3000))
    
    for customer in customers_with_tickets:
        customer_id = customer['customer_id']
        signup_date = datetime.strptime(customer['signup_date'], '%Y-%m-%d')
        
        num_tickets = np.random.poisson(tickets_per_customer_avg)
        if num_tickets == 0:
            continue
        
        for _ in range(min(num_tickets, 10)):
            days_since_signup = (datetime(2024, 10, 1) - signup_date).days
            if days_since_signup <= 0:
                continue
            
            random_days = random.randint(1, days_since_signup)
            ticket_date = signup_date + timedelta(days=random_days)
            
            category = random.choice(categories)
            priority = np.random.choice(priorities, p=priority_weights)
            status = np.random.choice(statuses, p=status_weights)
            
            ticket_text = random.choice(ticket_templates[category])
            
            # Resolution time based on priority
            if status in ['resolved', 'closed']:
                priority_hours = {'low': 48, 'medium': 24, 'high': 8, 'urgent': 2}
                base_hours = priority_hours[priority]
                resolution_time = int(base_hours * random.uniform(0.5, 2.0))
            else:
                resolution_time = None
            
            # Satisfaction score correlated with resolution time
            if status in ['resolved', 'closed']:
                if priority == 'urgent' and resolution_time <= 4:
                    satisfaction = random.choice([4, 5, 5])
                elif resolution_time and resolution_time > 72:
                    satisfaction = random.choice([1, 2, 2, 3])
                else:
                    satisfaction = random.choice([2, 3, 3, 4, 4])
            else:
                satisfaction = None
            
            support_tickets.append({
                'ticket_id': f"TKT_{ticket_counter:08d}",
                'customer_id': customer_id,
                'created_date': ticket_date.strftime('%Y-%m-%d'),
                'category': category,
                'priority': priority,
                'status': status,
                'resolution_time_hours': resolution_time,
                'satisfaction_score': satisfaction,
                'ticket_text': ticket_text
            })
            
            ticket_counter += 1
    
    print(f"✅ Generated {len(support_tickets)} support tickets")
    return support_tickets

def generate_churn_events(customers_data):
    """Generate churn events with the key business story: spike from 3% to 8%."""
    
    churn_reasons = [
        'pricing_too_high', 'poor_performance', 'missing_features', 
        'competitor_switch', 'business_closure', 'poor_support',
        'technical_issues', 'ease_of_use', 'integration_problems'
    ]
    
    # Historical vs recent churn reason patterns
    historical_reason_weights = [0.15, 0.12, 0.15, 0.20, 0.08, 0.10, 0.08, 0.07, 0.05]
    recent_reason_weights = [0.35, 0.25, 0.10, 0.15, 0.03, 0.05, 0.04, 0.02, 0.01]
    
    churn_events = []
    churn_counter = 1
    
    # Define time periods
    recent_cutoff = datetime(2024, 7, 1)  # Last 3 months
    
    # Split customers by signup date
    historical_customers = []
    recent_customers = []
    
    for customer in customers_data:
        signup_date = datetime.strptime(customer['signup_date'], '%Y-%m-%d')
        if signup_date < recent_cutoff:
            historical_customers.append(customer)
        else:
            recent_customers.append(customer)
    
    print(f"📊 Historical customers: {len(historical_customers)}, Recent: {len(recent_customers)}")
    
    # Generate historical churn (3% rate)
    historical_churn_rate = 0.03
    historical_churn_count = int(len(historical_customers) * historical_churn_rate)
    historical_churned = random.sample(historical_customers, historical_churn_count)
    
    for customer in historical_churned:
        customer_id = customer['customer_id']
        signup_date = datetime.strptime(customer['signup_date'], '%Y-%m-%d')
        
        max_days = (recent_cutoff - signup_date).days
        if max_days <= 30:
            continue
        
        min_days = max(30, max_days // 4)
        churn_days = random.randint(min_days, max_days)
        churn_date = signup_date + timedelta(days=churn_days)
        
        churn_reason = np.random.choice(churn_reasons, p=historical_reason_weights)
        
        churn_events.append({
            'churn_id': f"CHN_{churn_counter:08d}",
            'customer_id': customer_id,
            'churn_date': churn_date.strftime('%Y-%m-%d'),
            'churn_reason': churn_reason,
            'days_since_signup': churn_days,
            'final_plan_type': customer['plan_type'],
            'final_monthly_revenue': customer['monthly_revenue']
        })
        
        churn_counter += 1
    
    # Generate recent churn spike (additional 5% for 8% total)
    eligible_for_recent_churn = [c for c in historical_customers if c not in historical_churned]
    recent_churn_rate_additional = 0.05  # Additional 5% to reach 8% total
    recent_churn_count = int(len(eligible_for_recent_churn) * recent_churn_rate_additional)
    recent_churned = random.sample(eligible_for_recent_churn, min(recent_churn_count, len(eligible_for_recent_churn)))
    
    for customer in recent_churned:
        customer_id = customer['customer_id']
        signup_date = datetime.strptime(customer['signup_date'], '%Y-%m-%d')
        
        # Churn date in recent period
        churn_start = recent_cutoff
        churn_end = datetime(2024, 10, 1)
        
        random_days = random.randint(0, (churn_end - churn_start).days)
        churn_date = churn_start + timedelta(days=random_days)
        
        days_since_signup = (churn_date - signup_date).days
        churn_reason = np.random.choice(churn_reasons, p=recent_reason_weights)
        
        churn_events.append({
            'churn_id': f"CHN_{churn_counter:08d}",
            'customer_id': customer_id,
            'churn_date': churn_date.strftime('%Y-%m-%d'),
            'churn_reason': churn_reason,
            'days_since_signup': days_since_signup,
            'final_plan_type': customer['plan_type'],
            'final_monthly_revenue': customer['monthly_revenue']
        })
        
        churn_counter += 1
    
    print(f"✅ Generated {len(churn_events)} churn events")
    print(f"🚨 Historical churn: {len(historical_churned)}, Recent spike: {len(recent_churned)}")
    return churn_events

def insert_customers_data(session, customers_data):
    """Insert customer data in batches."""
    batch_size = 1000
    
    for i in range(0, len(customers_data), batch_size):
        batch = customers_data[i:i + batch_size]
        
        values = []
        for customer in batch:
            values.append(
                f"('{customer['customer_id']}', '{customer['signup_date']}', "
                f"'{customer['plan_type']}', '{customer['company_size']}', "
                f"'{customer['industry']}', '{customer['status']}', {customer['monthly_revenue']})"
            )
        
        insert_sql = f"""
        INSERT INTO CUSTOMERS (customer_id, signup_date, plan_type, company_size, industry, status, monthly_revenue)
        VALUES {', '.join(values)}
        """
        
        session.sql(insert_sql).collect()
    
    print(f"✅ Inserted {len(customers_data)} customers")

def insert_usage_events_data(session, events_data):
    """Insert usage events in batches."""
    batch_size = 1000
    
    for i in range(0, len(events_data), batch_size):
        batch = events_data[i:i + batch_size]
        
        values = []
        for event in batch:
            values.append(
                f"('{event['event_id']}', '{event['customer_id']}', '{event['event_date']}', "
                f"'{event['feature_used']}', {event['session_duration_minutes']}, {event['actions_count']})"
            )
        
        insert_sql = f"""
        INSERT INTO USAGE_EVENTS (event_id, customer_id, event_date, feature_used, session_duration_minutes, actions_count)
        VALUES {', '.join(values)}
        """
        
        session.sql(insert_sql).collect()
    
    print(f"✅ Inserted {len(events_data)} usage events")

def insert_support_tickets_data(session, tickets_data):
    """Insert support tickets in batches."""
    batch_size = 500
    
    for i in range(0, len(tickets_data), batch_size):
        batch = tickets_data[i:i + batch_size]
        
        values = []
        for ticket in batch:
            escaped_text = ticket['ticket_text'].replace("'", "''")
            resolution_time = ticket['resolution_time_hours'] if ticket['resolution_time_hours'] else 'NULL'
            satisfaction = ticket['satisfaction_score'] if ticket['satisfaction_score'] else 'NULL'
            
            values.append(
                f"('{ticket['ticket_id']}', '{ticket['customer_id']}', '{ticket['created_date']}', "
                f"'{ticket['category']}', '{ticket['priority']}', '{ticket['status']}', "
                f"{resolution_time}, {satisfaction}, '{escaped_text}')"
            )
        
        insert_sql = f"""
        INSERT INTO SUPPORT_TICKETS (ticket_id, customer_id, created_date, category, priority, status, 
                                   resolution_time_hours, satisfaction_score, ticket_text)
        VALUES {', '.join(values)}
        """
        
        session.sql(insert_sql).collect()
    
    print(f"✅ Inserted {len(tickets_data)} support tickets")

def insert_churn_events_data(session, churn_data):
    """Insert churn events and update customer status."""
    
    # Insert churn events
    batch_size = 500
    
    for i in range(0, len(churn_data), batch_size):
        batch = churn_data[i:i + batch_size]
        
        values = []
        for churn in batch:
            values.append(
                f"('{churn['churn_id']}', '{churn['customer_id']}', '{churn['churn_date']}', "
                f"'{churn['churn_reason']}', {churn['days_since_signup']}, "
                f"'{churn['final_plan_type']}', {churn['final_monthly_revenue']})"
            )
        
        insert_sql = f"""
        INSERT INTO CHURN_EVENTS (churn_id, customer_id, churn_date, churn_reason, 
                                days_since_signup, final_plan_type, final_monthly_revenue)
        VALUES {', '.join(values)}
        """
        
        session.sql(insert_sql).collect()
    
    # Update customer status to 'churned'
    churned_customer_ids = [f"'{churn['customer_id']}'" for churn in churn_data]
    
    update_sql = f"""
    UPDATE CUSTOMERS 
    SET status = 'churned' 
    WHERE customer_id IN ({', '.join(churned_customer_ids)})
    """
    
    session.sql(update_sql).collect()
    print(f"✅ Inserted {len(churn_data)} churn events and updated customer status")

def validate_data(session):
    """Validate the generated data and show key patterns."""
    
    print("🔍 DATA VALIDATION SUMMARY")
    print("=" * 50)
    
    # Table counts
    tables = ['CUSTOMERS', 'USAGE_EVENTS', 'SUPPORT_TICKETS', 'CHURN_EVENTS']
    for table in tables:
        count = session.sql(f"SELECT COUNT(*) as count FROM {table}").collect()[0]['COUNT']
        print(f"📊 {table}: {count:,} records")
    
    # Churn rate analysis
    churn_analysis = session.sql("""
        SELECT 
            COUNT(CASE WHEN c.status = 'churned' THEN 1 END) as churned_customers,
            COUNT(*) as total_customers,
            ROUND(COUNT(CASE WHEN c.status = 'churned' THEN 1 END) * 100.0 / COUNT(*), 2) as overall_churn_rate
        FROM CUSTOMERS c
    """).collect()[0]
    
    print(f"\n📉 Churn Analysis:")
    print(f"   Total customers: {churn_analysis['TOTAL_CUSTOMERS']:,}")
    print(f"   Churned customers: {churn_analysis['CHURNED_CUSTOMERS']:,}")
    print(f"   Overall churn rate: {churn_analysis['OVERALL_CHURN_RATE']}%")
    
    # Recent churn spike validation
    monthly_churn = session.sql("""
        SELECT 
            DATE_TRUNC('month', churn_date) as month,
            COUNT(*) as churn_count
        FROM CHURN_EVENTS 
        WHERE churn_date >= '2024-01-01'
        GROUP BY DATE_TRUNC('month', churn_date)
        ORDER BY month
    """).collect()
    
    print(f"\n🚨 Monthly Churn Trend (2024):")
    for row in monthly_churn:
        month_str = row['MONTH'].strftime('%Y-%m')
        print(f"   {month_str}: {row['CHURN_COUNT']} churns")
    
    # Top churn reasons in recent spike
    recent_churn_reasons = session.sql("""
        SELECT churn_reason, COUNT(*) as count
        FROM CHURN_EVENTS 
        WHERE churn_date >= '2024-07-01'
        GROUP BY churn_reason 
        ORDER BY count DESC
        LIMIT 5
    """).collect()
    
    print(f"\n🎯 Recent Churn Reasons (July-Oct 2024):")
    for row in recent_churn_reasons:
        print(f"   {row['CHURN_REASON']}: {row['COUNT']} customers")

if __name__ == "__main__":
    main()
