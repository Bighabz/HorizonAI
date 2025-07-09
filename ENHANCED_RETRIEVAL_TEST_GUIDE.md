# 🧪 Enhanced Retrieval Testing Guide

## 📋 **Pre-Test Setup**

### 1. Update Your Database
Run the SQL updates in Supabase:
```sql
-- Execute ENHANCED_DATABASE_UPDATE.sql
```

### 2. Import the Enhanced Workflow
```
1. Open n8n
2. Import: AI_HORIZON_ENHANCED_RETRIEVAL_WORKFLOW.json
3. Update credentials (if not already done)
```

### 3. Activate the Workflow
Click "Active" toggle in n8n

## 🔬 **Test Scenarios**

### Test 1: Upload and Last Document Query
**Step 1**: Upload a test document
```
Send to Telegram bot:
- A PDF, DOCX, or URL
- Wait for success message with classification
```

**Step 2**: Query for last document
```
Send: "Tell me about the last document I uploaded"

Expected Response:
📄 Last Document Uploaded:
Title: "[Your Document Title]"
File: [filename]
Classification: [Augment/Replace/etc] (XX% confidence)
Summary: [Full summary]

Associated DCWF Tasks:
- [Task IDs and names]

Tags: [categories]
URL: [if provided]
```

### Test 2: Evidence Query by Classification
**Step 1**: Upload multiple documents
```
Upload 2-3 documents that get different classifications
```

**Step 2**: Query for evidence
```
Send: "What evidence supports the Replace classification?"

Expected Response:
🔍 Evidence Supporting Classification "Replace":

1. Document: "[Title]"
   - Classification: Replace (XX% confidence)
   - Rationale: [Explanation]
   - Credibility: XX%, Impact: XX%, Specificity: XX%
   - URL: [if available]

2. Document: "[Title]"
   ...
```

### Test 3: DCWF Task Query
**Step 1**: Load DCWF tasks
```
Send: "/dcwf"
Wait for confirmation
```

**Step 2**: Query about tasks
```
Send: "What DCWF tasks relate to incident response?"

Expected Response:
🎯 DCWF Tasks Analysis:

ANL-004 (SP-ANL-002): Threat Analyst
📝 [Task description]

Related Documents:
- "[Document Title]" - Replace (94%)
- "[Document Title]" - Augment (87%)
```

### Test 4: Combined Context Query
**Step 1**: After uploading documents
```
Send: "What documents do I have about AI replacing cybersecurity tasks?"

Expected: Semantic search results with full metadata
```

## 🔍 **Validation Checklist**

### Document Upload:
- [ ] Success message shows all metadata
- [ ] Classification with confidence score
- [ ] DCWF tasks identified
- [ ] Summary generated
- [ ] URL preserved (if applicable)

### Last Document Query:
- [ ] Returns most recent upload
- [ ] All metadata displayed
- [ ] Formatted exactly as shown in examples
- [ ] DCWF tasks listed with IDs

### Evidence Query:
- [ ] Filters by classification correctly
- [ ] Shows confidence and scores
- [ ] Multiple documents listed
- [ ] Rationale included

### Chat Memory:
- [ ] Conversation context maintained
- [ ] Previous queries remembered
- [ ] Document references preserved

## 🐛 **Troubleshooting**

### "No documents found"
- Check user_id is consistent
- Verify documents table has data
- Check upload_timestamp is populated

### "Vector search failed"
- Ensure RPC functions are created
- Check Supabase permissions
- Fallback search should activate

### "Wrong classification returned"
- Verify classification field matches exactly
- Check confidence thresholds
- Ensure proper filtering in queries

## 📊 **Performance Metrics**

Monitor these for optimal performance:
- Query response time: < 3 seconds
- Embedding generation: < 2 seconds
- Document processing: < 10 seconds
- Success rate: > 95%

## ✅ **Success Criteria**

The enhanced retrieval is working when:
1. ✅ "Last document" queries return accurate results
2. ✅ Evidence aggregation works by classification
3. ✅ DCWF task searches return relevant documents
4. ✅ Chat maintains context across conversations
5. ✅ All metadata is preserved and displayed

Happy testing! 🎉 