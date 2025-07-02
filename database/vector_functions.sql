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