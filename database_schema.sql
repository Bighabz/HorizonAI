-- AI Horizon Database Schema - Essential Tables Only
-- For use with Supabase PostgreSQL + pgvector

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

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
    
    -- DCWF task mapping
    dcwf_task_ids TEXT[], -- Array of DCWF task IDs like ['T0001', 'T0419']
    
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_classification ON documents(classification);
CREATE INDEX IF NOT EXISTS idx_documents_dcwf_tasks ON documents USING GIN(dcwf_task_ids);
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_chat_memory_user_chat ON chat_memory(user_id, chat_id);

-- Vector similarity search function for RAG
CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.3,
    match_count int DEFAULT 5,
    user_id_filter text DEFAULT NULL
)
RETURNS TABLE (
    id int,
    title text,
    content text,
    classification text,
    dcwf_task_ids text[],
    filename text,
    distance float
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
        d.dcwf_task_ids,
        d.filename,
        (d.embedding <=> query_embedding) as distance
    FROM documents d
    WHERE 
        (user_id_filter IS NULL OR d.user_id = user_id_filter)
        AND (d.embedding <=> query_embedding) < match_threshold
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Example usage:
-- SELECT * FROM match_documents('[0.1,0.2,...]'::vector, 0.3, 5, 'user123');
-- 
-- For n8n workflow, use this SQL in "runSql" operation:
-- SELECT *, (embedding <=> '[{{ $json.data[0].embedding.join(',') }}]'::vector) as distance 
-- FROM documents 
-- WHERE user_id = '{{ $('Prepare Chat Input').item.json.userId }}' 
--   AND (embedding <=> '[{{ $json.data[0].embedding.join(',') }}]'::vector) < 0.3 
-- ORDER BY distance LIMIT 5;