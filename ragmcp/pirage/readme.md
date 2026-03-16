## **PIRAGE & PIRAGE-A — From Linear RAG to Agentic, AI-Assisted Systems**



## **1. Introduction**



Retrieval-Augmented Generation (RAG) enhances Large Language Models (LLMs) with external knowledge, enabling answers grounded in real data.  

**PIRAGE** is a structured refinement of RAG, split into five clear pillars:



1\.  \*\*P\*\* — Parse

   

2\.  \*\*I\*\* — Index

   

3\.  \*\*R\*\* — Retrieve

   

4\.  \*\*AG\*\* — Augmented Generation

   

5\.  \*\*E\*\* — Evaluation (continuous across all pillars)

   



The model is presented in two stages:



-   **Basic PIRAGE** — A simple, linear pipeline, perfect for newcomers and initial implementations.

-   **PIRAGE-A** — An advanced, agentic evolution with AI-assisted P–I services and dynamic pillar orchestration.




----------



## **2. Basic PIRAGE — The Linear Model**



The basic model runs as a straight, predictable flow. It’s designed to be easy to understand before exploring advanced techniques.



\*\*Two phases\*\*:



\-   \*\*Upstream Preprocessing\*\* — Preparing knowledge before any query.

   

\-   \*\*Query Flow\*\* — Using that prepared knowledge to answer user questions.  

   \*\*Evaluation\*\* runs throughout, monitoring quality at every step.

   



----------



### **2.1 Upstream Preprocessing**



#### **P — Parse**



Turns raw, unstructured documents into clean, structured segments.



\-   \*\*Input:\*\* PDFs, web pages, Word docs, etc.

   

\-   \*\*Process:\*\* Extract text, remove noise, normalize formatting, keep logical sections (paragraphs, headings, tables).

   

\-   \*\*Output:\*\* Parsed chunks + metadata.

   

\-   \*\*Example:\*\* Taking a PDF report and producing clean text blocks with table data preserved.

   



----------



#### **I — Index**



Organizes parsed chunks for efficient searching.



\-   \*\*Input:\*\* Parsed chunks from P.

   

\-   \*\*Process:\*\* Split into retrieval units (chunks), embed for semantic search, build keyword or graph indexes, store metadata.

   

\-   \*\*Output:\*\* Searchable indices linked to chunks.

   

\-   \*\*Example:\*\* Creating a vector index for semantic similarity search.

   



----------



### **2.2 Query Flow**



#### **R — Retrieve**



Finds the most relevant chunks for a query.



\-   \*\*Input:\*\* User query, indices, parsed chunks.

   

\-   \*\*Process:\*\* Search (semantic, keyword, graph, hybrid), rank results.

   

\-   \*\*Output:\*\* Ranked chunk list.

   

\-   \*\*Example:\*\* Searching for “symptoms of malaria” returns relevant document snippets.

   



----------



#### **AG — Augmented Generation**



Generates the answer using retrieved evidence.



\-   \*\*Input:\*\* User query, ranked chunks.

   

\-   \*\*Process:\*\* Select top chunks, combine with query, generate answer with LLM.

   

\-   \*\*Output:\*\* Final answer.

   

\-   \*\*Example:\*\* Producing a short, accurate summary with references.

   



----------



### **2.3 E — Evaluation**



Monitors all pillars for quality, accuracy, and performance.



\-   \*\*Methods:\*\* Automated metrics, human feedback, test queries.

   

\-   \*\*Scope:\*\* From checking parsing accuracy to ensuring generated answers are factually correct.

   



----------



\*\*Basic PIRAGE takeaway:\*\*  

A clear, step-by-step process that’s easy to explain, easy to debug, and a solid foundation before moving to advanced capabilities.



----------



## **3. PIRAGE-A — The Advanced / Agentic Model**



Once the basics are mastered, PIRAGE-A turns the pipeline into a \*\*dynamic, learning system\*\*.



----------



### **3.1 AI-Assisted P–I Service**



In PIRAGE-A, \*\*Parse–Index\*\* is no longer a one-time step — it becomes an \*\*ongoing, iterative, learning service\*\* where we will increasingly see \*\*AI-assisted solutions\*\* emerging.



These systems:



\-   Continuously re-parse and re-index as new documents arrive or content changes.

   

\-   Adapt indexing strategies to different query types over time.

   

\-   Use AI to help design and optimize the indexing process:

   

   -   Analyzing sample documents.

       

   -   Suggesting chunking and parsing methods.

       

   -   Testing alternative indexing approaches.

       

   -   Learning from retrieval outcomes and evaluation feedback.

       



While in this training we \*\*will not build a full AI-assisted P–I service\*\*, understanding this direction is important.  

Modern platforms are already moving toward it:



\-   \*\*Azure AI Search\*\*: AI-powered parsing and enrichment skills with automated indexers.

   

\-   \*\*Enterprise ingestion pipelines\*\*: Dynamic parsing, enrichment, and re-indexing strategies.

   

\-   \*\*Research prototypes\*\*: LLMs refining parsing/indexing strategies in real time.

   



\*\*Key point for learners:\*\*  

Think of P–I not as a static setup, but as a service that will evolve — and be increasingly augmented by AI — in production environments.



----------



### **3.2 Dynamic R ↔ AG Interaction**



Retrieval and Augmented Generation can interact:



\-   \*\*Re-querying:\*\* AG detects missing info and asks R to search again with refined terms.

   

\-   \*\*Multi-step queries:\*\* Break one user question into smaller sub-queries.

   

\-   \*\*Hybrid retrieval:\*\* R runs multiple methods (semantic, keyword, graph) and fuses results.

   



----------



### **3.3 Orchestrated Pillars**



An \*\*agent orchestrator\*\* can:



\-   Decide which retrieval methods to use for each query.

   

\-   Trigger re-indexing when needed.

   

\-   Choose different AG models or prompts based on the question type.

   

\-   Loop between pillars until confidence is high enough.

   



----------



\*\*PIRAGE-A takeaway:\*\*  

The same five pillars, but used flexibly, with AI helping to adapt, optimize, and evolve the system continuously.



----------



## **4. Learning Path**



1\.  \*\*Start simple:\*\* Implement Basic PIRAGE as a fixed pipeline.

   

2\.  \*\*Introduce feedback:\*\* Use E to monitor and improve performance.

   

3\.  \*\*Enhance P–I:\*\* Move to AI-assisted, continuously evolving indexing.

   

4\.  \*\*Add orchestration:\*\* Let R and AG loop, branch, and merge results dynamically.

   



----------



## **5. Summary**



\-   \*\*Basic PIRAGE\*\* = easy to understand, linear, transparent.

   

\-   \*\*PIRAGE-A\*\* = adaptive, agentic, AI-assisted, orchestrated.

   

\-   \*\*E\*\* ties them together — monitoring, learning, and driving improvement at every stage.

