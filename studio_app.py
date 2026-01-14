"""
Multi-Agent Supervisor Workflow for LangGraph Studio

A hub-and-spoke architecture where a supervisor coordinates specialized 
Snowflake Cortex Agents for customer intelligence analysis.

Architecture:
    START → supervisor (planning) → Agent → supervisor (routing) → ... → supervisor (synthesis) → END

Efficiency Features:
- Immutable plan: Created once, executed linearly
- No LLM routing calls: Supervisor uses simple plan lookup  
- Consolidated queries: Single SQL aggregations
- Aggregated error handling: Errors collected, not cascaded
"""

import json
import os
from typing import Dict, List, Optional, Literal
from functools import partial

# LangGraph imports
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command
from langgraph.graph.message import MessagesState

# LangChain imports
from langchain_core.messages import HumanMessage, AIMessage, BaseMessage
from langchain_core.prompts import ChatPromptTemplate

# Fix for langchain_snowflake import compatibility
import langchain.tools
from langchain_core.tools import Tool
langchain.tools.Tool = Tool

# Snowflake imports
from langchain_snowflake import ChatSnowflake, SnowflakeCortexAgent, create_session_from_env
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


# =============================================================================
# STATE DEFINITION
# =============================================================================

class State(MessagesState):
    """Extended state for efficient execution tracking.
    
    - Plan is created ONCE and never modified
    - Agent outputs stored in dedicated field (avoids message parsing)
    - Errors are aggregated, not cascaded
    """
    plan: Optional[Dict] = None
    current_step: int = 0
    agent_outputs: Dict = {}
    execution_errors: List = []
    planning_complete: bool = False


# =============================================================================
# SNOWFLAKE SESSION & AGENTS
# =============================================================================

# Create Snowflake session
session = create_session_from_env()

# Set warehouse
warehouse = os.getenv('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH')
session.sql(f"USE WAREHOUSE {warehouse}").collect()

# Supervisor model for routing and synthesis
supervisor_model = ChatSnowflake(
    session=session,
    model="claude-4-sonnet",
    temperature=0.1,
    max_tokens=2000
)

# Agent configuration
AGENT_DATABASE = "SNOWFLAKE_INTELLIGENCE"
AGENT_SCHEMA = "AGENTS"
AGENT_WAREHOUSE = os.getenv('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH')
AGENT_NAMES = ["CONTENT_AGENT", "DATA_ANALYST_AGENT", "RESEARCH_AGENT"]

# Initialize specialized agents
content_agent = SnowflakeCortexAgent(
    session=session,
    name="CONTENT_AGENT",
    database=AGENT_DATABASE,
    schema=AGENT_SCHEMA,
    warehouse=AGENT_WAREHOUSE,
)

data_analyst_agent = SnowflakeCortexAgent(
    session=session,
    name="DATA_ANALYST_AGENT",
    database=AGENT_DATABASE,
    schema=AGENT_SCHEMA,
    warehouse=AGENT_WAREHOUSE,
)

research_agent = SnowflakeCortexAgent(
    session=session,
    name="RESEARCH_AGENT",
    database=AGENT_DATABASE,
    schema=AGENT_SCHEMA,
    warehouse=AGENT_WAREHOUSE,
)


# =============================================================================
# PROMPTS
# =============================================================================

