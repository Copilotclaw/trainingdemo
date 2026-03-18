Agent RAG Demo

build me the notebook based on this - link it into the readme:

***

### 📓 Google Colab Notebook: Agentic RAG with Grok

#### Cell 1: Install Dependencies
We swap the OpenAI integration for the official `langchain-xai` package.
```python
# CELL 1: Setup & Installations
!pip install -qU langgraph langchain langchain-xai langchain-huggingface chromadb sentence-transformers pydantic
```

#### Cell 2: API Keys & Grok Setup
Head over to the [[xAI Developer Console](https://console.x.ai/)](https://console.x.ai/) to generate your API key. We will use `grok-2-latest` as the model, which is highly capable of handling the structured JSON output required by our Evaluator agent.
```python
# CELL 2: Environment Setup
import os
from getpass import getpass
from langchain_xai import ChatXAI

# BYOK: Enter your xAI API Key 
os.environ["XAI_API_KEY"] = getpass("Enter your xAI API Key: ")

# The "Brain" of our agent is now Grok!
llm = ChatXAI(
    model="grok-2-latest", 
    temperature=0
)
```

#### Cell 3: The Vector Database (Unchanged)
We still use HuggingFace locally for the embeddings to keep things fast and free.
```python
# CELL 3: Initialize the Vector DB
from langchain_community.vectorstores import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.documents import Document

embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

docs = [
    Document(page_content="On March 12th, the server outage was caused by a DDoS attack on the EU-East region."),
    Document(page_content="Tuesday's 504 Gateway Timeout was traced back to a misconfigured API limit in the EU-West load balancer."),
    Document(page_content="To fix an API limit timeout, engineers must increase the concurrent connection threshold in the AWS console."),
]

vectorstore = Chroma.from_documents(documents=docs, embedding=embeddings)
retriever = vectorstore.as_retriever(search_kwargs={"k": 2})
```

#### Cell 4: Define the Agent State (Unchanged)
```python
# CELL 4: Define the Agent State
from typing import TypedDict, List

class AgentState(TypedDict):
    question: str
    context: List[str]
    draft_answer: str
    feedback: str
    loop_count: int
```

#### Cell 5: Define the Agent Nodes (Using Grok)
The nodes remain exactly the same. LangChain handles the translation of the `with_structured_output(GraderOutput)` method under the hood so that Grok knows it must return strict JSON for the gating logic.
```python
# CELL 5: The Agentic Nodes
from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate

def retrieve_data(state: AgentState):
    print("-> AGENT: Retrieving Data...")
    search_query = state["question"] + " " + state.get("feedback", "")
    docs = retriever.invoke(search_query)
    context = [doc.page_content for doc in docs]
    return {"context": context, "loop_count": state.get("loop_count", 0) + 1}

def generate_draft(state: AgentState):
    print("-> AGENT: Generating Draft with Grok...")
    prompt = ChatPromptTemplate.from_messages([
        ("system", "You are a tech assistant. Answer the question using ONLY the context below.\n\nContext: {context}\n\nFeedback from Reviewer: {feedback}"),
        ("user", "{question}")
    ])
    chain = prompt | llm
    response = chain.invoke({"context": "\n".join(state["context"]), "question": state["question"], "feedback": state.get("feedback", "")})
    return {"draft_answer": response.content}

class GraderOutput(BaseModel):
    is_accurate: bool = Field(description="True if the draft perfectly answers the question using only context.")
    feedback: str = Field(description="If False, explain exactly what is missing or hallucinated.")

def evaluate_draft(state: AgentState):
    print("-> AGENT: Grok is Evaluating the Draft for Hallucinations...")
    prompt = ChatPromptTemplate.from_messages([
        ("system", "You are a strict QA reviewer. Does the Draft perfectly answer the Question based on the Context? If it hallucinates or misses key info, fail it and provide feedback."),
        ("user", "Question: {question}\nContext: {context}\nDraft: {draft_answer}")
    ])
    
    evaluator_llm = llm.with_structured_output(GraderOutput)
    chain = prompt | evaluator_llm
    
    result = chain.invoke({"question": state["question"], "context": "\n".join(state["context"]), "draft_answer": state["draft_answer"]})
    
    print(f"   [Evaluation Result: {'PASS' if result.is_accurate else 'FAIL'}]")
    if not result.is_accurate:
        print(f"   [Feedback: {result.feedback}]")
        
    return {"feedback": result.feedback if not result.is_accurate else "PASS"}
```

#### Cell 6: Wire the Graph (Unchanged)
```python
# CELL 6: Build the State Machine Graph
from langgraph.graph import StateGraph, END

workflow = StateGraph(AgentState)

workflow.add_node("Retrieve", retrieve_data)
workflow.add_node("Generate", generate_draft)
workflow.add_node("Evaluate", evaluate_draft)

workflow.add_edge("Retrieve", "Generate")
workflow.add_edge("Generate", "Evaluate")

def routing_logic(state: AgentState):
    if state["feedback"] == "PASS":
        return "End"
    elif state["loop_count"] >= 3:
        print("-> SYSTEM: Max loops reached. Exiting safely.")
        return "End"
    else:
        print("-> SYSTEM: Routing back to Retriever to try again.")
        return "Retrieve"

workflow.add_conditional_edges("Evaluate", routing_logic, {"Retrieve": "Retrieve", "End": END})
app = workflow.compile()
```

#### Cell 7: Execute!
```python
# CELL 7: Run the Scenario
inputs = {"question": "What caused Tuesday's 504 timeout and in which region did it happen?"}

print("=== STARTING AGENTIC RAG WITH GROK ===\n")
for output in app.stream(inputs):
    for key, value in output.items():
        pass 

print("\n=== FINAL VERIFIED OUTPUT ===")
final_state = app.get_state(inputs).values
print(final_state["draft_answer"])
```

### The Architectural Takeaway
Notice how the orchestration logic (the state machine, the loops, the retrieval mechanism) didn't care at all that we swapped the underlying model. This is why investing in an orchestration framework like LangGraph is so critical. If a new, incredibly cheap, or vastly superior model drops next week, your enterprise pipeline doesn't break—you just update Cell 2.