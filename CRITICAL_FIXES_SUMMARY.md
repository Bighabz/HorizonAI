# 🎯 CRITICAL RAG FIXES - PRIORITY ORDER

## 🚨 IMMEDIATE FIXES (Must do first - 30 minutes)

### 1. Create SQL Function in Supabase
**Go to Supabase Dashboard → SQL Editor → Run this:**
```sql
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10,
  user_id text DEFAULT NULL
)
RETURNS TABLE (
  id uuid, title text, content text, classification text,
  filename text, category text, tags text[], similarity float
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT d.id, d.title, d.content, d.classification, d.filename, d.category, d.tags,
         1 - (d.embedding <=> query_embedding) as similarity
  FROM documents d
  WHERE d.embedding IS NOT NULL
    AND (user_id IS NULL OR d.user_id = user_id)
    AND 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END; $$;
```

### 2. Update OpenAI API Key in n8n
**n8n → Settings → Credentials → OpenAI → Update API Key**

### 3. Add "Generate Query Embedding" Node
**Insert between "Prepare Vector Search" and "Vector Search Documents":**
- **Type:** HTTP Request
- **URL:** `https://api.openai.com/v1/embeddings`
- **Headers:** `Authorization: Bearer {{ $credentials.openAi.apiKey }}`
- **Body:** `{"model": "text-embedding-ada-002", "input": "{{ $('Prepare Chat Input').item.json.userMessage }}"}`

### 4. Replace "Vector Search Documents" Node
**Delete current Supabase node, add HTTP Request:**
- **URL:** `{{ $env.SUPABASE_URL }}/rest/v1/rpc/match_documents`
- **Headers:** `Authorization: Bearer {{ $env.SUPABASE_SERVICE_KEY }}`
- **Body:** `{"query_embedding": "{{ $('Generate Query Embedding').item.json.data[0].embedding }}", "user_id": "{{ $('Prepare Chat Input').item.json.userId }}"}`

## 🔧 DATA MAPPING FIXES (Critical for functionality)

### 5. Fix "Build AI Context" Node
**Replace the JavaScript code with:**
```javascript
let chatData, history = [], searchResults = [];

try {
  chatData = $('Prepare Chat Input').item.json;
} catch (e) {
  throw new Error('Chat input data not available');
}

try {
  history = $('Get Chat History').all() || [];
} catch (e) {
  console.log('No chat history available');
}

try {
  const vectorSearchNode = $('Vector Similarity Search');
  if (vectorSearchNode?.item?.json) {
    const results = vectorSearchNode.item.json;
    if (Array.isArray(results)) {
      searchResults = results;
    } else if (results.data && Array.isArray(results.data)) {
      searchResults = results.data;
    }
  }
} catch (e) {
  console.log('No vector search results available');
}

const formattedHistory = history
  .reverse()
  .slice(0, 10)
  .map(msg => `${msg.json.role === 'user' ? 'User' : 'Assistant'}: ${msg.json.content}`)
  .join('\n\n');

let relevantDocs = 'No relevant documents found.';
if (searchResults.length > 0) {
  relevantDocs = searchResults.slice(0, 5)
    .map((doc, index) => {
      const similarity = doc.similarity ? `${(doc.similarity * 100).toFixed(1)}%` : 'N/A';
      return `**Document ${index + 1}** (Similarity: ${similarity})\n**Title:** ${doc.title}\n**Content:** ${(doc.content || '').substring(0, 800)}...\n`;
    })
    .join('\n---\n');
}

const systemMessage = `You are an AI assistant for Project Horizon.

**Your Knowledge Base:**
${relevantDocs}

**Recent Conversation:**
${formattedHistory || 'No previous messages.'}

Use the knowledge base to answer questions about AI's impact on cybersecurity work.`;

return {
  json: {
    systemMessage,
    userMessage: chatData.userMessage,
    chatId: chatData.chatId,
    userId: chatData.userId,
    username: chatData.username,
    messageId: chatData.messageId,
    documentsFound: searchResults.length
  }
};
```

### 6. Fix Embedding Storage
**In "Store in Supabase" node, update embedding field:**
```
{{ JSON.stringify($('Generate Embedding').item.json.data[0].embedding) }}
```

## ✅ Test Sequence

1. **Send "Hello"** → Should get welcome message
2. **Upload test document** → Should process successfully  
3. **Ask "What was that document about?"** → Should get contextual response with similarity scores

## 🎯 Success Indicators

- ✅ Documents get processed and stored with embeddings
- ✅ Vector search returns relevant documents with similarity scores
- ✅ Bot responses include specific document references
- ✅ Chat maintains context across conversations

## 🚨 Common Issues

1. **"Function match_documents not found"** → Create SQL function in Supabase
2. **"OpenAI API error"** → Update API key in n8n credentials
3. **"No search results"** → Check node names match exactly
4. **"Embedding storage fails"** → Fix JSON.stringify in Store node

**Total Implementation Time: ~45 minutes**
**Expected Result: Fully functional RAG system with vector search**