planning_prompt = """
You are an Executive AI Assistant supervisor. Create DETAILED, ACTIONABLE execution plans.

**CRITICAL EFFICIENCY RULES:**
1. **ONE PLAN, ONE EXECUTION** - Create the plan once. It will NOT be modified during execution.
2. **CONSOLIDATE QUERIES** - Use single SQL aggregations instead of multiple separate queries.
3. **MINIMIZE AGENT CALLS** - Only use multiple agents when their specialized tools are needed.
4. **USE THE RIGHT TOOL** - Each agent has specific tools for specific purposes.

**AVAILABLE AGENTS AND TOOLS:**

| Agent | Tools | Data Access | Best For |
|-------|-------|-------------|----------|
| CONTENT_AGENT | CUSTOMER_FEEDBACK_SEARCH (cortex_search), CUSTOMER_CONTENT_ANALYZER (UDF) | SUPPORT_TICKETS_SEARCH index | Semantic search for complaints/feedback, sentiment analysis |
| DATA_ANALYST_AGENT | BUSINESS_INTELLIGENCE_ANALYST (cortex_analyst), CUSTOMER_BEHAVIOR_ANALYZER (UDF) | CUSTOMER_BEHAVIOR_ANALYST semantic view | Usage patterns, churn analysis, behavior trends |
| RESEARCH_AGENT | STRATEGIC_MARKET_ANALYST (cortex_analyst), CUSTOMER_SEGMENT_INTELLIGENCE (UDF) | STRATEGIC_RESEARCH_ANALYST semantic view | Market intelligence, industry analysis, CLV |

**KEY DATA FIELDS:**
- CUSTOMERS: customer_id, company_size, industry, plan_type, status, signup_date, monthly_revenue
- USAGE_EVENTS: event_id, customer_id, feature_used, event_date, session_duration_minutes, actions_count
- SUPPORT_TICKETS: ticket_id, customer_id, category, priority, status, created_date, resolution_time_hours, satisfaction_score
- CHURN_EVENTS: churn_id, customer_id, churn_reason, churn_date, days_since_signup, final_monthly_revenue

**AGENT SELECTION GUIDE:**
- Need to SEARCH ticket text for specific issues → CONTENT_AGENT (cortex_search)
- Need to ANALYZE specific customers' sentiment → CONTENT_AGENT (UDF)
- Need aggregate BEHAVIOR metrics (usage, sessions, engagement) → DATA_ANALYST_AGENT
- Need STRATEGIC analysis (CLV, market share, industry trends) → RESEARCH_AGENT

**JSON Response Format:**
{{
    "plan_summary": "[AGENT(s)] will use [TOOL(s)] to query [DATA_SOURCE(s)] for [GOAL]",
    "total_steps": <number>,
    "steps": [
        {{
            "step_number": 1,
            "agent": "AGENT_NAME",
            "tool": "TOOL_NAME",
            "data_source": "Semantic view or search index name",
            "purpose": "Specific analytical task",
            "consolidated_query": "SINGLE query/search that gets ALL needed data",
            "expected_output": "Specific columns/fields to return",
            "uses_data_from": [],
            "next_agent": "AGENT_NAME or null if last step"
        }}
    ],
    "combination_strategy": "How results will be joined/synthesized",
    "expected_final_output": "Final deliverable specification"
}}

**Query:** {input}

**RESPOND WITH ONLY THE JSON - Plan will be executed exactly as specified.**
"""

synthesis_prompt = """
You are an Executive AI Assistant synthesizing agent results into a clear answer.

**Original Question**: {question}
**Plan Summary**: {plan_summary}
**Agent Results**:
{agent_outputs}

**Your Task**: Provide a clear, confident answer using the data returned.

**DO NOT:**
- List "missing data" or "incomplete analysis"
- Apologize for limitations
- Add disclaimers about data gaps

**Response Format:**

## Summary
[Direct answer in 2-3 sentences with key metrics]

## Key Findings
[3-5 bullet points of important insights]

## Recommendations
[2-3 actionable next steps based on findings]
"""

planning_prompt_template = ChatPromptTemplate.from_messages([
    ("system", planning_prompt),
    ("human", "{input}")
])

synthesis_prompt_template = ChatPromptTemplate.from_messages([
    ("system", synthesis_prompt),
    ("human", "Synthesize the agent results into a clear answer to the original question.")
])


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def get_latest_human_message(messages: List[BaseMessage]) -> str:
    """Extract the latest human message content from the message list."""
    if not messages:
        return ""
    for msg in reversed(messages):
        if isinstance(msg, HumanMessage):
            content = msg.content
            if isinstance(content, list):
                for item in content:
                    if isinstance(item, dict) and item.get("type") == "text":
                        return item.get("text", "")
                    elif isinstance(item, str):
                        return item
            return str(content)
        if isinstance(msg, dict):
            if msg.get("type") == "human" or msg.get("role") == "user":
                content = msg.get("content", "")
                if isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "text":
                            return item.get("text", "")
                return str(content)
    return ""


def has_plan(state) -> bool:
    """Check if an execution plan has been created."""
    return state.get("plan") is not None and state.get("planning_complete", False)


def get_current_step(state):
    """Get the current step from the execution plan."""
    plan = state.get("plan")
    current_step_idx = state.get("current_step", 0)
    if plan and "steps" in plan:
        steps = plan["steps"]
        if current_step_idx < len(steps):
            return steps[current_step_idx]
    return None


def is_plan_complete(state) -> bool:
    """Check if all steps in the plan have been executed."""
    plan = state.get("plan")
    current_step_idx = state.get("current_step", 0)
    if plan and "steps" in plan:
        return current_step_idx >= len(plan["steps"])
    return True


