-- Enhanced AI Horizon Database Schema with Archon Patterns
-- Supabase PostgreSQL + pgvector for RAG workflow

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- DCWF Tasks table (Tasks Only - No KSAs)
-- Inspired by Archon's site_pages structure but specialized for DCWF
CREATE TABLE IF NOT EXISTS dcwf_tasks (
    id SERIAL PRIMARY KEY,
    task_id VARCHAR(20) UNIQUE NOT NULL, -- e.g., "390A", "391", "T0001"
    task_name VARCHAR(500) NOT NULL,
    task_description TEXT NOT NULL,
    nist_sp_id VARCHAR(20), -- e.g., "T0001", "T0419"
    work_role VARCHAR(100) DEFAULT 'General',
    category VARCHAR(100) DEFAULT 'Task',
    
    -- Archon-inspired enhancements
    embedding VECTOR(1536), -- OpenAI embeddings for semantic search
    metadata JSONB DEFAULT '{}', -- Flexible metadata storage
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enhanced Documents table with full RAG support
-- Combines your current structure with Archon's patterns
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Core document info
    artifact_id VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(500) NOT NULL,
    summary TEXT,
    content TEXT NOT NULL,
    
    -- Source information
    source_url TEXT,
    source_type VARCHAR(50), -- pdf, docx, csv, youtube, etc.
    filename VARCHAR(255),
    
    -- Enhanced classification (your 4-category system)
    classification VARCHAR(50) NOT NULL, -- Replace, Augment, Remain Human, New Task
    confidence FLOAT DEFAULT 0,
    rationale TEXT,
    
    -- Enhanced scoring system
    scores JSONB DEFAULT '{"credibility": 0, "impact": 0, "specificity": 0}',
    impact_score FLOAT DEFAULT 0,
    
    -- DCWF task mapping (enhanced)
    dcwf_task_ids TEXT[] DEFAULT '{}',
    nist_task_ids TEXT[] DEFAULT '{}',
    work_roles TEXT[] DEFAULT '{}',
    
    -- User and chat context
    user_id VARCHAR(50),
    chat_id VARCHAR(50),
    username VARCHAR(100),
    
    -- Categorization and tagging
    category VARCHAR(100) DEFAULT 'General',
    tags TEXT[] DEFAULT '{}',
    
    -- Archon-inspired enhancements
    chunk_index INTEGER DEFAULT 0,
    total_chunks INTEGER DEFAULT 1,
    embedding VECTOR(1536), -- OpenAI embeddings
    metadata JSONB DEFAULT '{}', -- Comprehensive metadata storage
    
    -- Evidence tracking (Archon pattern)
    evidence_strength VARCHAR(20) DEFAULT 'MEDIUM', -- HIGH, MEDIUM, LOW
    citation_count INTEGER DEFAULT 0,
    referenced_by UUID[] DEFAULT '{}', -- Documents that reference this one
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enhanced Chat Memory with embeddings (Archon pattern)
-- Persistent conversational memory for RAG
CREATE TABLE IF NOT EXISTS chat_memory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- User and chat context
    user_id VARCHAR(50) NOT NULL,
    chat_id VARCHAR(50) NOT NULL,
    username VARCHAR(100),
    
    -- Message content
    role VARCHAR(20) NOT NULL, -- user, assistant, system
    content TEXT NOT NULL,
    
    -- Archon-inspired memory features
    embedding VECTOR(1536), -- Semantic search over chat history
    message_type VARCHAR(50) DEFAULT 'general', -- memory_query, evidence_request, etc.
    
    -- Enhanced metadata with evidence tracking
    metadata JSONB DEFAULT '{}', -- Message metadata, evidence, context
    
    -- Memory importance scoring
    importance_score FLOAT DEFAULT 0.5, -- 0-1 scale for memory retention
    reference_count INTEGER DEFAULT 0, -- How often this memory is referenced
    
    -- Relationship tracking
    related_documents UUID[] DEFAULT '{}',
    related_tasks VARCHAR(20)[] DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '30 days')
);

