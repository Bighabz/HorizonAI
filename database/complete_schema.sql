-- AI Horizon RAG Agent - Complete Database Schema
-- This schema supports the DCWF (Department of Homeland Security Cybersecurity Workforce Framework) analysis

-- Enable pgvector extension for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- DCWF Specialty Areas table (from the worksheet)
CREATE TABLE IF NOT EXISTS dcwf_specialty_areas (
    id SERIAL PRIMARY KEY,
    specialty_area_code VARCHAR(10) UNIQUE NOT NULL,
    specialty_area_name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- DCWF Work Roles table (from the worksheet)
CREATE TABLE IF NOT EXISTS dcwf_work_roles (
    id SERIAL PRIMARY KEY,
    work_role_id VARCHAR(20) UNIQUE NOT NULL,
    work_role_name VARCHAR(255) NOT NULL,
    specialty_area_code VARCHAR(10) REFERENCES dcwf_specialty_areas(specialty_area_code),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- DCWF Tasks table (from the worksheet)
CREATE TABLE IF NOT EXISTS dcwf_tasks (
    id SERIAL PRIMARY KEY,
    task_id VARCHAR(20) UNIQUE NOT NULL,
    task_description TEXT NOT NULL,
    work_role_id VARCHAR(20) REFERENCES dcwf_work_roles(work_role_id),
    specialty_area_code VARCHAR(10) REFERENCES dcwf_specialty_areas(specialty_area_code),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Documents table for storing processed content with vector embeddings
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    artifact_id VARCHAR(255) UNIQUE NOT NULL,
    title VARCHAR(500),
    summary TEXT,
    content TEXT NOT NULL,
    source_url TEXT,
    source_type VARCHAR(50), -- 'document', 'youtube', 'tiktok', 'url', etc.
    filename VARCHAR(255),
    file_size BIGINT,
    mime_type VARCHAR(100),
    
    -- AI Classification fields
    classification VARCHAR(50) CHECK (classification IN ('Replace', 'Augment', 'Remain Human', 'New Task')),
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    rationale TEXT,
    
    -- DCWF mapping
    dcwf_task_ids TEXT[], -- Array of task IDs
    dcwf_work_roles TEXT[], -- Array of work role IDs
    dcwf_specialty_areas TEXT[], -- Array of specialty area codes
    
    -- Scoring
    credibility_score DECIMAL(3,2) CHECK (credibility_score >= 0 AND credibility_score <= 1),
    impact_score DECIMAL(3,2) CHECK (impact_score >= 0 AND impact_score <= 1),
    specificity_score DECIMAL(3,2) CHECK (specificity_score >= 0 AND specificity_score <= 1),
    
    -- Vector embedding for similarity search
    embedding vector(1536), -- OpenAI ada-002 embedding dimension
    
    -- User and metadata
    user_id VARCHAR(255) NOT NULL,
    chat_id VARCHAR(255),
    username VARCHAR(255),
    processed_by VARCHAR(100) DEFAULT 'n8n-workflow',
    retrieved_on DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat memory table for conversation history
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

-- Analysis results table for tracking AI impact assessments
CREATE TABLE IF NOT EXISTS analysis_results (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    analysis_type VARCHAR(50) DEFAULT 'ai_impact',
    classification VARCHAR(50),
    confidence DECIMAL(3,2),
    rationale TEXT,
    dcwf_tasks_affected TEXT[],
    impact_level VARCHAR(20) CHECK (impact_level IN ('Low', 'Medium', 'High', 'Critical')),
    timeline_estimate VARCHAR(50), -- e.g., "1-2 years", "3-5 years", "5+ years"
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User sessions table for tracking user interactions
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_classification ON documents(classification);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);
CREATE INDEX IF NOT EXISTS idx_documents_dcwf_tasks ON documents USING GIN(dcwf_task_ids);
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_chat_memory_user_chat ON chat_memory(user_id, chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_memory_timestamp ON chat_memory(timestamp);

CREATE INDEX IF NOT EXISTS idx_dcwf_tasks_work_role ON dcwf_tasks(work_role_id);
CREATE INDEX IF NOT EXISTS idx_dcwf_work_roles_specialty ON dcwf_work_roles(specialty_area_code);

-- Create function for vector similarity search
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

-- Insert DCWF Specialty Areas (from the worksheet)
INSERT INTO dcwf_specialty_areas (specialty_area_code, specialty_area_name, description) VALUES
('SP-RSK-001', 'Securely Provision', 'Conceptualizes, designs, procures, and/or builds secure information technology (IT) systems'),
('SP-DEV-001', 'Securely Provision', 'Develops secure code and/or systems'),
('SP-IMP-001', 'Securely Provision', 'Implements security designs for new or existing systems'),
('SP-SYS-001', 'Securely Provision', 'Installs, configures, troubleshoots, and maintains organizational systems'),
('OM-NET-001', 'Operate and Maintain', 'Provides network services, capabilities, and security'),
('OM-DTA-001', 'Operate and Maintain', 'Provides data administration services'),
('OM-STS-001', 'Operate and Maintain', 'Provides systems administration services'),
('PR-CIR-001', 'Protect and Defend', 'Identifies, analyzes, and mitigates threats to internal systems and networks'),
('PR-INF-001', 'Protect and Defend', 'Protects organizational infrastructure from physical and environmental threats'),
('AN-TWA-001', 'Analyze', 'Analyzes collected information to identify vulnerabilities and potential for exploitation'),
('AN-TGT-001', 'Analyze', 'Applies current knowledge of one or more regions, countries, non-state entities, and/or technologies'),
('CO-CLO-001', 'Collect and Operate', 'Provides specialized denial and deception operations and collection of cybersecurity information'),
('IN-FOR-001', 'Investigate', 'Conducts deep-dive investigations on computer-based crimes establishing documentary or physical evidence')
ON CONFLICT (specialty_area_code) DO NOTHING;

-- Insert sample DCWF Work Roles (key ones from the worksheet)
INSERT INTO dcwf_work_roles (work_role_id, work_role_name, specialty_area_code, description) VALUES
('PR-CIR-001', 'Cyber Defense Analyst', 'PR-CIR-001', 'Uses data collected from a variety of cyber defense tools to analyze events within the enterprise'),
('AN-TWA-001', 'Threat/Warning Analyst', 'AN-TWA-001', 'Develops cyber threat assessments for decision makers'),
('PR-INF-001', 'Cyber Defense Infrastructure Support Specialist', 'PR-INF-001', 'Tests, implements, deploys, maintains, and administers infrastructure hardware and software'),
('OM-NET-001', 'Network Operations Specialist', 'OM-NET-001', 'Plans, implements, and operates network services/systems'),
('SP-DEV-001', 'Software Developer', 'SP-DEV-001', 'Develops, creates, maintains, and writes/codes new or modified software programs'),
('AN-TGT-001', 'All-Source Analyst', 'AN-TGT-001', 'Analyzes data/information from one or multiple sources to conduct preparation of the environment'),
('IN-FOR-001', 'Cyber Crime Investigator', 'IN-FOR-001', 'Identifies, collects, examines, and preserves evidence using controlled and documented analytical and investigative techniques')
ON CONFLICT (work_role_id) DO NOTHING;

-- Insert sample DCWF Tasks (key ones from the worksheet)
INSERT INTO dcwf_tasks (task_id, task_description, work_role_id, specialty_area_code) VALUES
('T0023', 'Characterize and analyze network traffic to identify anomalous activity and potential threats to network resources', 'PR-CIR-001', 'PR-CIR-001'),
('T0166', 'Perform event correlation using information gathered from a variety of sources within the enterprise to gain situational awareness and determine the effectiveness of an observed attack', 'PR-CIR-001', 'PR-CIR-001'),
('T0214', 'Receive and analyze network alerts from various sources within the enterprise and determine possible causes of such alerts', 'PR-CIR-001', 'PR-CIR-001'),
('T0503', 'Monitor and evaluate cybersecurity alerts and advisories from internal and external sources', 'AN-TWA-001', 'AN-TWA-001'),
('T0582', 'Provide technical documents, incident reports, findings from computer examinations, summaries, and other situational awareness information', 'AN-TWA-001', 'AN-TWA-001'),
('T0180', 'Perform network traffic analysis to identify vulnerabilities', 'OM-NET-001', 'OM-NET-001'),
('T0121', 'Implement security designs for new or existing system(s)', 'SP-DEV-001', 'SP-DEV-001'),
('T0176', 'Perform secure program code reviews', 'SP-DEV-001', 'SP-DEV-001'),
('T0240', 'Capture and analyze network traffic associated with malicious activities using packet analyzers', 'IN-FOR-001', 'IN-FOR-001'),
('T0432', 'Collect and analyze intrusion artifacts and use discovered data to enable mitigation of potential cyber defense incidents within the enterprise', 'IN-FOR-001', 'IN-FOR-001')
ON CONFLICT (task_id) DO NOTHING;

-- Create a view for easy DCWF lookup
CREATE OR REPLACE VIEW dcwf_full_mapping AS
SELECT 
    t.task_id,
    t.task_description,
    wr.work_role_id,
    wr.work_role_name,
    sa.specialty_area_code,
    sa.specialty_area_name
FROM dcwf_tasks t
JOIN dcwf_work_roles wr ON t.work_role_id = wr.work_role_id
JOIN dcwf_specialty_areas sa ON t.specialty_area_code = sa.specialty_area_code;

-- Function to get recent chat history for a user
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
    avg_confidence decimal
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
        AVG(d.confidence) as avg_confidence
    FROM documents d
    FULL OUTER JOIN chat_memory cm ON d.user_id = cm.user_id
    WHERE d.user_id = p_user_id OR cm.user_id = p_user_id;
END;
$$;

-- Grant permissions (adjust as needed for your setup)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_n8n_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_n8n_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO your_n8n_user;

-- Example queries for testing:
-- SELECT * FROM match_documents('[0.1,0.2,...]'::vector, 0.7, 5, 'user123');
-- SELECT * FROM get_chat_history('user123', 'chat456', 10);
-- SELECT * FROM get_user_stats('user123');
-- SELECT * FROM dcwf_full_mapping WHERE task_id LIKE 'T0%';