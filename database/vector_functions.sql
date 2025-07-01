-- AI Horizon RAG Agent - Vector Search Functions
-- Execute this in Supabase SQL Editor after creating the schema

-- ================================
-- MAIN VECTOR SIMILARITY SEARCH FUNCTION
-- ================================
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10,
  user_id text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  content text,
  classification text,
  filename text,
  category text,
  tags text[],
  similarity float
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
    d.filename,
    d.category,
    d.tags,
    1 - (d.embedding <=> query_embedding) as similarity
  FROM documents d
  WHERE 
    d.embedding IS NOT NULL
    AND (user_id IS NULL OR d.user_id = user_id)
    AND 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ================================
-- ENHANCED SEARCH WITH FILTERS
-- ================================
CREATE OR REPLACE FUNCTION search_documents_advanced(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10,
  user_id text DEFAULT NULL,
  source_types text[] DEFAULT NULL,
  classifications text[] DEFAULT NULL,
  categories text[] DEFAULT NULL,
  date_from timestamp DEFAULT NULL,
  date_to timestamp DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  content text,
  classification text,
  filename text,
  category text,
  tags text[],
  source_type text,
  created_at timestamp,
  similarity float,
  confidence float
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
    d.filename,
    d.category,
    d.tags,
    d.source_type,
    d.created_at,
    1 - (d.embedding <=> query_embedding) as similarity,
    d.confidence
  FROM documents d
  WHERE 
    d.embedding IS NOT NULL
    AND (user_id IS NULL OR d.user_id = user_id)
    AND 1 - (d.embedding <=> query_embedding) > match_threshold
    AND (source_types IS NULL OR d.source_type = ANY(source_types))
    AND (classifications IS NULL OR d.classification = ANY(classifications))
    AND (categories IS NULL OR d.category = ANY(categories))
    AND (date_from IS NULL OR d.created_at >= date_from)
    AND (date_to IS NULL OR d.created_at <= date_to)
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ================================
-- HYBRID SEARCH (VECTOR + TEXT)
-- ================================
CREATE OR REPLACE FUNCTION hybrid_search_documents(
  query_embedding vector(1536),
  query_text text,
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10,
  user_id text DEFAULT NULL,
  vector_weight float DEFAULT 0.7,
  text_weight float DEFAULT 0.3
)
RETURNS TABLE (
  id uuid,
  title text,
  content text,
  classification text,
  filename text,
  category text,
  tags text[],
  similarity float,
  text_rank float,
  combined_score float
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
    d.filename,
    d.category,
    d.tags,
    1 - (d.embedding <=> query_embedding) as similarity,
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) as text_rank,
    (vector_weight * (1 - (d.embedding <=> query_embedding))) + 
    (text_weight * ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text))) as combined_score
  FROM documents d
  WHERE 
    d.embedding IS NOT NULL
    AND (user_id IS NULL OR d.user_id = user_id)
    AND (
      1 - (d.embedding <=> query_embedding) > match_threshold
      OR to_tsvector('english', d.content) @@ plainto_tsquery('english', query_text)
    )
  ORDER BY combined_score DESC
  LIMIT match_count;
END;
$$;

-- ================================
-- FIND SIMILAR DOCUMENTS
-- ================================
CREATE OR REPLACE FUNCTION find_similar_documents(
  document_id uuid,
  match_threshold float DEFAULT 0.8,
  match_count int DEFAULT 5,
  user_id text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  classification text,
  filename text,
  category text,
  similarity float
)
LANGUAGE plpgsql
AS $$
DECLARE
  source_embedding vector(1536);
BEGIN
  -- Get the embedding of the source document
  SELECT embedding INTO source_embedding 
  FROM documents 
  WHERE documents.id = document_id;
  
  IF source_embedding IS NULL THEN
    RAISE EXCEPTION 'Document not found or has no embedding';
  END IF;
  
  RETURN QUERY
  SELECT 
    d.id,
    d.title,
    d.classification,
    d.filename,
    d.category,
    1 - (d.embedding <=> source_embedding) as similarity
  FROM documents d
  WHERE 
    d.id != document_id
    AND d.embedding IS NOT NULL
    AND (user_id IS NULL OR d.user_id = user_id)
    AND 1 - (d.embedding <=> source_embedding) > match_threshold
  ORDER BY d.embedding <=> source_embedding
  LIMIT match_count;
END;
$$;