-- Knowledge Graph Relationships (Archon-inspired)
-- Multi-hop reasoning between tasks, documents, and concepts
CREATE TABLE IF NOT EXISTS knowledge_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relationship definition
    source_type VARCHAR(50) NOT NULL, -- dcwf_task, document, concept
    source_id VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id VARCHAR(100) NOT NULL,
    
    -- Relationship characteristics
    relationship_type VARCHAR(50) NOT NULL, -- depends_on, enables, similar_to, impacts_role, etc.
    strength FLOAT DEFAULT 0.5, -- 0-1 relationship strength
    confidence FLOAT DEFAULT 0.5, -- 0-1 confidence in relationship
    
    -- Evidence for relationship
    evidence_sources UUID[] DEFAULT '{}', -- Documents supporting this relationship
    reasoning TEXT, -- Why this relationship exists
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- AI Capabilities Mapping (your enhanced system)
-- Maps AI technologies to DCWF tasks with impact analysis
CREATE TABLE IF NOT EXISTS ai_capabilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    capability_name VARCHAR(100) NOT NULL,
    capability_type VARCHAR(50), -- ML_Threat_Detection, Automated_Incident_Response, etc.
    description TEXT,
    
    -- Task impact mapping
    affected_tasks VARCHAR(20)[] DEFAULT '{}',
    impact_type VARCHAR(50), -- Replace, Augment, Enable, Create
    impact_confidence FLOAT DEFAULT 0,
    
    -- Evidence and reasoning
    supporting_documents UUID[] DEFAULT '{}',
    rationale TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance (Archon pattern)
CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_embedding ON dcwf_tasks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_chat_memory_embedding ON chat_memory USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- User-specific indexes
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_memory_user_chat ON chat_memory(user_id, chat_id);
CREATE INDEX IF NOT EXISTS idx_documents_classification ON documents(classification);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);

-- DCWF-specific indexes
CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_task_id ON dcwf_tasks(task_id);
CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_nist_sp_id ON dcwf_tasks(nist_sp_id);
CREATE INDEX IF NOT EXISTS idx_documents_dcwf_tasks ON documents USING GIN (dcwf_task_ids);

-- Knowledge graph indexes
CREATE INDEX IF NOT EXISTS idx_relationships_source ON knowledge_relationships(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_relationships_target ON knowledge_relationships(target_type, target_id);

-- Enhanced RAG Functions (Archon-inspired)

-- 1. Match documents with memory context
CREATE OR REPLACE FUNCTION match_documents_with_memory(
    query_text TEXT,
    user_id TEXT,
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title VARCHAR(500),
    content TEXT,
    classification VARCHAR(50),
    confidence FLOAT,
    dcwf_task_ids TEXT[],
    similarity FLOAT,
    evidence_strength VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Get query embedding (would typically be passed from n8n)
    -- For now, return similarity-based results
    RETURN QUERY
    SELECT 
        d.id,
        d.title,
        d.content,
        d.classification,
        d.confidence,
        d.dcwf_task_ids,
        1 - (d.embedding <=> (SELECT embedding FROM dcwf_tasks LIMIT 1)) as similarity,
        d.evidence_strength,
        d.created_at
    FROM documents d
    WHERE d.user_id = match_documents_with_memory.user_id
      AND (1 - (d.embedding <=> (SELECT embedding FROM dcwf_tasks LIMIT 1))) > match_threshold
    ORDER BY similarity DESC
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- 2. Get DCWF task context with relationships
CREATE OR REPLACE FUNCTION get_dcwf_task_context(
    task_id_param VARCHAR(20),
    depth INT DEFAULT 2
)
RETURNS TABLE (
    task_id VARCHAR(20),
    task_name VARCHAR(500),
    task_description TEXT,
    related_tasks JSONB,
    impacted_roles TEXT[],
    ai_implications JSONB,
    relationship_chains JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dt.task_id,
        dt.task_name,
        dt.task_description,
        
        -- Related tasks through relationships
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'target_task', kr.target_id,
                    'relationship', kr.relationship_type,
                    'strength', kr.strength
                )
            )
            FROM knowledge_relationships kr
            WHERE kr.source_id = dt.task_id AND kr.source_type = 'dcwf_task'
            ), '[]'::jsonb
        ) as related_tasks,
        
        -- Work roles (from task definition)
        ARRAY[dt.work_role] as impacted_roles,
        
        -- AI capabilities that affect this task
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'capability', ac.capability_name,
                    'impact_type', ac.impact_type,
                    'confidence', ac.impact_confidence
                )
            )
            FROM ai_capabilities ac
            WHERE dt.task_id = ANY(ac.affected_tasks)
            ), '[]'::jsonb
        ) as ai_implications,
        
        -- Multi-hop relationship chains (simplified)
        '[]'::jsonb as relationship_chains
        
    FROM dcwf_tasks dt
    WHERE dt.task_id = task_id_param;
