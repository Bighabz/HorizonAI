# AI Horizon RAG Functionality - Critical Fixes Needed

## 🎯 Current Status
- ✅ Database tables exist and are accessible
- ✅ Supabase connection works with service key
- ✅ n8n workflow structure is complete (44 nodes)
- ✅ Dumpling AI integration is working
- ❌ Vector search implementation needs fixes
- ❌ Data mapping between nodes needs correction

## 🔧 Critical Issues & Fixes

### 1. Vector Search Implementation (PRIORITY 1)

**Current Issue:** The workflow uses basic Supabase node filtering instead of proper vector similarity search.

**Current Code in "Vector Search Documents":**
```javascript
// Current - Basic filter, no vector search
operation: "getAll",
filterString: "=user_id.eq.{{ $('Prepare Chat Input').item.json.userId }}"
```

**Fix Needed:**
```javascript
// Use HTTP Request node for proper vector search
POST {SUPABASE_URL}/rest/v1/rpc/similarity_search
{
  "query_embedding": [embedding_vector],
  "match_threshold": 0.7,
  "match_count": 10,
  "user_id": "user_123"
}
```

**Action Required:**
1. Replace "Vector Search Documents" Supabase node with HTTP Request node
2. Add embedding generation for user query
3. Create PostgreSQL function for vector similarity search

### 2. Embedding Generation for Chat Queries (PRIORITY 1)

**Current Issue:** User messages aren't converted to embeddings for vector search.

**Missing Node:** Between "Prepare Vector Search" and "Vector Search Documents"
```javascript
// Add this HTTP Request node
{
  "method": "POST",
  "url": "https://api.openai.com/v1/embeddings",
  "headers": {
    "Authorization": "Bearer {{$json.openai_key}}",
    "Content-Type": "application/json"
  },
  "body": {
    "model": "text-embedding-ada-002",
    "input": "{{$('Prepare Chat Input').item.json.userMessage}}"
  }
}
```

### 3. Context Building Issues (PRIORITY 2)

**Current Issue in "Build AI Context":**
```javascript
// Current - assumes searchResults from wrong node
const searchNode = $('Vector Search Documents');
searchResults = searchNode.all().map(item => item.json) || [];
```

**Fix:**
```javascript
// Correct - handle proper vector search results
let searchResults = [];
try {
  const vectorSearchNode = $('Vector Similarity Search');
  if (vectorSearchNode && vectorSearchNode.item && vectorSearchNode.item.json) {
    searchResults = vectorSearchNode.item.json.data || [];
  }
} catch (e) {
  console.log('No vector search results available');
}
```

### 4. Document Storage Issues (PRIORITY 2)

**Current Issue in "Store in Supabase":**
```javascript
// Embedding field mapping issue
"embedding": "={{ $json.data[0].embedding }}"
```

**Fix:**
```javascript
// Correct embedding storage
"embedding": "={{ JSON.stringify($('Generate Embedding').item.json.data[0].embedding) }}"
```

### 5. Missing PostgreSQL Functions (PRIORITY 1)

**Required SQL Functions:**
```sql
-- Vector similarity search function
CREATE OR REPLACE FUNCTION similarity_search(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10,
  user_id text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  content text,
  classification text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.title,
    d.content,
    d.classification,
    1 - (d.embedding <=> query_embedding) as similarity
  FROM documents d
  WHERE 
    (user_id IS NULL OR d.user_id = user_id)
    AND 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

## 🔄 Updated Workflow Structure

### Phase 1: Chat Processing Flow
```
1. Telegram Trigger
2. Detect Route Type
3. Route by Type → chat
4. Prepare Chat Input
5. Get Chat History (parallel)
6. Generate Query Embedding (NEW)
7. Vector Similarity Search (FIXED)
8. Merge Chat Data
9. Build AI Context (FIXED)
10. Call OpenAI Chat
11. Process AI Response
12. Send Telegram Response
13. Store User Message & AI Response
```

### Phase 2: Document Processing Flow  
```
1. Route by Type → document
2. Document Source Handler
3. Download Telegram File (if needed)
4. Route Document Type
5. Extract Content (Dumpling)
6. Normalize Content
7. Chunk Text
8. AI Classification (parallel)
9. Enrich Metadata
10. Generate Embedding
11. Store in Supabase (FIXED)
12. Aggregate Success Message
13. Send Success Message
```

## 🛠️ Specific Node Fixes Required

### 1. Replace "Vector Search Documents" node:
- **Current:** Supabase node with basic filter
- **New:** HTTP Request node calling similarity_search RPC
- **URL:** `{SUPABASE_URL}/rest/v1/rpc/similarity_search`
- **Method:** POST
- **Body:** Include query embedding and filters

### 2. Add "Generate Query Embedding" node:
- **Type:** HTTP Request 
- **Position:** Between "Prepare Vector Search" and "Vector Search Documents"
- **Purpose:** Convert user message to embedding vector

### 3. Fix "Build AI Context" node:
- **Issue:** Incorrect data source reference
- **Fix:** Update to handle vector search results properly
- **Add:** Better error handling for missing data

### 4. Fix "Store in Supabase" node:
- **Issue:** Embedding field mapping
- **Fix:** Proper JSON serialization of embedding vector
- **Add:** Error handling for missing embeddings

## 🧪 Testing Strategy

### 1. Test Vector Search:
```bash
# Test similarity search function
curl -X POST '{SUPABASE_URL}/rest/v1/rpc/similarity_search' \
  -H "Authorization: Bearer {SERVICE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "query_embedding": [0.1, 0.2, ...], 
    "match_threshold": 0.7,
    "match_count": 5,
    "user_id": "test_user"
  }'
```

### 2. Test Document Storage:
```bash
# Verify embeddings are stored correctly
curl '{SUPABASE_URL}/rest/v1/documents?select=id,title,embedding&limit=1' \
  -H "Authorization: Bearer {SERVICE_KEY}"
```

### 3. Test Chat Flow:
1. Send "Hello" to bot → Should get welcome message
2. Upload test document → Should process and store
3. Ask "What was that document about?" → Should retrieve and respond

## 📋 Implementation Priority

1. **IMMEDIATE (1 hour):**
   - Create similarity_search SQL function
   - Fix "Vector Search Documents" node
   - Add "Generate Query Embedding" node

2. **HIGH (2 hours):**
   - Fix "Build AI Context" data mapping
   - Fix "Store in Supabase" embedding storage
   - Test basic RAG flow

3. **MEDIUM (1 hour):**
   - Improve error handling
   - Add logging for debugging
   - Test with real documents

## 🎯 Success Criteria

✅ User can upload a document and it gets processed
✅ User can ask questions about uploaded documents  
✅ Bot retrieves relevant document chunks via vector search
✅ Bot provides contextual answers based on document content
✅ Chat history is maintained across conversations