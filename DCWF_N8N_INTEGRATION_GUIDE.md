# DCWF Task Upload Integration Guide for n8n Workflow

## 🎯 **Integration Overview**

This guide shows how to integrate your DCWF task upload functionality directly into your n8n workflow, combining your existing Python scripts with n8n automation.

## 📋 **Current State Analysis**

### **What You Have:**
- ✅ **2 n8n workflows** (ai_horizon_main_workflow.json, My_workflow_26.json)
- ✅ **936 DCWF tasks** extracted by `extract_dcwf_tasks_only.py`
- ✅ **Upload scripts** (`upload_dcwf_tasks_only.py`, `upload_dcwf.py`)
- ✅ **Database schema** (`database_schema_tasks_only.sql`)
- ✅ **Task keywords** (`dcwf_task_keywords.json`)

### **What's Missing:**
- ❌ **No DCWF upload node** in either n8n workflow
- ❌ **No dynamic task loading** (currently hardcoded examples)
- ❌ **No auto-cleanup** of previous uploads
- ❌ **No workflow variable** for task reference

## 🔧 **Integration Steps**

### **Step 1: Add DCWF Upload Detection**

Add this to your **Route by Type** switch node:

```javascript
// Add new route condition
{
  "conditions": {
    "conditions": [
      {
        "leftValue": "={{ $json.routeType }}",
        "rightValue": "dcwf_upload",
        "operator": { "type": "string", "operation": "equals" }
      }
    ]
  },
  "renameOutput": true,
  "outputKey": "dcwf_upload"
}
```

### **Step 2: Update Route Detection Logic**

Modify the **Detect Route Type** node to identify DCWF uploads:

```javascript
// Add DCWF detection logic
else if (update.message.document) {
  const doc = update.message.document;
  const fileName = doc.file_name || '';
  
  // Check if it's a DCWF upload
  if (fileName.toLowerCase().includes('dcwf') || 
      fileName.toLowerCase().includes('task') ||
      fileName.toLowerCase().includes('nist')) {
    routeType = 'dcwf_upload';
    data = {
      routeType: 'dcwf_upload',
      fileId: doc.file_id,
      fileName: fileName,
      mimeType: doc.mime_type,
      fileSize: doc.file_size,
      chatId: update.message.chat.id,
      userId: update.message.from.id,
      username: update.message.from.username,
      messageId: update.message.message_id,
      source: 'telegram'
    };
  }
}
```

### **Step 3: Add DCWF Processing Nodes**

Insert these nodes after the **Route by Type** node:

1. **DCWF Task Upload Processor** (see `n8n_dcwf_upload_node.json`)
2. **Upload DCWF to Database** (Supabase node)
3. **Enhanced AI Classification with DCWF** (Updated AI node)

### **Step 4: Create Workflow Variables**

Add this node to initialize workflow variables:

```javascript
// Initialize Workflow Variables
const dcwfTaskList = {
  tasks: [],
  totalTasks: 0,
  lastUpdated: null,
  source: 'none'
};

// Store in workflow variables
workflow.variables.dcwfTaskList = dcwfTaskList;

return {
  json: {
    variablesInitialized: true,
    dcwfTaskList: dcwfTaskList
  }
};
```

## 🗄️ **Database Integration**

### **1. Required Tables**

Ensure your Supabase has these tables:

```sql
-- DCWF Tasks table (from your database_schema_tasks_only.sql)
CREATE TABLE dcwf_tasks (
    id SERIAL PRIMARY KEY,
    task_id VARCHAR(20) UNIQUE NOT NULL,
    task_name VARCHAR(500) NOT NULL,
    task_description TEXT NOT NULL,
    nist_sp_id VARCHAR(20),
    work_role VARCHAR(100) DEFAULT 'General',
    category VARCHAR(100) DEFAULT 'Task',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enhanced documents table with DCWF task mapping
ALTER TABLE documents 
ADD COLUMN dcwf_task_ids TEXT[] DEFAULT '{}',
ADD COLUMN nist_task_ids TEXT[] DEFAULT '{}';
```

### **2. Database Functions**

Add these functions to your Supabase:

