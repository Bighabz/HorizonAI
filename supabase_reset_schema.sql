-- AI Horizon RAG Agent - Complete Schema Reset
-- This script drops all existing tables and creates the new schema

-- Drop existing tables (in correct order due to foreign keys)
DROP TABLE IF EXISTS analysis_results CASCADE;
DROP TABLE IF EXISTS weekly_reports CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS chat_memory CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS dcwf_tasks CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS match_documents CASCADE;
DROP FUNCTION IF EXISTS get_chat_history CASCADE;
DROP FUNCTION IF EXISTS get_user_stats CASCADE;
DROP FUNCTION IF EXISTS generate_weekly_report CASCADE;

-- Drop existing views
DROP VIEW IF EXISTS dcwf_task_lookup CASCADE;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- DCWF Master data table
CREATE TABLE dcwf_tasks (
    id SERIAL PRIMARY KEY,
    dcwf_id VARCHAR(20) UNIQUE NOT NULL,
    nist_sp_id VARCHAR(20),
    task_description TEXT NOT NULL,
    task_type VARCHAR(10) CHECK (task_type IN ('Task', 'KSA')),
    category VARCHAR(100),
    work_roles TEXT[],
    specialty_areas TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- AI Horizon documents with vector embeddings
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
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    rationale TEXT,
    dcwf_task_ids TEXT[],
    nist_task_ids TEXT[],
    credibility_score DECIMAL(3,2) CHECK (credibility_score >= 0 AND credibility_score <= 1),
    impact_score DECIMAL(3,2) CHECK (impact_score >= 0 AND impact_score <= 1),
    specificity_score DECIMAL(3,2) CHECK (specificity_score >= 0 AND specificity_score <= 1),
    embedding vector(1536),
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255),
    username VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat memory for RAG conversations
CREATE TABLE chat_memory (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    message_id VARCHAR(255),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Analysis results tracking
CREATE TABLE analysis_results (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    classification VARCHAR(50),
    confidence DECIMAL(3,2),
    rationale TEXT,
    dcwf_tasks_affected TEXT[],
    impact_level VARCHAR(20) CHECK (impact_level IN ('Low', 'Medium', 'High', 'Critical')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User sessions
CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    session_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    message_count INTEGER DEFAULT 0,
    documents_processed INTEGER DEFAULT 0
);

-- Weekly reports
CREATE TABLE weekly_reports (
    id SERIAL PRIMARY KEY,
    report_date DATE NOT NULL,
    total_artifacts INTEGER DEFAULT 0,
    replace_count INTEGER DEFAULT 0,
    augment_count INTEGER DEFAULT 0,
    remain_human_count INTEGER DEFAULT 0,
    new_task_count INTEGER DEFAULT 0,
    avg_confidence DECIMAL(3,2),
    top_dcwf_tasks TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_classification ON documents(classification);
CREATE INDEX idx_documents_dcwf_tasks ON documents USING GIN(dcwf_task_ids);
CREATE INDEX idx_documents_embedding ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_chat_memory_user_chat ON chat_memory(user_id, chat_id);
CREATE INDEX idx_chat_memory_timestamp ON chat_memory(timestamp);

-- Vector similarity search function
CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 5,
    user_id text DEFAULT NULL
)
RETURNS TABLE (
    id int, artifact_id text, title text, summary text, content text,
    classification text, confidence decimal, dcwf_task_ids text[],
    filename text, source_type text, created_at timestamptz, similarity float
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT d.id, d.artifact_id, d.title, d.summary, d.content, d.classification,
           d.confidence, d.dcwf_task_ids, d.filename, d.source_type, d.created_at,
           (1 - (d.embedding <=> query_embedding)) as similarity
    FROM documents d
    WHERE (user_id IS NULL OR d.user_id = user_id)
        AND (1 - (d.embedding <=> query_embedding)) > match_threshold
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Chat history function
CREATE OR REPLACE FUNCTION get_chat_history(p_user_id text, p_chat_id text, p_limit int DEFAULT 10)
RETURNS TABLE (role text, content text, timestamp timestamptz)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT cm.role, cm.content, cm.timestamp
    FROM chat_memory cm
    WHERE cm.user_id = p_user_id AND cm.chat_id = p_chat_id
    ORDER BY cm.timestamp DESC LIMIT p_limit;
END;
$$;

-- User stats function
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id text)
RETURNS TABLE (
    documents_processed bigint, messages_sent bigint, classifications_replace bigint,
    classifications_augment bigint, classifications_remain_human bigint,
    classifications_new_task bigint, avg_confidence decimal
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT COUNT(d.id) as documents_processed, COUNT(cm.id) as messages_sent,
           COUNT(CASE WHEN d.classification = 'Replace' THEN 1 END) as classifications_replace,
           COUNT(CASE WHEN d.classification = 'Augment' THEN 1 END) as classifications_augment,
           COUNT(CASE WHEN d.classification = 'Remain Human' THEN 1 END) as classifications_remain_human,
           COUNT(CASE WHEN d.classification = 'New Task' THEN 1 END) as classifications_new_task,
           AVG(d.confidence) as avg_confidence
    FROM documents d
    FULL OUTER JOIN chat_memory cm ON d.user_id = cm.user_id
    WHERE d.user_id = p_user_id OR cm.user_id = p_user_id;
END;
$$;

-- Insert sample DCWF tasks
INSERT INTO dcwf_tasks (dcwf_id, nist_sp_id, task_description, task_type, category) VALUES
('390A', 'T0419', 'Acquire and maintain working knowledge of laws, regulations, policies, agreements, standards, procedures', 'Task', 'General'),
('391', 'T0001', 'Acquire and manage necessary resources for IT security goals and objectives', 'Task', 'General'),
('392', 'T0002', 'Acquire necessary resources for effective enterprise continuity operations', 'Task', 'General'),
('393A', 'T0420', 'Administer test beds and evaluate applications, hardware infrastructure, access controls', 'Task', 'General'),
('394A', 'T0421', 'Manage indexing, cataloguing, storage, and access of organizational knowledge', 'Task', 'General'),
('395', 'T0003', 'Advise senior management on risk levels and security posture', 'Task', 'General'),
('396', 'T0004', 'Advise senior management on cost/benefit analysis of security programs', 'Task', 'General');

-- Create lookup view
CREATE VIEW dcwf_task_lookup AS
SELECT dcwf_id, nist_sp_id, task_description, task_type, category
FROM dcwf_tasks WHERE task_type = 'Task' ORDER BY dcwf_id;