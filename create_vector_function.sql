-- Create the match_documents function for vector similarity search
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  user_id text,
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id uuid,
  artifact_id text,
  title text,
  summary text,
  content text,
  classification text,
  confidence float,
  dcwf_task_ids text[],
  distance float
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
    (d.embedding <=> query_embedding) as distance
  FROM documents d
  WHERE d.user_id = match_documents.user_id
    AND (d.embedding <=> query_embedding) < match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;