```sql
-- Get DCWF tasks for workflow
CREATE OR REPLACE FUNCTION get_dcwf_tasks_for_workflow()
RETURNS TABLE (
    task_id VARCHAR(20),
    task_name VARCHAR(500),
    task_description TEXT,
    nist_sp_id VARCHAR(20),
    work_role VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.task_id,
        t.task_name,
        t.task_description,
        t.nist_sp_id,
        t.work_role
    FROM dcwf_tasks t
    ORDER BY t.task_id;
END;
$$ LANGUAGE plpgsql;

-- Clean up old DCWF uploads
CREATE OR REPLACE FUNCTION cleanup_old_dcwf_uploads()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM dcwf_tasks 
    WHERE created_at < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
```

## 📤 **Upload Process Integration**

### **Recommended Flow:**

1. **Python Script Upload** (Current) ✅
   - Use `python upload_dcwf_tasks_only.py` for initial setup
   - Handles 936 tasks with full validation

2. **n8n Workflow Upload** (New) ✨
   - Handles incremental updates
   - Auto-detects DCWF files
   - Integrates with chat flow

3. **Hybrid Approach** (Recommended) 🎯
   - Python for bulk uploads
   - n8n for real-time updates
   - Shared database and validation

## 🔄 **Workflow Reference System**

### **How to Reference DCWF Tasks:**

```javascript
// In any node, reference the task list:
const dcwfTasks = workflow.variables.dcwfTaskList?.tasks || [];

// Example: Find tasks by ID
const taskT0419 = dcwfTasks.find(t => t.nist_sp_id === 'T0419');

// Example: Get all tasks for a work role
const analystTasks = dcwfTasks.filter(t => t.work_role === 'Cyber Defense Analyst');

// Example: Search task descriptions
const threatTasks = dcwfTasks.filter(t => 
  t.task_description.toLowerCase().includes('threat')
);
```

### **AI Classification Enhancement:**

```javascript
// Enhanced system prompt with dynamic task loading
const systemPrompt = `
You are an AI classifier for Project Horizon.

DCWF Task Reference (${workflow.variables.dcwfTaskList?.totalTasks || 0} tasks loaded):
${workflow.variables.dcwfTaskList?.tasks?.slice(0, 20).map(t => 
  `- ${t.task_id} (${t.nist_sp_id}): ${t.task_name}`
).join('\\n') || 'No DCWF tasks loaded'}

Map content to specific DCWF task IDs when mentioned or implied.
`;
```

## 🎯 **Implementation Plan**

### **Phase 1: Database Setup** (15 minutes)
1. Run `database_schema_tasks_only.sql` in Supabase
2. Upload tasks using `python upload_dcwf_tasks_only.py`
3. Verify 936 tasks in database

### **Phase 2: Workflow Integration** (30 minutes)
1. Add DCWF upload detection to **Route by Type**
2. Insert DCWF processing nodes
3. Update AI Classification node
4. Add workflow variables

### **Phase 3: Testing** (15 minutes)
1. Upload a DCWF CSV file via Telegram
2. Verify auto-detection and processing
3. Test AI classification with task references
4. Validate document mapping

### **Phase 4: Optimization** (Ongoing)
1. Monitor performance with 936 tasks
2. Add auto-cleanup for old uploads
3. Implement incremental updates
4. Add task search functionality

## 🏷️ **Reference Names for n8n**

Use these consistent references throughout your workflow:

```javascript
// Primary reference
workflow.variables.dcwfTaskList

// Specific access patterns
workflow.variables.dcwfTaskList.tasks           // Array of all tasks
workflow.variables.dcwfTaskList.totalTasks      // Count
workflow.variables.dcwfTaskList.lastUpdated     // Timestamp
workflow.variables.dcwfTaskList.source          // 'python_upload' or 'workflow_upload'

// Helper functions
const findTaskById = (id) => workflow.variables.dcwfTaskList.tasks.find(t => t.task_id === id);
const findTaskByNIST = (nist) => workflow.variables.dcwfTaskList.tasks.find(t => t.nist_sp_id === nist);
const getTasksByRole = (role) => workflow.variables.dcwfTaskList.tasks.filter(t => t.work_role === role);
```

## 🚀 **Next Steps**

1. **Implement Phase 1** - Set up database and upload your 936 tasks
2. **Test current Python workflow** - Verify everything works
3. **Implement Phase 2** - Add n8n integration nodes
4. **Share updated workflow** - I'll help you merge the changes

Would you like me to start with Phase 1 and help you set up the database integration? 