-- AI Horizon Forecasting Pipeline - Complete Supabase Schema
-- Based on real DCWF data from DCWFMASTER.xlsx and AIHORIZON.txt requirements

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- DCWF Master data tables (based on DCWFMASTER.xlsx structure)
CREATE TABLE IF NOT EXISTS dcwf_tasks (
    id SERIAL PRIMARY KEY,
    dcwf_id VARCHAR(20) UNIQUE NOT NULL, -- e.g., "390A", "391", "T0001"
    nist_sp_id VARCHAR(20), -- e.g., "T0001", "T0419" 
    task_description TEXT NOT NULL,
    task_type VARCHAR(10) CHECK (task_type IN ('Task', 'KSA')),
    category VARCHAR(100),
    subcategory VARCHAR(100),
    work_roles TEXT[], -- Array of associated work roles
    specialty_areas TEXT[], -- Array of specialty areas
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- AI Horizon artifacts/documents table with vector embeddings
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    artifact_id VARCHAR(255) UNIQUE NOT NULL,
    title VARCHAR(500),
    summary TEXT,
    content TEXT NOT NULL,
    source_url TEXT,
    source_type VARCHAR(50), -- 'document', 'youtube', 'tiktok', 'url', 'rss'
    filename VARCHAR(255),
    file_size BIGINT,
    mime_type VARCHAR(100),
    
    -- AI Horizon Classification (from AIHORIZON.txt)
    classification VARCHAR(50) CHECK (classification IN ('Replace', 'Augment', 'Remain Human', 'New Task')),
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    rationale TEXT,
    
    -- DCWF task mapping
    dcwf_task_ids TEXT[], -- Array of DCWF task IDs
    nist_task_ids TEXT[], -- Array of NIST SP task IDs (T0xxx)
    
    -- AI Horizon Scoring (from AIHORIZON.txt requirements)
    credibility_score DECIMAL(3,2) CHECK (credibility_score >= 0 AND credibility_score <= 1),
    impact_score DECIMAL(3,2) CHECK (impact_score >= 0 AND impact_score <= 1),
    specificity_score DECIMAL(3,2) CHECK (specificity_score >= 0 AND specificity_score <= 1),
    
    -- Vector embedding for RAG functionality
    embedding vector(1536), -- OpenAI ada-002 embedding dimension
    
    -- User and metadata
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255),
    username VARCHAR(255),
    processed_by VARCHAR(100) DEFAULT 'ai-horizon-pipeline',
    retrieved_on DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat memory for conversational RAG
