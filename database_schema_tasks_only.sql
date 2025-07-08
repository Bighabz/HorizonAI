-- AI Horizon Database Schema - TASKS ONLY (NO KSAs)
-- For use with Supabase PostgreSQL + pgvector

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- DCWF Tasks table (TASKS ONLY - NO KSAs)
CREATE TABLE IF NOT EXISTS dcwf_tasks (
    id SERIAL PRIMARY KEY,
    task_id VARCHAR(20) UNIQUE NOT NULL, -- e.g., "390A", "391", "T0001"
    task_name VARCHAR(500) NOT NULL,
    task_description TEXT NOT NULL,
    nist_sp_id VARCHAR(20), -- e.g., "T0001", "T0419"
    work_role VARCHAR(100) DEFAULT 'General',
    category VARCHAR(100) DEFAULT 'Task',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Main documents table with vector embeddings for RAG
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    artifact_id VARCHAR(255) UNIQUE NOT NULL,
    title VARCHAR(500),
    summary TEXT,
    content TEXT NOT NULL,
    source_url TEXT,
    source_type VARCHAR(50), -- 'document', 'youtube', 'url'
    filename VARCHAR(255),
    
    -- AI Horizon Classification
    classification VARCHAR(50) CHECK (classification IN ('Replace', 'Augment', 'Remain Human', 'New Task')),
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    rationale TEXT,
    
    -- DCWF TASK mapping (TASKS ONLY - NO KSAs)
    dcwf_task_ids TEXT[], -- Array of DCWF task IDs like ['390A', '391', 'T0001']
    nist_task_ids TEXT[], -- Array of NIST SP task IDs like ['T0001', 'T0419']
    
    -- AI Horizon Scoring
    credibility_score DECIMAL(3,2) CHECK (credibility_score >= 0 AND credibility_score <= 1),
    impact_score DECIMAL(3,2) CHECK (impact_score >= 0 AND impact_score <= 1),
    specificity_score DECIMAL(3,2) CHECK (specificity_score >= 0 AND specificity_score <= 1),
    
    -- Vector embedding for RAG (OpenAI ada-002 = 1536 dimensions)
    embedding vector(1536),
    
    -- User tracking
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255),
    username VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat memory for conversational RAG
