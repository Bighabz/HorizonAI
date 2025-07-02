# AI Horizon n8n Workflow Fix - Complete Technical Prompt

## URGENT: Fix Disconnected Nodes in n8n AI Horizon RAG Workflow

### PROBLEM STATEMENT
The n8n workflow `ai_horizon_complete_workflow.json` has disconnected nodes that are costing money. The workflow needs ALL nodes properly connected with working data flow for:
- Vector search with pgvector/Supabase
- OpenAI embeddings and chat
- Document processing with Dumpling AI
- Telegram bot integration
- DCWF task mapping

### REQUIRED FUNCTIONALITY

**Core AI Horizon Forecasting Pipeline:**
1. **Document Processing Route:**
   - Telegram file upload → Download → Dumpling AI OCR → AI Classification + Embedding Generation → Store in Supabase → Confirmation
   
2. **YouTube Processing Route:**
   - YouTube URL → Dumpling AI transcript → AI Classification + Embedding Generation → Store in Supabase → Confirmation
   
3. **Chat/RAG Route:**
   - User message → Generate query embedding → Vector search Supabase + Get chat history → Build context → OpenAI response → Save to chat memory + Send reply

**AI Classification Requirements:**
- Classify as: Replace, Augment, Remain Human, New Task
- Score: credibility, impact, specificity (0-1 scale)
- Map to DCWF task IDs (T0001-T0999+)
- Return structured JSON

### API CREDENTIALS (HARDCODED)
```
TELEGRAM_BOT_TOKEN: 7799820694:AAHiGF8k3SiVfcy8_o2xqac7JkwqOmj3y2s
OPENAI_API_KEY: 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
DUMPLING_API_KEY: sk_wHUE8kEVOvO8InedX5K9MjHxlB6Ws02mPSBBQvPnaH5Nss8q
SUPABASE_URL: https://hdevbjifbhxcacpjxstr.supabase.co
SUPABASE_SERVICE_KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkZXZiamlmYmh4Y2FjcGp4c3RyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNDU5OTM5NywiZXhwIjoyMDUwMTc1Mzk3fQ.Hl8Rj6QJZ7zKtEOdZTGWsR8E8Qg7-ZgGQNYL-Jy4E4M
```

### SUPABASE SCHEMA
```sql
-- Main documents table with vector embeddings
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    artifact_id VARCHAR(255) UNIQUE NOT NULL,
    title VARCHAR(500),
    summary TEXT,
    content TEXT NOT NULL,
    source_url TEXT,
    source_type VARCHAR(50),
    filename VARCHAR(255),
    classification VARCHAR(50) CHECK (classification IN ('Replace', 'Augment', 'Remain Human', 'New Task')),
    confidence DECIMAL(3,2),
    rationale TEXT,
    dcwf_task_ids TEXT[],
    credibility_score DECIMAL(3,2),
    impact_score DECIMAL(3,2),
    specificity_score DECIMAL(3,2),
    embedding vector(1536), -- OpenAI ada-002 dimension
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255),
    username VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat memory for RAG
CREATE TABLE chat_memory (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    role VARCHAR(20) CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    message_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Vector search function
CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 5,
    user_id text DEFAULT NULL
)
RETURNS TABLE (
    id int,
    title text,
    content text,
    classification text,
    dcwf_task_ids text[],
    filename text,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id, d.title, d.content, d.classification, d.dcwf_task_ids, d.filename,
        (1 - (d.embedding <=> query_embedding)) as similarity
    FROM documents d
    WHERE (user_id IS NULL OR d.user_id = user_id)
        AND (1 - (d.embedding <=> query_embedding)) > match_threshold
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
```

### DCWF TASK CONTEXT
The Department of Homeland Security Cybersecurity Workforce Framework (DCWF) contains 1,350+ tasks and 1,772+ KSAs. Key task examples:
- T0001: Acquire and manage resources for IT security
- T0419: Maintain knowledge of laws and regulations  
- T0420: Administer test beds and evaluate applications
- T0421: Manage organizational knowledge indexing

### API ENDPOINTS

**Dumpling AI:**
- Document OCR: `POST https://app.dumplingai.com/api/v1/doc-to-text`
  - Headers: `Authorization: Bearer API_KEY`, `Content-Type: application/json`
  - Body: `{"inputMethod": "base64", "file": "base64_data"}`
- YouTube: `POST https://app.dumplingai.com/api/v1/get-youtube-transcript`
  - Body: `{"videoUrl": "url", "includeTimestamps": true}`

**OpenAI:**
- Embeddings: `POST https://api.openai.com/v1/embeddings`
  - Body: `{"model": "text-embedding-ada-002", "input": "text"}`
- Chat: Use n8n OpenAI node with `gpt-4o-mini`

**Supabase:**
- Use n8n Supabase node with operation "create" (NOT "insert")
- Vector search: Use "runSql" operation with custom SQL

### CRITICAL FIXES NEEDED

1. **Connection Issues:**
   - All nodes must be connected with proper data flow
   - No orphaned or disconnected nodes
   - Proper merge nodes where parallel processing occurs

2. **Data Flow Problems:**
   - Fix OpenAI response parsing: `$json.message.content` vs `$json.choices[0].message.content`
   - Fix Supabase field mappings with proper column names
   - Fix embedding array formatting: `'[' + embedding.join(',') + ']'`

3. **Node Configuration:**
   - Supabase operations: Use "create" not "insert"
   - OpenAI nodes: Ensure proper credential types
   - Switch node: Proper case-sensitive routing

4. **Required Node Structure:**
   ```
   Telegram Trigger → Route Detection → Switch
   ├─ Document: Download → Process → [AI Classify + Embedding] → Merge → Store → Confirm
   ├─ YouTube: Process → [AI Classify + Embedding] → Merge → Store → Confirm  
   └─ Chat: Prepare → [Query Embedding + History] → Merge → Context → AI Response → [Save + Reply]
   ```

### SUCCESS CRITERIA
- All nodes connected (no question marks in n8n)
- Chat messages get AI responses with RAG context
- Documents upload, process, classify, and store with embeddings
- YouTube URLs extract transcripts and process
- Vector search returns relevant documents
- Chat history saves properly
- No execution errors

### DELIVERABLE
Provide a complete, working n8n workflow JSON file with:
- All nodes properly connected
- Hardcoded API credentials
- Proper data flow and field mappings
- Error handling
- Tested routing logic

**IMPORTANT: This is costing real money. The workflow must work immediately upon import with no additional configuration needed.**