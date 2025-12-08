"""
Multi-Agentic Demo - LangGraph Studio Application
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, List, Optional, Literal

# Add the langchain_snowflake package to the path
current_dir = Path(__file__).parent
docs_root = current_dir.parent.parent.parent
package_root = docs_root.parent
sys.path.insert(0, str(package_root))

from langchain_core.messages import HumanMessage, AIMessage, BaseMessage, AnyMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_snowflake import ChatSnowflake, SnowflakeCortexAgent
from langchain_snowflake import create_session_from_env
from langgraph.graph import StateGraph, START, END, MessagesState
from langgraph.graph.message import add_messages
from langgraph.graph.state import CompiledStateGraph
from typing_extensions import TypedDict, Annotated

from dotenv import load_dotenv

load_dotenv()

print("LangGraph Studio Multi-Agent Demo")

# Use MessagesState directly - only messages, no extra fields
State = MessagesState

def create_multi_agent_workflow():
    """Create the complete multi-agent workflow."""
    
    print("Creating multi-agent supervisor workflow...")
    
    # Initialize Snowflake session
    try:
        session = create_session_from_env()
        print("Snowflake session created successfully")
        
        # Get database and schema, stripping any quotes that Snowflake might add
        current_database = session.get_current_database().strip('"')
        current_schema = session.get_current_schema().strip('"')
        print(f"Connected to: {current_database}.{current_schema}")
    except Exception as e:
        print(f"Snowflake connection failed: {e}")
        raise
    
    # Initialize supervisor model
    supervisor_model = ChatSnowflake(
        session=session,
        model="claude-4-sonnet",
        temperature=0.1,
        max_tokens=2000
    )
    print("Supervisor model initialized")
    
    # Initialize agents
    print("\nInitializing agents...")
    
    # Agents are in SNOWFLAKE_INTELLIGENCE.AGENTS schema
    agent_database = "SNOWFLAKE_INTELLIGENCE"
    agent_schema = "AGENTS"
    
    content_agent = SnowflakeCortexAgent(
        session=session,
        name="CONTENT_AGENT",
        database=agent_database,
        schema=agent_schema,
        description="Customer feedback, sentiment analysis, and communication intelligence specialist"
    )
    print("CONTENT_AGENT initialized")
    
    data_analyst_agent = SnowflakeCortexAgent(
        session=session,
        name="DATA_ANALYST_AGENT",
        database=agent_database,
        schema=agent_schema,
        description="Customer behavior, business metrics, and predictive analytics specialist"
    )
    print("DATA_ANALYST_AGENT initialized")
    
    research_agent = SnowflakeCortexAgent(
        session=session,
        name="RESEARCH_AGENT",
        database=agent_database,
        schema=agent_schema,
        description="Market intelligence, strategic analysis, and competitive insights specialist"
    )
    print("RESEARCH_AGENT initialized")
    
    # Supervisor routing prompt
    routing_prompt = """
You are an Executive AI Assistant supervisor managing three specialized business intelligence agents:

**CONTENT_AGENT**: Customer feedback, sentiment analysis, and communication intelligence
**DATA_ANALYST_AGENT**: Customer behavior, business metrics, and predictive analytics  
**RESEARCH_AGENT**: Market intelligence, strategic analysis, and competitive insights

**CRITICAL INSTRUCTION**: You MUST respond with ONLY a JSON object in this exact format:
{{"next_agent": "AGENT_NAME"}}

**Routing Guidelines:**
- Customer feedback, sentiment, satisfaction, support issues, complaints → CONTENT_AGENT
- Data analysis, metrics, behavior patterns, churn, revenue, analytics → DATA_ANALYST_AGENT  
- Market research, competition, strategy, industry trends → RESEARCH_AGENT

**Examples:**
- "Assess churn risk for customers complaining about API issues" → {{"next_agent": "CONTENT_AGENT"}}
- "Analyze customer behavior patterns for Q3" → {{"next_agent": "DATA_ANALYST_AGENT"}}
- "Research market opportunities in fintech" → {{"next_agent": "RESEARCH_AGENT"}}