def get_all_agent_outputs(state) -> Dict[str, str]:
    """Get all agent outputs from state."""
    if state.get("agent_outputs"):
        return state.get("agent_outputs", {})
    
    outputs = {}
    messages = state.get("messages", [])
    for msg in messages:
        if hasattr(msg, 'name') and msg.name in AGENT_NAMES:
            content = msg.content if hasattr(msg, 'content') else str(msg)
            outputs[msg.name] = content
    return outputs


def get_context_for_step(state, step: Dict) -> str:
    """Get context from previous agent output for the current step."""
    uses_data_from = step.get("uses_data_from", [])
    if not uses_data_from:
        return ""
    
    agent_outputs = state.get("agent_outputs", {})
    plan = state.get("plan", {})
    steps = plan.get("steps", [])
    
    context_parts = []
    for step_num in uses_data_from:
        for s in steps:
            if s.get("step_number") == step_num:
                agent_name = s.get("agent")
                if agent_name in agent_outputs:
                    output = agent_outputs[agent_name]
                    if len(output) > 2000:
                        output = output[:2000] + "..."
                    context_parts.append(f"From {agent_name}: {output}")
                break
    
    return "\n".join(context_parts)


def format_agent_outputs_for_synthesis(outputs: Dict[str, str], plan: Dict) -> str:
    """Format agent outputs for synthesis."""
    formatted = []
    for step in plan.get("steps", []):
        agent_name = step.get("agent")
        if agent_name in outputs:
            output = outputs[agent_name]
            if len(output) > 5000:
                output = output[:5000] + "\n... [truncated]"
            
            formatted.append(f"""
**{agent_name}** (Step {step.get('step_number')}/{plan.get('total_steps', len(plan.get('steps', [])))})
Purpose: {step.get('purpose', 'N/A')}

Results:
{output}
""")
    
    return "\n".join(formatted) if formatted else "No agent outputs available."


def build_query_with_context(original_query: str, state: State) -> str:
    """Build query with context from previous agent outputs."""
    current_step = get_current_step(state)
    if not current_step:
        return original_query
    
    context = get_context_for_step(state, current_step)
    if context:
        return f"{original_query}\n\nContext from previous analysis:\n{context}"
    return original_query


def parse_agent_stream_response(chunks: List[str]) -> tuple[str, List[str]]:
    """Parse streaming response from Cortex Agent."""
    response_parts = []
    errors = []
    
    for chunk in chunks:
        try:
            chunk_data = json.loads(chunk)
            if isinstance(chunk_data, dict):
                if chunk_data.get("type") == "text":
                    response_parts.append(chunk_data.get("text", ""))
                elif "content" in chunk_data:
                    response_parts.append(str(chunk_data.get("content", "")))
                elif "message" in chunk_data:
                    errors.append(chunk_data.get("message", "Unknown error"))
            else:
                response_parts.append(str(chunk_data))
        except (json.JSONDecodeError, TypeError):
            if chunk and not chunk.startswith("{"):
                response_parts.append(chunk)
    
    return "".join(response_parts), errors


# =============================================================================
# NODE FUNCTIONS
# =============================================================================