END;
$$ LANGUAGE plpgsql;

-- 3. Enhanced memory search with context
CREATE OR REPLACE FUNCTION search_memory_with_context(
    query_text TEXT,
    user_id_param TEXT,
    chat_id_param TEXT,
    context_days INT DEFAULT 7,
    limit_count INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    role VARCHAR(20),
    content TEXT,
    message_type VARCHAR(50),
    importance_score FLOAT,
    created_at TIMESTAMP WITH TIME ZONE,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.id,
        cm.role,
        cm.content,
        cm.message_type,
        cm.importance_score,
        cm.created_at,
        0.8 as similarity -- Placeholder for actual embedding similarity
    FROM chat_memory cm
    WHERE cm.user_id = user_id_param
      AND cm.chat_id = chat_id_param
      AND cm.created_at > (NOW() - (context_days || ' days')::INTERVAL)
    ORDER BY cm.created_at DESC, cm.importance_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 4. Update document citations and evidence strength
CREATE OR REPLACE FUNCTION update_document_evidence(
    doc_id UUID,
    citation_increase INT DEFAULT 1
)
RETURNS VOID AS $$
BEGIN
    UPDATE documents 
    SET 
        citation_count = citation_count + citation_increase,
        evidence_strength = CASE 
            WHEN citation_count + citation_increase > 10 THEN 'HIGH'
            WHEN citation_count + citation_increase > 3 THEN 'MEDIUM'
            ELSE 'LOW'
        END,
        updated_at = NOW()
    WHERE id = doc_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Cleanup old memory (Archon pattern)
CREATE OR REPLACE FUNCTION cleanup_old_memory()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete expired low-importance memories
    DELETE FROM chat_memory 
    WHERE expires_at < NOW() 
      AND importance_score < 0.3;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Update expires_at for important memories
    UPDATE chat_memory 
    SET expires_at = NOW() + INTERVAL '90 days'
    WHERE importance_score > 0.8;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Row Level Security (optional but recommended)
-- Enable RLS on sensitive tables
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_memory ENABLE ROW LEVEL SECURITY;

-- Create policies for user isolation
CREATE POLICY documents_user_isolation ON documents
    FOR ALL USING (auth.uid()::text = user_id);

CREATE POLICY chat_memory_user_isolation ON chat_memory
    FOR ALL USING (auth.uid()::text = user_id);

-- Initial setup function
CREATE OR REPLACE FUNCTION setup_enhanced_dcwf_system()
RETURNS TEXT AS $$
BEGIN
    -- Verify extensions
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        RAISE EXCEPTION 'pgvector extension is required but not installed';
    END IF;
    
    -- Create any missing indexes
    -- (indexes already created above)
    
    -- Set up periodic cleanup (requires pg_cron extension)
    -- SELECT cron.schedule('cleanup-old-memory', '0 2 * * *', 'SELECT cleanup_old_memory();');
    
    RETURN 'Enhanced DCWF system setup completed successfully. Tables: dcwf_tasks, documents, chat_memory, knowledge_relationships, ai_capabilities. Functions: match_documents_with_memory, get_dcwf_task_context, search_memory_with_context, update_document_evidence, cleanup_old_memory.';
END;
$$ LANGUAGE plpgsql;

-- Execute setup
SELECT setup_enhanced_dcwf_system(); 