**RESPOND WITH ONLY THE JSON - NO OTHER TEXT, NO EXPLANATIONS, NO MARKDOWN**
"""
    
    routing_prompt_template = ChatPromptTemplate.from_messages([
        ("system", routing_prompt),
        ("human", "{input}")
    ])
    
    # Supervisor synthesis prompt
    synthesis_prompt = """
You are an Executive AI Assistant synthesizing insights from specialized agents.

**Original Question**: {question}

**Agent Analysis**: {agent_output}

**Instructions**:
1. Extract the key findings and insights from the agent's analysis
2. Present them in a clear, business-friendly format
3. Include specific data points, metrics, and recommendations when available
4. If the agent encountered issues finding data, acknowledge this and suggest alternatives
5. Keep the response concise but comprehensive

**Format your response as**:
- **Summary**: Brief overview of findings
- **Key Insights**: Bullet points of important discoveries  
- **Recommendations**: Actionable next steps
- **Data Gaps** (if any): Note any limitations in the analysis
"""
    
    synthesis_prompt_template = ChatPromptTemplate.from_messages([
        ("system", synthesis_prompt),
        ("human", "Please synthesize the agent's findings into an executive summary.")
    ])
    
    def get_latest_human_message(messages: List[BaseMessage]) -> str:
        """Extract the latest human message content."""
        print(f"DEBUG: messages type = {type(messages)}, length = {len(messages) if messages else 0}")
        
        if not messages:
            return ""
            
        for i, msg in enumerate(reversed(messages)):
            print(f"DEBUG: Message {i}: type={type(msg).__name__}, content_type={type(getattr(msg, 'content', None))}")
            
            # Handle HumanMessage
            if isinstance(msg, HumanMessage):
                content = msg.content
                print(f"DEBUG: HumanMessage content = {content[:100] if isinstance(content, str) else content}")
                
                # Handle LangGraph Studio format (list of content blocks)
                if isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "text":
                            return item.get("text", "")
                        elif isinstance(item, str):
                            return item
                return str(content)
            
            # Handle dict-like messages (from LangGraph Studio)
            if isinstance(msg, dict):
                print(f"DEBUG: dict message keys = {msg.keys()}")
                if msg.get("type") == "human" or msg.get("role") == "user":
                    content = msg.get("content", "")
                    if isinstance(content, list):
                        for item in content:
                            if isinstance(item, dict) and item.get("type") == "text":
                                return item.get("text", "")
                    return str(content)
                    
        return ""
    
    # Helper to check if an agent has responded
    def has_agent_response(messages: List[BaseMessage]) -> bool:
        """Check if any agent has responded in the messages."""
        agent_names = ["CONTENT_AGENT", "DATA_ANALYST_AGENT", "RESEARCH_AGENT"]
        for msg in messages:
            if hasattr(msg, 'name') and msg.name in agent_names:
                return True
        return False
    
    # Helper to get agent output
    def get_agent_output(messages: List[BaseMessage]) -> str:
        """Get the agent's output from messages."""
        agent_names = ["CONTENT_AGENT", "DATA_ANALYST_AGENT", "RESEARCH_AGENT"]
        for msg in reversed(messages):
            if hasattr(msg, 'name') and msg.name in agent_names:
                return msg.content if hasattr(msg, 'content') else str(msg)
        return ""
    
    # SUPERVISOR NODE - handles both routing and synthesis
    def supervisor_node(state: State) -> Dict[str, List[BaseMessage]]:
        """
        Supervisor node that handles routing (first pass) and synthesis (second pass).
        """
        print(f"\nSUPERVISOR NODE EXECUTING")
        
        messages = state.get("messages", [])
        print(f"Processing {len(messages)} messages")
        
        # Check if we're in synthesis mode (agent has responded)
        if has_agent_response(messages):
            print("MODE: Synthesis (agent has responded)")
            
            original_question = get_latest_human_message(messages)
            agent_output = get_agent_output(messages)
            
            try:
                synthesis_chain = synthesis_prompt_template | supervisor_model
                response = synthesis_chain.invoke({
                    "question": original_question,
                    "agent_output": agent_output[:10000]  # Limit to avoid token overflow
                })
                
                content = response.content if hasattr(response, 'content') else str(response)
                print(f"Synthesis completed: {len(content)} characters")
                
                # Mark as synthesis complete so routing knows to end
                return {"messages": [AIMessage(content=content, name="supervisor_synthesis")]}
                
            except Exception as e:
                print(f"Synthesis error: {e}")
                return {"messages": [AIMessage(
                    content=f"Analysis completed. Raw findings:\n\n{agent_output[:2000]}...",
                    name="supervisor_synthesis"
                )]}
        
        # Routing mode - first pass
        print("MODE: Routing (selecting agent)")
        
        latest_message = get_latest_human_message(messages)
        
        if not latest_message:
            print("No human message found")
            return {"messages": [AIMessage(content='{"next_agent": "END"}', name="supervisor_routing")]}
        
        print(f"Supervisor analyzing: {latest_message}")
        
        try:
            routing_chain = routing_prompt_template | supervisor_model
            response = routing_chain.invoke({"input": latest_message})
            
            content = response.content if hasattr(response, 'content') else str(response)
            print(f"Routing decision: {content}")
            
            return {"messages": [AIMessage(content=content, name="supervisor_routing")]}
                
        except Exception as e:
            print(f"Supervisor error: {e}")
            import traceback
            traceback.print_exc()
            return {"messages": [AIMessage(content='{"next_agent": "END"}', name="supervisor_routing")]}
    
    # ROUTING FUNCTION - Parses supervisor's message to get routing decision
    def route_after_supervisor(state: State) -> str:
        """Route based on supervisor's decision parsed from the last message."""
        messages = state.get("messages", [])
        
        # Get the last message (should be from supervisor)
        if not messages:
            print("No messages found")
            return "__end__"
            
        last_message = messages[-1]
        
        # Check if synthesis is complete (supervisor_synthesis message)
        if hasattr(last_message, 'name') and last_message.name == "supervisor_synthesis":
            print("\nROUTING: Synthesis complete, ending workflow")
            return "__end__"
        
        content = last_message.content if hasattr(last_message, 'content') else str(last_message)
        
        # Parse JSON from supervisor's routing response
        next_agent = "END"
        if "{" in content and "}" in content:
            try:
                start = content.find("{")
                end = content.rfind("}") + 1
                json_str = content[start:end]
                decision = json.loads(json_str)
                next_agent = decision.get("next_agent", "END")
            except json.JSONDecodeError:
                pass
        
        print(f"\nROUTING: Supervisor decided '{next_agent}'")
        
        if next_agent == "CONTENT_AGENT":
            print(f"Routing to: CONTENT_AGENT")
            return "CONTENT_AGENT"
        elif next_agent == "DATA_ANALYST_AGENT":
            print(f"Routing to: DATA_ANALYST_AGENT")
            return "DATA_ANALYST_AGENT"
        elif next_agent == "RESEARCH_AGENT":
            print(f"Routing to: RESEARCH_AGENT")
            return "RESEARCH_AGENT"
        else:
            print(f"Ending workflow")
            return "__end__"
    
    # Agent node functions
    def content_agent_node(state: State) -> Dict[str, List[BaseMessage]]:
        """Content agent node."""
        messages = state["messages"]
        query = get_latest_human_message(messages)
        
        print(f"\nCONTENT_AGENT EXECUTING")
        print(f"Processing: {query}")
        
        try:
            result = content_agent.invoke(query)
            response_content = result.get("output", "")
            
            print(f"CONTENT_AGENT completed")
            print(f"Response length: {len(response_content)} characters")
            print(f"Preview: {response_content[:100]}...")
            
            ai_message = AIMessage(
                content=response_content,
                name="CONTENT_AGENT"
            )
            
            return {"messages": [ai_message]}
            
        except Exception as e:
            print(f"CONTENT_AGENT error: {e}")
            error_message = AIMessage(
                content=f"Error executing CONTENT_AGENT: {str(e)}",
                name="CONTENT_AGENT"
            )
            return {"messages": [error_message]}
    
    def data_analyst_agent_node(state: State) -> Dict[str, List[BaseMessage]]:
        """Data analyst agent node."""
        messages = state["messages"]
        query = get_latest_human_message(messages)
        
        print(f"\nDATA_ANALYST_AGENT EXECUTING")
        print(f"Processing: {query}")
        
        try:
            result = data_analyst_agent.invoke(query)
            response_content = result.get("output", "")
            
            print(f"DATA_ANALYST_AGENT completed")
            print(f"Response length: {len(response_content)} characters")
            print(f"Preview: {response_content[:100]}...")
            
            ai_message = AIMessage(
                content=response_content,
                name="DATA_ANALYST_AGENT"
            )
            
            return {"messages": [ai_message]}
            
        except Exception as e:
            print(f"DATA_ANALYST_AGENT error: {e}")
            error_message = AIMessage(
                content=f"Error executing DATA_ANALYST_AGENT: {str(e)}",
                name="DATA_ANALYST_AGENT"
            )
            return {"messages": [error_message]}
    
    def research_agent_node(state: State) -> Dict[str, List[BaseMessage]]:
        """Research agent node."""
        messages = state["messages"]
        query = get_latest_human_message(messages)
        
        print(f"\nRESEARCH_AGENT EXECUTING")
        print(f"Processing: {query}")
        
        try:
            result = research_agent.invoke(query)
            response_content = result.get("output", "")
            
            print(f"RESEARCH_AGENT completed")
            print(f"Response length: {len(response_content)} characters")
            print(f"Preview: {response_content[:100]}...")
            
            ai_message = AIMessage(
                content=response_content,
                name="RESEARCH_AGENT"
            )
            
            return {"messages": [ai_message]}
            
        except Exception as e:
            print(f"RESEARCH_AGENT error: {e}")
            error_message = AIMessage(
                content=f"Error executing RESEARCH_AGENT: {str(e)}",
                name="RESEARCH_AGENT"
            )
            return {"messages": [error_message]}
    
    # Build workflow
    workflow = StateGraph(State)
    
    # Add supervisor node
    workflow.add_node("supervisor", supervisor_node)
    
    # Add agent nodes
    workflow.add_node("CONTENT_AGENT", content_agent_node)
    workflow.add_node("DATA_ANALYST_AGENT", data_analyst_agent_node)
    workflow.add_node("RESEARCH_AGENT", research_agent_node)
    
    # Graph flow: START → supervisor → [agents] → supervisor (synthesis) → END
    workflow.add_edge(START, "supervisor")
    
    # Conditional edges from supervisor to agents (or END after synthesis)
    workflow.add_conditional_edges(
        "supervisor",
        route_after_supervisor,
        {
            "CONTENT_AGENT": "CONTENT_AGENT",
            "DATA_ANALYST_AGENT": "DATA_ANALYST_AGENT", 
            "RESEARCH_AGENT": "RESEARCH_AGENT",
            "__end__": END
        }
    )
    
    # Route agents back to supervisor for synthesis
    workflow.add_edge("CONTENT_AGENT", "supervisor")
    workflow.add_edge("DATA_ANALYST_AGENT", "supervisor")
    workflow.add_edge("RESEARCH_AGENT", "supervisor")
    
    print("Workflow structure complete: supervisor → agent → supervisor (synthesis) → END")
    return workflow.compile()

# Create the app for LangGraph Studio
app = create_multi_agent_workflow()
print("Multi-Agent Supervisor ready for LangGraph Studio!")

if __name__ == "__main__":
    print("\nTesting locally...")
    
    # Test with standard HumanMessage
    test_message = HumanMessage(content="Assess the churn risk for customers complaining about API issues.")
    # test_message = HumanMessage(content="What's the average session duration and engagement score for enterprise customers compared to professional customers?")
    # test_message = HumanMessage(content="What industries have the highest customer lifetime value and represent our best strategic expansion opportunities?")
    
    try:
        result = app.invoke({
            "messages": [test_message]
        })
        
        print(f"\nResult: {len(result.get('messages', []))} messages")
        
        for i, msg in enumerate(result.get("messages", []), 1):
            msg_type = type(msg).__name__
            msg_name = getattr(msg, 'name', 'Unknown')
            content = msg.content
            if isinstance(content, list):
                content = str(content)
            print(f"\n{i}. {msg_type} ({msg_name}):")
            print(f"   {content[:200]}{'...' if len(str(content)) > 200 else ''}")
        
        print("\nTest successful!")
        
    except Exception as e:
        print(f"Test failed: {e}")
        import traceback
        traceback.print_exc()