CREATE TABLE IF NOT EXISTS chat_memory (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    message_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_task_id ON dcwf_tasks(task_id);
CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_nist_sp_id ON dcwf_tasks(nist_sp_id);
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_classification ON documents(classification);
CREATE INDEX IF NOT EXISTS idx_documents_dcwf_task_ids ON documents USING GIN(dcwf_task_ids);
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON documents USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_chat_memory_user_chat ON chat_memory(user_id, chat_id);

-- Vector similarity search function for TASKS ONLY
CREATE OR REPLACE FUNCTION match_documents_tasks_only(
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
    nist_task_ids text[],
    filename text,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id, d.title, d.content, d.classification, d.dcwf_task_ids, d.nist_task_ids, d.filename,
        (1 - (d.embedding <=> query_embedding)) as similarity
    FROM documents d
    WHERE (user_id IS NULL OR d.user_id = user_id)
        AND (1 - (d.embedding <=> query_embedding)) > match_threshold
        AND d.dcwf_task_ids IS NOT NULL  -- Only documents mapped to tasks
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to get task details by ID
CREATE OR REPLACE FUNCTION get_task_details(task_ids text[])
RETURNS TABLE (
    task_id text,
    task_name text,
    task_description text,
    nist_sp_id text,
    work_role text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.task_id,
        t.task_name,
        t.task_description,
        t.nist_sp_id,
        t.work_role
    FROM dcwf_tasks t
    WHERE t.task_id = ANY(task_ids)
    ORDER BY t.task_id;
END;
$$;

-- Function to get chat history
CREATE OR REPLACE FUNCTION get_chat_history(p_user_id text, p_chat_id text, p_limit int DEFAULT 10)
RETURNS TABLE (
    role text,
    content text,
    created_at timestamp with time zone
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT cm.role, cm.content, cm.created_at
    FROM chat_memory cm
    WHERE cm.user_id = p_user_id AND cm.chat_id = p_chat_id
    ORDER BY cm.created_at DESC
    LIMIT p_limit;
END;
$$;

-- Function to get user stats (TASKS ONLY)
CREATE OR REPLACE FUNCTION get_user_stats_tasks_only(p_user_id text)
RETURNS TABLE (
    documents_processed bigint,
    messages_sent bigint,
    classifications_replace bigint,
    classifications_augment bigint,
    classifications_remain_human bigint,
    classifications_new_task bigint,
    avg_confidence decimal,
    top_dcwf_tasks text[]
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(d.id) as documents_processed,
        COUNT(cm.id) as messages_sent,
        COUNT(CASE WHEN d.classification = 'Replace' THEN 1 END) as classifications_replace,
        COUNT(CASE WHEN d.classification = 'Augment' THEN 1 END) as classifications_augment,
        COUNT(CASE WHEN d.classification = 'Remain Human' THEN 1 END) as classifications_remain_human,
        COUNT(CASE WHEN d.classification = 'New Task' THEN 1 END) as classifications_new_task,
        AVG(d.confidence) as avg_confidence,
        (
            SELECT array_agg(DISTINCT task_id)
            FROM (
                SELECT unnest(d2.dcwf_task_ids) as task_id
                FROM documents d2 
                WHERE d2.user_id = p_user_id
                    AND d2.dcwf_task_ids IS NOT NULL
                LIMIT 10
            ) t
        ) as top_dcwf_tasks
    FROM documents d
    FULL OUTER JOIN chat_memory cm ON d.user_id = cm.user_id
    WHERE d.user_id = p_user_id OR cm.user_id = p_user_id;
END;
$$;

-- Insert sample DCWF tasks (TASKS ONLY)
INSERT INTO dcwf_tasks (task_id, task_name, task_description, nist_sp_id, work_role) VALUES
('390A', 'Task', 'Acquire and maintain a working knowledge of constitutional issues relevant laws, regulations, policies, agreements, standards, procedures, or other issuances.', 'T0419', 'General'),
('391', 'Task', 'Acquire and manage the necessary resources, including leadership support, financial resources, and key security personnel, to support information technology (IT) security goals and objectives and reduce overall organizational risk.', 'T0001', 'General'),
('392', 'Task', 'Acquire necessary resources, including financial resources, to conduct an effective enterprise continuity of operations program.', 'T0002', 'General'),
('393A', 'Task', 'Administer test bed(s), and test and evaluate applications, hardware infrastructure, rules/signatures, access controls, and configurations of platforms managed by service provider(s).', 'T0420', 'General'),
('394A', 'Task', 'Manage the indexing/cataloguing, storage, and access of explicit organizational knowledge (e.g., hard copy documents, digital files).', 'T0421', 'General'),
('395', 'Task', 'Advise senior management (e.g., CIO) on risk levels and security posture.', 'T0003', 'General'),
('396', 'Task', 'Advise senior management (e.g., CIO) on cost/benefit analysis of information security programs, policies, processes, systems, and elements.', 'T0004', 'General')
ON CONFLICT (task_id) DO NOTHING;

-- Create view for easy task lookup
CREATE OR REPLACE VIEW dcwf_task_lookup AS
SELECT 
    task_id,
    task_name,
    task_description,
    nist_sp_id,
    work_role,
    category
FROM dcwf_tasks
ORDER BY task_id;

-- Example queries for testing:
-- SELECT * FROM match_documents_tasks_only('[0.1,0.2,...]'::vector, 0.7, 5, 'user123');
-- SELECT * FROM get_chat_history('user123', 'chat456', 10);
-- SELECT * FROM get_user_stats_tasks_only('user123');
-- SELECT * FROM get_task_details(ARRAY['390A', '391', 'T0001']);
-- SELECT * FROM dcwf_task_lookup WHERE nist_sp_id LIKE 'T04%'; 