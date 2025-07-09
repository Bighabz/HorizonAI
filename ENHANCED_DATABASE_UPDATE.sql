-- Enhanced Database Updates for Advanced Retrieval
-- Run these updates on your existing Supabase database

-- Add upload tracking fields to documents table
ALTER TABLE documents 
ADD COLUMN IF NOT EXISTS upload_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS upload_order BIGINT DEFAULT extract(epoch from CURRENT_TIMESTAMP) * 1000;

-- Create index for efficient last document queries
CREATE INDEX IF NOT EXISTS idx_documents_upload_order ON documents(user_id, upload_order DESC);
CREATE INDEX IF NOT EXISTS idx_documents_upload_timestamp ON documents(user_id, upload_timestamp DESC);

-- Add message_type to chat_memory if not exists
ALTER TABLE chat_memory
ADD COLUMN IF NOT EXISTS message_type VARCHAR(50) DEFAULT 'general';

-- Create index for message type queries
CREATE INDEX IF NOT EXISTS idx_chat_memory_message_type ON chat_memory(user_id, message_type);

-- Update the vector search function to include new fields
DROP FUNCTION IF EXISTS match_documents_with_memory;

CREATE OR REPLACE FUNCTION match_documents_with_memory(
  query_text TEXT,
  user_id TEXT,
  match_threshold FLOAT DEFAULT 0.7,
  match_count INT DEFAULT 10
)
RETURNS TABLE (
  artifact_id TEXT,
  title TEXT,
  summary TEXT,
  content TEXT,
  source_url TEXT,
  source_type TEXT,
  filename TEXT,
  classification TEXT,
  confidence FLOAT,
  rationale TEXT,
  impact_score FLOAT,
  dcwf_task_ids TEXT[],
  work_roles TEXT[],
  category TEXT,
  tags TEXT[],
  evidence_strength TEXT,
  upload_timestamp TIMESTAMP WITH TIME ZONE,
  upload_order BIGINT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
  query_embedding vector(1536);
BEGIN
  -- For now, use text similarity (in production, generate embedding via API)
  -- Check for exact matches first
  IF EXISTS (
    SELECT 1 FROM documents d
    WHERE d.user_id = match_documents_with_memory.user_id
    AND d.content ILIKE '%' || query_text || '%'
    LIMIT 1
  ) THEN
    -- Return text-based similarity results
    RETURN QUERY
    SELECT 
      d.artifact_id,
      d.title,
      d.summary,
      d.content,
      d.source_url,
      d.source_type,
      d.filename,
      d.classification,
      d.confidence,
      d.rationale,
      d.impact_score,
      d.dcwf_task_ids,
      d.work_roles,
      d.category,
      d.tags,
      d.evidence_strength,
      d.upload_timestamp,
      d.upload_order,
      -- Text similarity score
      CASE 
        WHEN d.content ILIKE '%' || query_text || '%' THEN 0.9
        WHEN d.summary ILIKE '%' || query_text || '%' THEN 0.8
        WHEN d.title ILIKE '%' || query_text || '%' THEN 0.7
        ELSE 0.5
      END AS similarity
    FROM documents d
    WHERE d.user_id = match_documents_with_memory.user_id
      AND (
        d.content ILIKE '%' || query_text || '%'
        OR d.summary ILIKE '%' || query_text || '%'
        OR d.title ILIKE '%' || query_text || '%'
      )
    ORDER BY similarity DESC, d.upload_timestamp DESC
    LIMIT match_count;
  ELSE
    -- If no text matches, return recent documents
    RETURN QUERY
    SELECT 
      d.artifact_id,
      d.title,
      d.summary,
      d.content,
      d.source_url,
      d.source_type,
      d.filename,
      d.classification,
      d.confidence,
      d.rationale,
      d.impact_score,
      d.dcwf_task_ids,
      d.work_roles,
      d.category,
      d.tags,
      d.evidence_strength,
      d.upload_timestamp,
      d.upload_order,
      0.5 AS similarity
    FROM documents d
    WHERE d.user_id = match_documents_with_memory.user_id
    ORDER BY d.upload_timestamp DESC
    LIMIT match_count;
  END IF;
END;
$$;

-- Create specialized function for evidence queries
CREATE OR REPLACE FUNCTION get_documents_by_classification(
  search_user_id TEXT,
  search_classification TEXT,
  min_confidence FLOAT DEFAULT 0.0,
  result_limit INT DEFAULT 20
)
RETURNS SETOF documents
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM documents
  WHERE user_id = search_user_id
    AND classification = search_classification
    AND confidence >= min_confidence
  ORDER BY confidence DESC, upload_timestamp DESC
  LIMIT result_limit;
END;
$$;

-- Create function to get last uploaded document
CREATE OR REPLACE FUNCTION get_last_uploaded_document(
  search_user_id TEXT
)
RETURNS SETOF documents
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM documents
  WHERE user_id = search_user_id
  ORDER BY upload_timestamp DESC, upload_order DESC
  LIMIT 1;
END;
$$;

-- Create function to search by DCWF tasks
CREATE OR REPLACE FUNCTION get_documents_by_dcwf_tasks(
  search_user_id TEXT,
  task_ids TEXT[],
  result_limit INT DEFAULT 15
)
RETURNS SETOF documents
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT *
  FROM documents
  WHERE user_id = search_user_id
    AND dcwf_task_ids && task_ids  -- Array overlap operator
  ORDER BY confidence DESC, upload_timestamp DESC
  LIMIT result_limit;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_documents_by_classification TO anon;
GRANT EXECUTE ON FUNCTION get_documents_by_classification TO authenticated;
GRANT EXECUTE ON FUNCTION get_last_uploaded_document TO anon;
GRANT EXECUTE ON FUNCTION get_last_uploaded_document TO authenticated;
GRANT EXECUTE ON FUNCTION get_documents_by_dcwf_tasks TO anon;
GRANT EXECUTE ON FUNCTION get_documents_by_dcwf_tasks TO authenticated;

-- Create composite indexes for better performance
CREATE INDEX IF NOT EXISTS idx_documents_classification_confidence 
ON documents(user_id, classification, confidence DESC);

CREATE INDEX IF NOT EXISTS idx_documents_dcwf_tasks 
ON documents USING GIN(dcwf_task_ids);

-- Update existing documents with upload tracking (one-time migration)
UPDATE documents 
SET upload_order = extract(epoch from created_at) * 1000,
    upload_timestamp = created_at
WHERE upload_order IS NULL; 