# Multi-Agent Customer Intelligence Demo

A sophisticated multi-agent AI system built with **LangGraph** and **Snowflake Cortex** for customer analytics, churn prediction, and business intelligence.

> **Quick Start:** Clone this repo directly in Snowflake using Git Integration, then run LangGraph Studio locally to interact with the agents.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Query                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SUPERVISOR (Claude)                           │
│              Routes queries & synthesizes responses              │
└─────────────────────────────────────────────────────────────────┘
                              │
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  CONTENT_AGENT  │  │ DATA_ANALYST    │  │ RESEARCH_AGENT  │
│                 │  │ _AGENT          │  │                 │
│ • Sentiment     │  │ • Metrics       │  │ • Market Intel  │
│ • Feedback      │  │ • Behavior      │  │ • Strategy      │
│ • Support       │  │ • Analytics     │  │ • Trends        │
└─────────────────┘  └─────────────────┘  └─────────────────┘
           │                  │                  │
           └──────────────────┼──────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Snowflake AI Tools                               │
│     Cortex Search │ Cortex Analyst │ Custom AI UDFs             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SUPERVISOR (Synthesis)                        │
│              Creates executive summary response                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Snowflake Account** with Cortex features enabled
- **Python 3.9+** (for local LangGraph development)
- **LangGraph CLI** (`pip install langgraph-cli`)
- **LangSmith Account** (optional, for tracing)

---

## Snowflake Setup (Git Integration)

This demo uses **Snowflake Git Integration** to clone and run setup scripts directly in Snowflake.

### Step 1: Clone Repository in Snowflake

Run this in Snowsight to clone the repo:

```sql
-- Create API integration for GitHub (public repo, no secrets needed)
CREATE API INTEGRATION IF NOT EXISTS github_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/Snowflake-Labs/')
    ENABLED = TRUE;

-- Create database for demo
CREATE DATABASE IF NOT EXISTS CUSTOMER_INTELLIGENCE_DB;
USE DATABASE CUSTOMER_INTELLIGENCE_DB;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- Clone the GitHub repository
CREATE OR REPLACE GIT REPOSITORY customer_intelligence_demo
    API_INTEGRATION = github_api_integration
    ORIGIN = 'https://github.com/Snowflake-Labs/sfguide-build-and-evaluate-agents-with-snowflake-and-langgraph.git';

-- Verify the repository
SHOW GIT BRANCHES IN customer_intelligence_demo;
LS @customer_intelligence_demo/branches/main/sql/;
```

### Step 2: Run Setup Scripts (in Snowsight)

```sql
-- Create database and tables
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/01_setup_database.sql;

-- Load demo data from CSV files (uses Snowpark stored procedure)
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/02_load_data.sql;

-- Create Cortex Search services
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/03_setup_cortex_search.sql;

-- Create Semantic Views for Cortex Analyst
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/04_create_semantic_views.sql;

-- Create custom AI UDFs (tools for agents)
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/05_setup_udfs.sql;

-- Create Cortex Agents
EXECUTE IMMEDIATE FROM @customer_intelligence_demo/branches/main/sql/06_setup_cortex_agents.sql;
```

### Step 3: Verify Data Loaded

```sql
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;
```

### Step 4: Update Repository (Optional)

Pull latest changes:

```sql
ALTER GIT REPOSITORY customer_intelligence_demo FETCH;
```

---

## Local Development Setup

For running the LangGraph application locally:

### Install Dependencies

```bash
pip install -r requirements.txt
pip install langgraph-cli
```

### Configure Environment

```bash
cp .env.template .env
```

Edit `.env`:

```env
SNOWFLAKE_ACCOUNT=your_account_identifier
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_DATABASE=CUSTOMER_INTELLIGENCE_DB
SNOWFLAKE_SCHEMA=PUBLIC
SNOWFLAKE_WAREHOUSE=your_warehouse
SNOWFLAKE_ROLE=your_role

# Optional: LangSmith tracing
LANGSMITH_API_KEY=your_langsmith_api_key
```

