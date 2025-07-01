# 🚀 AI Horizon RAG Implementation Guide

## 📋 Step-by-Step Implementation

### STEP 1: Create SQL Function in Supabase (5 minutes)

1. **Go to Supabase Dashboard** → Your Project → SQL Editor
2. **Execute this SQL:**

```sql
CREATE OR REPLACE FUNCTION match_documents(
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
  filename text,
  category text,
  tags text[],
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
    d.filename,
    d.category,
    d.tags,
    1 - (d.embedding <=> query_embedding) as similarity
  FROM documents d
  WHERE 
    d.embedding IS NOT NULL
    AND (user_id IS NULL OR d.user_id = user_id)
    AND 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

3. **Click "Run"** to create the function

### STEP 2: Update OpenAI Credentials in n8n (2 minutes)

1. **Go to n8n** → Settings → Credentials
2. **Find "OpenAI" credential** or create new one
3. **Update API Key** with your new key
4. **Test connection** to ensure it works

### STEP 3: Add "Generate Query Embedding" Node (10 minutes)

1. **In n8n workflow editor:**
   - Find the connection between "Prepare Vector Search" and "Vector Search Documents"
   - **Add new HTTP Request node** between them
   - **Name it:** "Generate Query Embedding"

2. **Configure the node:**
   - **Method:** POST
   - **URL:** `https://api.openai.com/v1/embeddings`
   - **Headers:**
     - `Authorization`: `Bearer {{ $credentials.openAi.apiKey }}`
     - `Content-Type`: `application/json`
   - **Body (JSON):**
   ```json
   {
     "model": "text-embedding-ada-002",
     "input": "{{ $('Prepare Chat Input').item.json.userMessage }}"
   }
   ```

3. **Connect the nodes:**
   - "Prepare Vector Search" → "Generate Query Embedding"
   - "Generate Query Embedding" → "Vector Search Documents"

### STEP 4: Replace "Vector Search Documents" Node (15 minutes)

1. **Delete the current "Vector Search Documents" Supabase node**

2. **Add new HTTP Request node:**
   - **Name:** "Vector Similarity Search"
   - **Method:** POST
   - **URL:** `{{ $env.SUPABASE_URL }}/rest/v1/rpc/match_documents`
   - **Headers:**
     - `apikey`: `{{ $env.SUPABASE_SERVICE_KEY }}`
     - `Authorization`: `Bearer {{ $env.SUPABASE_SERVICE_KEY }}`
     - `Content-Type`: `application/json`
   - **Body (JSON):**
   ```json
   {
     "query_embedding": "{{ $('Generate Query Embedding').item.json.data[0].embedding }}",
     "match_threshold": 0.7,
     "match_count": 10,
     "user_id": "{{ $('Prepare Chat Input').item.json.userId }}"
   }
   ```

3. **Update connections:**
   - "Generate Query Embedding" → "Vector Similarity Search"
   - "Vector Similarity Search" → "Merge Chat Data"

### STEP 5: Fix "Build AI Context" Node (10 minutes)

1. **Find the "Build AI Context" Code node**
2. **Replace the JavaScript code** with this enhanced version:

```javascript
// Enhanced context building with proper vector search results
let chatData, history = [], searchResults = [];

// Safely get chat data
try {
  chatData = $('Prepare Chat Input').item.json;
} catch (e) {
  throw new Error('Chat input data not available');
}

// Safely get chat history
try {
  history = $('Get Chat History').all() || [];
} catch (e) {
  console.log('No chat history available');
}

// Safely get vector search results
try {
  const vectorSearchNode = $('Vector Similarity Search');
  if (vectorSearchNode && vectorSearchNode.item && vectorSearchNode.item.json) {
    // Handle both direct results and nested data structure
    const results = vectorSearchNode.item.json;
    if (Array.isArray(results)) {
      searchResults = results;
    } else if (results.data && Array.isArray(results.data)) {
      searchResults = results.data;
    } else if (results.results && Array.isArray(results.results)) {
      searchResults = results.results;
    }
  }
} catch (e) {
  console.log('No vector search results available:', e.message);
}

// Format chat history
const formattedHistory = history
  .reverse()
  .slice(0, 10) // Limit to last 10 messages
  .map(msg => `${msg.json.role === 'user' ? 'User' : 'Assistant'}: ${msg.json.content}`)
  .join('\n\n');

// Format search results with similarity scores
let relevantDocs = 'No relevant documents found.';
if (searchResults.length > 0) {
  relevantDocs = searchResults.slice(0, 5)
    .map((doc, index) => {
      const title = doc.title || 'Untitled';
      const category = doc.category || 'General';
      const content = (doc.content || '').substring(0, 800);
      const filename = doc.filename || 'Unknown file';
      const classification = doc.classification || 'Unknown';
      const similarity = doc.similarity ? `${(doc.similarity * 100).toFixed(1)}%` : 'N/A';
      
      return `**Document ${index + 1}** (Similarity: ${similarity})\n**Title:** ${title}\n**File:** ${filename}\n**Category:** ${category}\n**Classification:** ${classification}\n**Content:** ${content}...\n`;
    })
    .join('\n---\n');
}

// Build enhanced system message
const systemMessage = `You are an AI assistant for Project Horizon, specialized in analyzing how AI impacts cybersecurity tasks and roles.