def supervisor_node(state: State) -> Command[Literal["CONTENT_AGENT", "DATA_ANALYST_AGENT", "RESEARCH_AGENT", "__end__"]]:
    """Supervisor node: Planning → Routing → Synthesis"""
    messages = state.get("messages", [])
    plan = state.get("plan")
    
    # MODE 1: PLANNING
    if not has_plan(state):
        latest_message = get_latest_human_message(messages)
        
        if not latest_message:
            return Command(
                update={
                    "plan": {"steps": [], "plan_summary": "No query"},
                    "planning_complete": True
                },
                goto="__end__"
            )
        
        try:
            planning_chain = planning_prompt_template | supervisor_model
            response = planning_chain.invoke({"input": latest_message})
            content = response.content if hasattr(response, 'content') else str(response)
            
            if "{" in content and "}" in content:
                start = content.find("{")
                end = content.rfind("}") + 1
                plan = json.loads(content[start:end])
            else:
                raise ValueError("No valid JSON found")
            
            print(f"\n{'━'*60}")
            print("📋 EXECUTION PLAN")
            print(f"{'━'*60}")
            print(f"\n{plan.get('plan_summary', 'N/A')}")
            print(f"\n📍 Steps ({plan.get('total_steps', len(plan.get('steps', [])))}):")
            for step in plan.get("steps", []):
                print(f"   {step.get('step_number')}. {step.get('agent')}")
            print(f"{'━'*60}\n")
            
            first_step = plan.get("steps", [{}])[0] if plan.get("steps") else {}
            first_agent = first_step.get("agent", "CONTENT_AGENT")
            
            return Command(
                update={
                    "plan": plan,
                    "current_step": 0,
                    "planning_complete": True,
                    "agent_outputs": {},
                    "execution_errors": []
                },
                goto=first_agent
            )
            
        except Exception as e:
            print(f"⚠️ Planning error: {e}")
            fallback_plan = {
                "plan_summary": "Direct query routing",
                "total_steps": 1,
                "steps": [{"step_number": 1, "agent": "CONTENT_AGENT", "purpose": "Handle query", "next_agent": None}],
            }
            return Command(
                update={
                    "plan": fallback_plan,
                    "current_step": 0,
                    "planning_complete": True,
                    "agent_outputs": {},
                    "execution_errors": []
                },
                goto="CONTENT_AGENT"
            )
    
    # MODE 2: ROUTING
    if not is_plan_complete(state):
        current_step = get_current_step(state)
        if current_step:
            next_agent = current_step.get("agent")
            if next_agent and next_agent in AGENT_NAMES:
                print(f"   → Routing to {next_agent}")
                return Command(goto=next_agent)
    
    # MODE 3: SYNTHESIS
    original_question = get_latest_human_message(messages)
    agent_outputs = get_all_agent_outputs(state)
    execution_errors = state.get("execution_errors", [])
    
    print(f"📊 Synthesizing results from {len(agent_outputs)} agent(s)...")
    
    try:
        formatted_outputs = format_agent_outputs_for_synthesis(agent_outputs, plan)
        
        if execution_errors:
            formatted_outputs += f"\n\n**Notes:** {len(execution_errors)} error(s) occurred\n"
        
        synthesis_chain = synthesis_prompt_template | supervisor_model
        response = synthesis_chain.invoke({
            "question": original_question,
            "plan_summary": plan.get("plan_summary", ""),
            "agent_outputs": formatted_outputs
        })
        
        content = response.content if hasattr(response, 'content') else str(response)
        print(f"✅ Analysis complete\n")
        
        return Command(
            update={"messages": [AIMessage(content=content, name="supervisor")]},
            goto="__end__"
        )
        
    except Exception as e:
        print(f"⚠️ Synthesis error: {e}")
        raw_outputs = "\n\n".join([f"**{k}**:\n{v[:2000]}" for k, v in agent_outputs.items()])
        return Command(
            update={"messages": [AIMessage(content=f"Analysis:\n\n{raw_outputs}", name="supervisor")]},
            goto="__end__"
        )


def content_agent_node(state: State) -> Command[Literal["supervisor"]]:
    """Content Agent - customer feedback and sentiment analysis."""
    messages = state["messages"]
    query = get_latest_human_message(messages)
    current_step_idx = state.get("current_step", 0)
    agent_outputs = state.get("agent_outputs", {}).copy()
    execution_errors = state.get("execution_errors", []).copy()
    
    enhanced_query = build_query_with_context(query, state)
    
    print(f"🔍 CONTENT_AGENT analyzing...")
    
    try:
        result = content_agent.invoke(enhanced_query)
        response_content = result.get("output", "")
        print(f"   ✓ Complete ({len(response_content)} chars)")
        
        agent_outputs["CONTENT_AGENT"] = response_content
        
        return Command(
            update={
                "messages": [AIMessage(content=response_content, name="CONTENT_AGENT")],
                "current_step": current_step_idx + 1,
                "agent_outputs": agent_outputs
            },
            goto="supervisor"
        )
        
    except Exception as e:
        error_msg = f"CONTENT_AGENT error: {str(e)}"
        print(f"   ✗ {error_msg}")
        execution_errors.append(error_msg)
        
        return Command(
            update={
                "messages": [AIMessage(content=f"Error: {str(e)}", name="CONTENT_AGENT")],
                "current_step": current_step_idx + 1,
                "agent_outputs": agent_outputs,
                "execution_errors": execution_errors
            },
            goto="supervisor"
        )


