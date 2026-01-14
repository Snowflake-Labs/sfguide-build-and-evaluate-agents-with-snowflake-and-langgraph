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
│                      SUPERVISOR (Planning)                       │
│               Plans execution and routes queries                 │
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
│                 Snowflake AI Tools                              │
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

## Snowflake Setup

This demo uses **Snowflake Git Integration** to clone the repository and load data.

### Step 1: Setup Git Integration (in Snowsight)

First, create the database and clone this repository into Snowflake:

```sql
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

-- Verify repository contents
LS @customer_intelligence_demo/branches/main/;
```

### Step 2: Run Setup Scripts

After Git integration is set up, navigate to the SQL scripts in the repository and run them **in order**:

| Order | Script | Purpose |
|-------|--------|---------|
| 1 | `sql/01_setup_database_and_load_data.sql` | Creates tables and loads CSV data |
| 2 | `sql/02_setup_cortex_search.sql` | Creates Cortex Search services |
| 3 | `sql/03_setup_semantic_views.sql` | Creates Semantic Views for Cortex Analyst |
| 4 | `sql/04_setup_udfs.sql` | Creates AI UDFs (tools for agents) |
| 5 | `sql/05_setup_cortex_agents.sql` | Creates the three Cortex Agents |

> **Note:** Run scripts in order as later scripts depend on earlier ones.

### Step 3: Verify Data Loaded

After running `01_setup_database_and_load_data.sql`, verify the data:

```sql
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS;
```

### Step 4: Verify Agents Created

After running all scripts:

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;
SHOW SEMANTIC VIEWS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;
SHOW USER FUNCTIONS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
```

### Step 5: Update Repository (Optional)

To pull latest changes from GitHub:

```sql
ALTER GIT REPOSITORY CUSTOMER_INTELLIGENCE_DB.PUBLIC.customer_intelligence_demo FETCH;
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
| `01_setup_database_and_load_data.sql` | Creates tables and loads demo data from CSV files |
| `02_setup_cortex_search.sql` | Creates Cortex Search services for ticket and customer search |
| `03_setup_semantic_views.sql` | Creates Semantic Views for Cortex Analyst text-to-SQL |
| `04_setup_udfs.sql` | Creates AI-powered UDFs (tools used by agents) |
| `05_setup_cortex_agents.sql` | Creates CONTENT_AGENT, DATA_ANALYST_AGENT, and RESEARCH_AGENT |

## Running the Demo

### Option 1: Run the notebook

Choose `run all` to execute the entire notebook. View agent performance in Snowsight under AI > Evaluations.

### Option 2: LangGraph Studio

```bash
langgraph dev
```

This opens LangGraph Studio in your browser at `https://smith.langchain.com/studio/`

### Option 3: Run Directly

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
├── build_and_evaluat....ipynb # Notebook with LangGraph application
├── langgraph.json             # LangGraph Studio configuration
├── requirements.txt           # Python dependencies
├── .env.template              # Environment template
├── data_generation.py         # Demo data generator
│
├── sql/                       # Snowflake setup scripts
│   ├── 01_setup_database_and_load_data.sql
│   ├── 02_setup_cortex_search.sql
│   ├── 03_setup_semantic_views.sql
│   ├── 04_setup_udfs.sql
│   └── 05_setup_cortex_agents.sql
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