**Your Knowledge Base:**
${relevantDocs}

**Recent Conversation:**
${formattedHistory || 'No previous messages.'}

**Instructions:**
- Use the knowledge base documents to answer questions
- When referencing documents, mention their titles and similarity scores
- Focus on AI's impact on cybersecurity work (Replace/Augment/Remain Human/New Task)
- If asked about recent uploads, refer to the most relevant documents above
- Be specific and cite evidence from the documents
- If no relevant documents exist, acknowledge this and provide general guidance`;

return {
  json: {
    systemMessage: systemMessage,
    userMessage: chatData.userMessage,
    chatId: chatData.chatId,
    userId: chatData.userId,
    username: chatData.username,
    messageId: chatData.messageId,
    documentsFound: searchResults.length,
    historyCount: history.length,
    searchResults: searchResults.slice(0, 3) // Include top results for debugging
  }
};
```

### STEP 6: Fix "Store in Supabase" Embedding Field (5 minutes)

1. **Find the "Store in Supabase" node in the document processing flow**
2. **Update the embedding field value:**
   - **Current:** `={{ $json.data[0].embedding }}`
   - **New:** `={{ JSON.stringify($('Generate Embedding').item.json.data[0].embedding) }}`

### STEP 7: Test the System (15 minutes)

1. **Activate the workflow** in n8n

2. **Test basic chat:**
   - Send "Hello" to your Telegram bot
   - Should get welcome message

3. **Test document upload:**
   - Upload a PDF or DOCX file
   - Should get processing confirmation

4. **Test RAG functionality:**
   - Ask "What was that document about?"
   - Should get response with document content and similarity scores

5. **Check logs:**
   - Monitor n8n execution logs for any errors
   - Verify embeddings are being generated and stored

## 🔧 Troubleshooting

### If Vector Search Fails:
1. **Check Supabase SQL function** exists: `SELECT * FROM pg_proc WHERE proname = 'match_documents';`
2. **Verify embeddings exist:** `SELECT COUNT(*) FROM documents WHERE embedding IS NOT NULL;`
3. **Test function manually:** Execute the match_documents function in SQL editor

### If Embeddings Fail:
1. **Check OpenAI API key** in n8n credentials
2. **Verify API quota** isn't exceeded
3. **Test embedding generation** with a simple text

### If Context Building Fails:
1. **Check node names** match exactly ("Vector Similarity Search")
2. **Verify data structure** in execution logs
3. **Add console.log** statements for debugging

## 🎯 Expected Results

After implementation:

1. **User uploads document** → Gets processed and stored with embeddings
2. **User asks question** → System finds relevant documents via vector search
3. **Bot responds** with contextual answer citing specific documents and similarity scores
4. **Chat history** is maintained across conversations

## 📊 Performance Metrics

- **Document processing:** ~30-60 seconds per document
- **Vector search:** <2 seconds response time  
- **Embedding generation:** ~5-10 seconds per query
- **Overall chat response:** <15 seconds

## 🚀 Next Steps

Once basic RAG is working:
1. **Load DCWF reference data** for task mapping
2. **Improve classification accuracy** with better prompts
3. **Add YouTube/TikTok processing** capabilities
4. **Implement export functionality** for data analysis