CREATE TABLE IF NOT EXISTS chat_memory (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    message_id VARCHAR(255),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Analysis results for tracking forecasting outcomes
CREATE TABLE IF NOT EXISTS analysis_results (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    analysis_type VARCHAR(50) DEFAULT 'ai_impact_forecast',
    classification VARCHAR(50),
    confidence DECIMAL(3,2),
    rationale TEXT,
    dcwf_tasks_affected TEXT[],
    impact_level VARCHAR(20) CHECK (impact_level IN ('Low', 'Medium', 'High', 'Critical')),
    timeline_estimate VARCHAR(50), -- e.g., "1-2 years", "3-5 years"
    evidence_quality VARCHAR(20) CHECK (evidence_quality IN ('Strong', 'Moderate', 'Weak')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User sessions for tracking engagement
CREATE TABLE IF NOT EXISTS user_sessions (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    session_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_end TIMESTAMP WITH TIME ZONE,
    message_count INTEGER DEFAULT 0,
    documents_processed INTEGER DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Weekly reports table (from AIHORIZON.txt requirements)
CREATE TABLE IF NOT EXISTS weekly_reports (
    id SERIAL PRIMARY KEY,
    report_date DATE NOT NULL,
    report_type VARCHAR(50) DEFAULT 'weekly_forecast',
    summary TEXT,
    total_artifacts INTEGER DEFAULT 0,
    replace_count INTEGER DEFAULT 0,
    augment_count INTEGER DEFAULT 0,
    remain_human_count INTEGER DEFAULT 0,
    new_task_count INTEGER DEFAULT 0,
    avg_confidence DECIMAL(3,2),
    top_dcwf_tasks TEXT[],
    report_data JSONB, -- Full structured report data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_classification ON documents(classification);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);
CREATE INDEX IF NOT EXISTS idx_documents_dcwf_tasks ON documents USING GIN(dcwf_task_ids);
CREATE INDEX IF NOT EXISTS idx_documents_nist_tasks ON documents USING GIN(nist_task_ids);
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_chat_memory_user_chat ON chat_memory(user_id, chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_memory_timestamp ON chat_memory(timestamp);

CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_nist_id ON dcwf_tasks(nist_sp_id);
CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_type ON dcwf_tasks(task_type);

-- Vector similarity search function for RAG
CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 5,
    user_id text DEFAULT NULL
)
RETURNS TABLE (
    id int,
    artifact_id text,
    title text,
    summary text,
    content text,
    classification text,
    confidence decimal,
    dcwf_task_ids text[],
    nist_task_ids text[],
    filename text,
    source_type text,
    created_at timestamptz,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id,
        d.artifact_id,
        d.title,
        d.summary,
        d.content,
        d.classification,
        d.confidence,
        d.dcwf_task_ids,
        d.nist_task_ids,
        d.filename,
        d.source_type,
        d.created_at,
        (1 - (d.embedding <=> query_embedding)) as similarity
    FROM documents d
    WHERE 
        (user_id IS NULL OR d.user_id = user_id)
        AND (1 - (d.embedding <=> query_embedding)) > match_threshold
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to get chat history
CREATE OR REPLACE FUNCTION get_chat_history(
    p_user_id text,
    p_chat_id text,
    p_limit int DEFAULT 10
)
RETURNS TABLE (
    role text,
    content text,
    timestamp timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.role,
        cm.content,
        cm.timestamp
    FROM chat_memory cm
    WHERE cm.user_id = p_user_id 
        AND cm.chat_id = p_chat_id
    ORDER BY cm.timestamp DESC
    LIMIT p_limit;
END;
$$;

-- Function to get user statistics
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id text)
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
                LIMIT 10
            ) t
        ) as top_dcwf_tasks
    FROM documents d
    FULL OUTER JOIN chat_memory cm ON d.user_id = cm.user_id
    WHERE d.user_id = p_user_id OR cm.user_id = p_user_id;
END;
$$;

-- Function to generate weekly report
CREATE OR REPLACE FUNCTION generate_weekly_report(report_week date DEFAULT CURRENT_DATE)
RETURNS TABLE (
    total_artifacts bigint,
    replace_count bigint,
    augment_count bigint,
    remain_human_count bigint,
    new_task_count bigint,
    avg_confidence decimal,
    top_dcwf_tasks text[]
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_artifacts,
        COUNT(CASE WHEN classification = 'Replace' THEN 1 END) as replace_count,
        COUNT(CASE WHEN classification = 'Augment' THEN 1 END) as augment_count,
        COUNT(CASE WHEN classification = 'Remain Human' THEN 1 END) as remain_human_count,
        COUNT(CASE WHEN classification = 'New Task' THEN 1 END) as new_task_count,
        AVG(confidence) as avg_confidence,
        (
            SELECT array_agg(DISTINCT task_id ORDER BY task_id)
            FROM (
                SELECT unnest(dcwf_task_ids) as task_id
                FROM documents 
                WHERE created_at >= report_week - INTERVAL '7 days'
                    AND created_at < report_week
                GROUP BY task_id
                ORDER BY COUNT(*) DESC
                LIMIT 20
            ) t
        ) as top_dcwf_tasks
    FROM documents
    WHERE created_at >= report_week - INTERVAL '7 days'
        AND created_at < report_week;
END;
$$;

-- Insert sample DCWF tasks (based on DCWFMASTER.xlsx analysis)
INSERT INTO dcwf_tasks (dcwf_id, nist_sp_id, task_description, task_type, category) VALUES
('390A', 'T0419', 'Acquire and maintain a working knowledge of constitutional issues relevant laws, regulations, policies, agreements, standards, procedures, or other issuances.', 'Task', 'General'),
('391', 'T0001', 'Acquire and manage the necessary resources, including leadership support, financial resources, and key security personnel, to support information technology (IT) security goals and objectives and reduce overall organizational risk.', 'Task', 'General'),
('392', 'T0002', 'Acquire necessary resources, including financial resources, to conduct an effective enterprise continuity of operations program.', 'Task', 'General'),
('393A', 'T0420', 'Administer test bed(s), and test and evaluate applications, hardware infrastructure, rules/signatures, access controls, and configurations of platforms managed by service provider(s).', 'Task', 'General'),
('393B', 'T0420', 'Coordinate with system administrators to create cyber defense tools, test bed(s), and test and evaluate applications, hardware infrastructure, rules/signatures, access controls, and configurations of platforms managed by service provider(s).', 'Task', 'General'),
('394A', 'T0421', 'Manage the indexing/cataloguing, storage, and access of explicit organizational knowledge (e.g., hard copy documents, digital files).', 'Task', 'General'),
('395', 'T0003', 'Advise senior management (e.g., CIO) on risk levels and security posture.', 'Task', 'General'),
('395A', NULL, 'Advise senior management on risk levels, security posture, and necessary changes to existing AI policies.', 'Task', 'General'),
('396', 'T0004', 'Advise senior management (e.g., CIO) on cost/benefit analysis of information security programs, policies, processes, systems, and elements.', 'Task', 'General')
ON CONFLICT (dcwf_id) DO NOTHING;

-- Create view for easy task lookup
CREATE OR REPLACE VIEW dcwf_task_lookup AS
SELECT 
    dcwf_id,
    nist_sp_id,
    task_description,
    task_type,
    category,
    work_roles,
    specialty_areas
FROM dcwf_tasks
WHERE task_type = 'Task'
ORDER BY dcwf_id;

-- Grant permissions (adjust as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO your_user;

-- Example queries for testing:
-- SELECT * FROM match_documents('[0.1,0.2,...]'::vector, 0.7, 5, 'user123');
-- SELECT * FROM get_chat_history('user123', 'chat456', 10);
-- SELECT * FROM get_user_stats('user123');
-- SELECT * FROM generate_weekly_report(CURRENT_DATE);
-- SELECT * FROM dcwf_task_lookup WHERE nist_sp_id LIKE 'T04%';