-- ================================
-- SEARCH BY DCWF TASKS
-- ================================
CREATE OR REPLACE FUNCTION search_by_dcwf_tasks(
  task_ids text[],
  user_id text DEFAULT NULL,
  match_count int DEFAULT 10
)
RETURNS TABLE (
  id uuid,
  title text,
  content text,
  classification text,
  filename text,
  dcwf_task_ids text[],
  work_roles text[],
  confidence float
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
    d.filename,
    d.dcwf_task_ids,
    d.work_roles,
    d.confidence
  FROM documents d
  WHERE 
    (user_id IS NULL OR d.user_id = user_id)
    AND d.dcwf_task_ids && task_ids -- Array overlap operator
  ORDER BY d.confidence DESC, d.created_at DESC
  LIMIT match_count;
END;
$$;

-- ================================
-- ANALYTICS FUNCTIONS
-- ================================

-- Get classification statistics
CREATE OR REPLACE FUNCTION get_classification_stats(
  user_id text DEFAULT NULL,
  date_from timestamp DEFAULT NULL,
  date_to timestamp DEFAULT NULL
)
RETURNS TABLE (
  classification text,
  count bigint,
  avg_confidence float,
  avg_impact_score float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.classification,
    COUNT(*) as count,
    AVG(d.confidence) as avg_confidence,
    AVG(d.impact_score) as avg_impact_score
  FROM documents d
  WHERE 
    (user_id IS NULL OR d.user_id = user_id)
    AND (date_from IS NULL OR d.created_at >= date_from)
    AND (date_to IS NULL OR d.created_at <= date_to)
  GROUP BY d.classification
  ORDER BY count DESC;
END;
$$;

-- Get document processing statistics
CREATE OR REPLACE FUNCTION get_processing_stats(
  user_id text DEFAULT NULL,
  days_back int DEFAULT 30
)
RETURNS TABLE (
  source_type text,
  total_documents bigint,
  avg_processing_time interval,
  success_rate float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.source_type,
    COUNT(*) as total_documents,
    AVG(d.created_at - l.processed_at) as avg_processing_time,
    (COUNT(CASE WHEN l.status = 'completed' THEN 1 END)::float / COUNT(*)::float) as success_rate
  FROM documents d
  LEFT JOIN document_processing_log l ON d.filename = l.filename
  WHERE 
    (user_id IS NULL OR d.user_id = user_id)
    AND d.created_at >= NOW() - INTERVAL '%s days' % days_back
  GROUP BY d.source_type
  ORDER BY total_documents DESC;
END;
$$;

-- ================================
-- UTILITY FUNCTIONS
-- ================================

-- Check if embedding exists for document
CREATE OR REPLACE FUNCTION has_embedding(document_id uuid)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  embedding_exists boolean;
BEGIN
  SELECT (embedding IS NOT NULL) INTO embedding_exists
  FROM documents 
  WHERE id = document_id;
  
  RETURN COALESCE(embedding_exists, false);
END;
$$;

-- Get embedding dimensions
CREATE OR REPLACE FUNCTION get_embedding_dimensions()
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  dims int;
BEGIN
  SELECT array_length(embedding, 1) INTO dims
  FROM documents 
  WHERE embedding IS NOT NULL 
  LIMIT 1;
  
  RETURN COALESCE(dims, 0);
END;
$$;

-- Clean up old chat history
CREATE OR REPLACE FUNCTION cleanup_old_chat_history(
  days_to_keep int DEFAULT 30,
  user_id text DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  deleted_count int;
BEGIN
  DELETE FROM chat_memory
  WHERE 
    created_at < NOW() - INTERVAL '%s days' % days_to_keep
    AND (user_id IS NULL OR chat_memory.user_id = user_id);
    
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- ================================
-- COMMENTS FOR DOCUMENTATION
-- ================================

COMMENT ON FUNCTION match_documents IS 'Main vector similarity search function for RAG queries';
COMMENT ON FUNCTION search_documents_advanced IS 'Advanced search with multiple filters and metadata';
COMMENT ON FUNCTION hybrid_search_documents IS 'Combines vector similarity with full-text search';
COMMENT ON FUNCTION find_similar_documents IS 'Find documents similar to a given document';
COMMENT ON FUNCTION search_by_dcwf_tasks IS 'Search documents by DCWF task IDs';
COMMENT ON FUNCTION get_classification_stats IS 'Get statistics about AI impact classifications';
COMMENT ON FUNCTION cleanup_old_chat_history IS 'Remove old chat messages to manage storage';