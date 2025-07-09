-- Supabase RPC Function for Vector Similarity Search
-- This function is required for the enhanced workflow's vector search capability

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS match_documents_with_memory;

-- Create the vector similarity search function
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
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
  query_embedding vector(1536);
BEGIN
  -- Generate embedding for the query text
  -- Note: In production, you'd generate this embedding via OpenAI API
  -- For now, we'll use a simplified approach
  
  -- Get embeddings from similar content (simplified approach)
  -- In production, you would call OpenAI API to get the actual embedding
  SELECT embedding INTO query_embedding
  FROM documents
  WHERE user_id = match_documents_with_memory.user_id
    AND content ILIKE '%' || query_text || '%'
  LIMIT 1;
  
  -- If no exact match found, do a broader search
  IF query_embedding IS NULL THEN
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
      -- Text similarity score (simplified)
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
    ORDER BY similarity DESC, d.created_at DESC
    LIMIT match_count;
  ELSE
    -- Vector similarity search
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
      1 - (d.embedding <=> query_embedding) AS similarity
    FROM documents d
    WHERE d.user_id = match_documents_with_memory.user_id
      AND d.embedding IS NOT NULL
      AND 1 - (d.embedding <=> query_embedding) > match_threshold
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION match_documents_with_memory TO anon;
GRANT EXECUTE ON FUNCTION match_documents_with_memory TO authenticated;

-- Alternative simpler function if the above doesn't work
CREATE OR REPLACE FUNCTION simple_document_search(
  search_text TEXT,
  search_user_id TEXT,
  result_limit INT DEFAULT 10
)
RETURNS SETOF documents
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM documents
  WHERE user_id = search_user_id
    AND (
      content ILIKE '%' || search_text || '%'
      OR summary ILIKE '%' || search_text || '%'
      OR title ILIKE '%' || search_text || '%'
    )
  ORDER BY created_at DESC
  LIMIT result_limit;
END;
$$;

-- Grant permissions for simple search
GRANT EXECUTE ON FUNCTION simple_document_search TO anon;
GRANT EXECUTE ON FUNCTION simple_document_search TO authenticated;

-- Index for better text search performance
CREATE INDEX IF NOT EXISTS idx_documents_content_text ON documents USING GIN (to_tsvector('english', content));
CREATE INDEX IF NOT EXISTS idx_documents_summary_text ON documents USING GIN (to_tsvector('english', summary));
CREATE INDEX IF NOT EXISTS idx_documents_title_text ON documents USING GIN (to_tsvector('english', title)); 