def data_analyst_agent_node(state: State) -> Command[Literal["supervisor"]]:
    """Data Analyst Agent - metrics and analytics."""
    messages = state["messages"]
    original_query = get_latest_human_message(messages)
    current_step_idx = state.get("current_step", 0)
    agent_outputs = state.get("agent_outputs", {}).copy()
    execution_errors = state.get("execution_errors", []).copy()
    
    query = build_query_with_context(original_query, state)
    
    print(f"📊 DATA_ANALYST_AGENT analyzing...")
    
    try:
        chunks = []
        for chunk in data_analyst_agent.stream(query):
            chunks.append(str(chunk))
        
        response_content, stream_errors = parse_agent_stream_response(chunks)
        
        if stream_errors:
            unique_errors = list(set(stream_errors))
            if unique_errors:
                print(f"   ⚠️ {len(unique_errors)} error(s) during streaming")
                execution_errors.extend([f"DATA_ANALYST: {e}" for e in unique_errors[:3]])
        
        print(f"   ✓ Complete ({len(response_content)} chars)")
        
        agent_outputs["DATA_ANALYST_AGENT"] = response_content
        
        return Command(
            update={
                "messages": [AIMessage(content=response_content, name="DATA_ANALYST_AGENT")],
                "current_step": current_step_idx + 1,
                "agent_outputs": agent_outputs,
                "execution_errors": execution_errors
            },
            goto="supervisor"
        )
        
    except Exception as e:
        error_msg = f"DATA_ANALYST_AGENT error: {str(e)}"
        print(f"   ✗ {error_msg}")
        execution_errors.append(error_msg)
        
        return Command(
            update={
                "messages": [AIMessage(content=f"Error: {str(e)}", name="DATA_ANALYST_AGENT")],
                "current_step": current_step_idx + 1,
                "agent_outputs": agent_outputs,
                "execution_errors": execution_errors
            },
            goto="supervisor"
        )


def research_agent_node(state: State) -> Command[Literal["supervisor"]]:
    """Research Agent - market and strategic analysis."""
    messages = state["messages"]
    original_query = get_latest_human_message(messages)
    current_step_idx = state.get("current_step", 0)
    agent_outputs = state.get("agent_outputs", {}).copy()
    execution_errors = state.get("execution_errors", []).copy()
    
    query = build_query_with_context(original_query, state)
    
    print(f"🔬 RESEARCH_AGENT analyzing...")
    
    try:
        chunks = []
        for chunk in research_agent.stream(query):
            chunks.append(str(chunk))
        
        response_content, stream_errors = parse_agent_stream_response(chunks)
        
        if stream_errors:
            unique_errors = list(set(stream_errors))
            if unique_errors:
                print(f"   ⚠️ {len(unique_errors)} error(s) during streaming")
                execution_errors.extend([f"RESEARCH: {e}" for e in unique_errors[:3]])
        
        print(f"   ✓ Complete ({len(response_content)} chars)")
        
        agent_outputs["RESEARCH_AGENT"] = response_content
        
        return Command(
            update={
                "messages": [AIMessage(content=response_content, name="RESEARCH_AGENT")],
                "current_step": current_step_idx + 1,
                "agent_outputs": agent_outputs,
                "execution_errors": execution_errors
            },
            goto="supervisor"
        )
        
    except Exception as e:
        error_msg = f"RESEARCH_AGENT error: {str(e)}"
        print(f"   ✗ {error_msg}")
        execution_errors.append(error_msg)
        
        return Command(
            update={
                "messages": [AIMessage(content=f"Error: {str(e)}", name="RESEARCH_AGENT")],
                "current_step": current_step_idx + 1,
                "agent_outputs": agent_outputs,
                "execution_errors": execution_errors
            },
            goto="supervisor"
        )


# =============================================================================
# BUILD AND COMPILE GRAPH
# =============================================================================

# Create the StateGraph
workflow = StateGraph(State)

# Add nodes
workflow.add_node("supervisor", supervisor_node)
workflow.add_node("CONTENT_AGENT", content_agent_node)
workflow.add_node("DATA_ANALYST_AGENT", data_analyst_agent_node)
workflow.add_node("RESEARCH_AGENT", research_agent_node)

# Entry point
workflow.add_edge(START, "supervisor")

# Compile the workflow - this is what LangGraph Studio expects
app = workflow.compile()


# =============================================================================
# ENTRY POINT (for direct execution)
# =============================================================================

if __name__ == "__main__":
    # Test query
    test_query = "What industries have the highest customer lifetime value?"
    
    print(f"\n{'='*60}")
    print(f"Testing: {test_query}")
    print(f"{'='*60}\n")
    
    result = app.invoke({
        "messages": [HumanMessage(content=test_query)]
    })
    
    # Print final response
    final_message = result["messages"][-1]
    print(f"\n{'='*60}")
    print("FINAL RESPONSE:")
    print(f"{'='*60}")
    print(final_message.content)