### Configure Agent Location

Update `studio_app.py` to match your agent database/schema:

```python
agent_database = "SNOWFLAKE_INTELLIGENCE"  # Your agent database
agent_schema = "AGENTS"                     # Your agent schema
```

---

## SQL Scripts Reference

| Script | Purpose |
|--------|---------|
| `00_run_all_setup.sql` | Master script with Git integration setup |
| `01_setup_database.sql` | Creates database, schema, and tables |
| `02_load_data.sql` | Loads CSV data from Git repo via Snowpark |
| `03_setup_cortex_search.sql` | Creates Cortex Search service |
| `04_create_semantic_views.sql` | Creates Semantic Views for Cortex Analyst |
| `05_setup_udfs.sql` | Creates AI UDFs (tools for agents) |
| `06_setup_cortex_agents.sql` | Creates the three Cortex Agents |

## Running the Demo

### Option 1: LangGraph Studio (Recommended)

```bash
langgraph dev
```

This opens LangGraph Studio in your browser at `https://smith.langchain.com/studio/`

### Option 2: Run Directly

```bash
python studio_app.py
```

## Test Queries

Try these business scenarios:

| Query Type | Example |
|------------|---------|
| **Content Analysis** | "Assess the churn risk for customers complaining about API issues." |
| **Data Analytics** | "What's the average session duration for enterprise vs professional customers?" |
| **Strategic Research** | "What industries represent our best expansion opportunities?" |
| **Churn Prediction** | "Which customers are most likely to churn in the next 30 days?" |
| **Support Analysis** | "What are the most common support issues for enterprise customers?" |

## Project Structure

```
├── studio_app.py              # Main LangGraph application
├── langgraph.json             # LangGraph Studio configuration
├── requirements.txt           # Python dependencies
├── .env.template              # Environment template
├── data_generation.py         # Demo data generator
│
├── sql/                       # Snowflake setup scripts
│   ├── 00_run_all_setup.sql   # Master script (Git integration)
│   ├── 01_setup_database.sql  # Database, schema, tables
│   ├── 02_load_data.sql       # Stage creation & CSV loading
│   ├── 03_setup_cortex_search.sql
│   ├── 04_create_semantic_views.sql
│   ├── 05_setup_udfs.sql      # AI UDFs (tools for agents)
│   └── 06_setup_cortex_agents.sql
│
└── README.md
```

## Troubleshooting

### Git Integration Issues
- Ensure your role has `CREATE INTEGRATION` privileges
- For private repos, create a secret with your GitHub token
- Run `ALTER GIT REPOSITORY ... FETCH` to pull latest changes

### "401 Unauthorized" Error
- Check your Snowflake credentials in `.env`
- Verify your role has `USAGE` on the Cortex Agents
- Ensure `agent_database` and `agent_schema` in `studio_app.py` are correct

### "No human message found"
- Enter the query in the "Messages" field in LangGraph Studio
- Leave the "Routing Decision" field empty (it's internal)

### Agent returns 0 customers
- Verify Cortex Search service includes `customer_id` in ATTRIBUTES
- Check that demo data was generated (`python data_generation.py`)

### Connection Issues
- Verify `SNOWFLAKE_ACCOUNT` format (e.g., `org-account` or `account.region`)
- Check warehouse is running and you have access

## How It Works

1. **User submits query** → LangGraph Studio
2. **Supervisor analyzes** → Routes to appropriate agent (CONTENT, DATA_ANALYST, or RESEARCH)
3. **Agent executes** → Uses Cortex Search, Analyst, and custom UDFs
4. **Supervisor synthesizes** → Creates executive summary with insights, recommendations, and data gaps
5. **Response returned** → Clean, actionable business intelligence

## License

Apache 2.0 - See [LICENSE](LICENSE) file.
