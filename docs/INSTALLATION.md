# 🚀 AI Horizon RAG Agent - Installation Guide

## 📋 Prerequisites

Before starting, ensure you have:

- **Supabase Account**: [Create free account](https://supabase.com)
- **OpenAI API Key**: [Get API key](https://platform.openai.com/api-keys)
- **Dumpling AI Account**: [Sign up](https://app.dumplingai.com)
- **Telegram Bot**: Created via [@BotFather](https://t.me/botfather)
- **n8n Instance**: Self-hosted or cloud (Railway, DigitalOcean, etc.)

## 🎯 Quick Setup (30 minutes)

### Step 1: Clone Repository

```bash
git clone <your-repository-url>
cd ai-horizon-rag-agent
```

### Step 2: Environment Configuration

1. **Copy environment template:**
```bash
cp .env.example .env
```

2. **Edit `.env` with your credentials:**
```bash
# Supabase (from your project settings)
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key

# OpenAI (from platform.openai.com)
OPENAI_API_KEY=sk-your-openai-key

# Dumpling AI (from app.dumplingai.com)
DUMPLING_API_KEY=sk_your-dumpling-key
DUMPLING_API_URL=https://app.dumplingai.com/api/v1

# Telegram (from @BotFather)
TELEGRAM_BOT_TOKEN=your-bot-token
```

### Step 3: Database Setup

#### Option A: Automated Setup (Recommended)
```bash
# Install dependencies
pip install -r requirements.txt

# Run setup script
python scripts/setup_database.py
```

#### Option B: Manual Setup
1. **Go to Supabase Dashboard** → Your Project → SQL Editor
2. **Execute in order:**
   - `database/schema.sql`
   - `database/vector_functions.sql`
   - Load DCWF data from `data/DCWF_Clean.csv`

### Step 4: n8n Workflow Import

1. **Open your n8n instance**
2. **Import workflow:**
   - Go to Workflows → Import from File
   - Select `n8n/workflow_fixed.json`
3. **Configure credentials:**
   - OpenAI API
   - Supabase API
   - Telegram Bot API
   - Dumpling AI API

### Step 5: Test System

```bash
# Run health check
python scripts/health_check.py

# Test with sample data
python scripts/test_workflow.py
```

## 🔧 Detailed Installation

### Supabase Setup

#### 1. Create New Project
- Go to [Supabase Dashboard](https://supabase.com/dashboard)
- Click "New Project"
- Choose organization and region
- Set database password (save it!)

#### 2. Enable pgvector Extension
```sql
-- In SQL Editor, run:
CREATE EXTENSION IF NOT EXISTS vector;
```

#### 3. Get API Keys
- Go to Settings → API
- Copy `URL`, `anon key`, and `service_role key`

#### 4. Configure RLS (Row Level Security)
The schema includes RLS policies, but verify:
- Go to Authentication → Policies
- Ensure policies exist for `documents` and `chat_memory` tables

### OpenAI Setup

#### 1. Get API Key
- Visit [OpenAI Platform](https://platform.openai.com/api-keys)
- Create new secret key
- Copy and save securely

#### 2. Verify Models
Ensure you have access to:
- `gpt-4o-mini` (for chat)
- `text-embedding-ada-002` (for embeddings)

#### 3. Set Usage Limits
- Go to Billing → Usage limits
- Set appropriate monthly limits

### Dumpling AI Setup

#### 1. Create Account
- Sign up at [Dumpling AI](https://app.dumplingai.com)
- Verify email and complete onboarding

#### 2. Get API Key
- Go to Settings → API Keys
- Generate new key
- Note the API URL: `https://app.dumplingai.com/api/v1`

#### 3. Check Credits
- Ensure you have sufficient credits for document processing
- Each document costs ~1-5 credits depending on size

### Telegram Bot Setup

#### 1. Create Bot
```
1. Message @BotFather on Telegram
2. Send /newbot
3. Choose bot name and username
4. Save the bot token
```

#### 2. Configure Bot
```
# Set bot description
/setdescription - AI assistant for cybersecurity workforce analysis

# Set bot commands
/setcommands
start - Start conversation
help - Get help
stats - View document statistics
export - Export your data
```

#### 3. Get Chat ID (for testing)
```bash
# Send message to your bot, then:
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```

### n8n Configuration

#### 1. Install n8n (if needed)
```bash
# Via npm
npm install n8n -g

# Via Docker
docker run -it --rm --name n8n -p 5678:5678 n8nio/n8n

# Via Docker Compose (recommended for production)
```

#### 2. Configure Environment Variables
Set in n8n instance:
```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_SERVICE_KEY": "your-service-key",
  "OPENAI_API_KEY": "sk-your-openai-key",
  "DUMPLING_API_KEY": "sk_your-dumpling-key"
}
```

#### 3. Create Credentials
In n8n interface:

**OpenAI API:**
- Credential Type: OpenAI API
- API Key: Your OpenAI key

**Supabase API:**
- Credential Type: Supabase API
- Host: your-project.supabase.co
- Service Role Key: Your service key

**Telegram Bot API:**
- Credential Type: Telegram Bot API
- Access Token: Your bot token

**Dumpling AI API:**
- Credential Type: HTTP Request Auth
- Auth Type: Bearer Token
- Token: Your Dumpling API key

#### 4. Import and Activate Workflow
1. Import `n8n/workflow_fixed.json`
2. Update all credential references
3. Test webhook URL
4. Activate workflow

## 🧪 Testing & Verification

### Health Check
```bash
python scripts/health_check.py
```

Expected output:
```
✅ Environment Variables: All required variables present
✅ Supabase Connection: Database accessible
✅ Table: documents: Exists (X rows)
✅ Table: chat_memory: Exists (X rows)
✅ Vector Search Function: match_documents function working
✅ OpenAI API: Connected (X models available)
✅ Dumpling AI API: API accessible
✅ Embedding Generation: Generated 1536-dimensional embedding
```

### Manual Testing

#### 1. Test Telegram Bot
```
1. Send message to your bot: "Hello"
2. Expected response: AI greeting message
3. Upload a PDF document
4. Expected: Processing confirmation + classification
```

#### 2. Test Vector Search
```bash
# In Supabase SQL Editor:
SELECT * FROM match_documents(
  ARRAY[0.1, 0.2, 0.3, ...]::vector(1536),
  0.7,
  5,
  'test_user'
);
```

#### 3. Test Document Processing
```bash
python scripts/test_workflow.py
```

## 🚨 Troubleshooting

### Common Issues

#### 1. "pgvector extension not found"
```sql
-- In Supabase SQL Editor:
CREATE EXTENSION IF NOT EXISTS vector;
```

#### 2. "Function match_documents does not exist"
- Run `database/vector_functions.sql` in Supabase SQL Editor
- Verify function exists: `\df match_documents` in SQL Editor

#### 3. "OpenAI API 401 Unauthorized"
- Verify API key is correct and active
- Check billing and usage limits
- Ensure key has proper permissions

#### 4. "Telegram webhook not receiving messages"
- Verify webhook URL is accessible
- Check n8n workflow is active
- Test webhook endpoint manually

#### 5. "Dumpling AI processing fails"
- Check API credits balance
- Verify file size limits (30MB max)
- Ensure proper file format (PDF, DOCX)

### Debug Mode

Enable debug logging:
```bash
export DEBUG=true
export LOG_LEVEL=debug
python scripts/health_check.py
```

### Log Analysis

Check n8n execution logs:
1. Go to Executions tab
2. Click on failed execution
3. Review each node's input/output
4. Check error messages

## 🔄 Production Deployment

### Environment Setup

#### 1. Use Production Database
- Upgrade Supabase to paid plan if needed
- Enable database backups
- Set up monitoring

#### 2. Secure API Keys
- Use environment variables, not hardcoded keys
- Rotate keys regularly
- Implement rate limiting

#### 3. Scale n8n
```yaml
# docker-compose.yml for production
version: '3.8'
services:
  n8n:
    image: n8nio/n8n
    restart: always
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=secure_password
      - WEBHOOK_URL=https://your-domain.com
    volumes:
      - n8n_data:/home/node/.n8n
    ports:
      - "5678:5678"
```

#### 4. Set Up Monitoring
- Configure health check endpoints
- Set up alerting for failures
- Monitor API usage and costs

### Backup Strategy

#### 1. Database Backups
- Enable Supabase automatic backups
- Export DCWF reference data regularly

#### 2. Workflow Backups
- Export n8n workflows regularly
- Version control workflow files

#### 3. Configuration Backups
- Backup environment variables
- Document credential setup

## 📊 Performance Optimization

### Database Optimization
```sql
-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS documents_embedding_idx 
ON documents USING ivfflat (embedding vector_cosine_ops);

-- Optimize vector search
SET ivfflat.probes = 10;
```

### n8n Optimization
- Enable workflow caching
- Optimize node execution order
- Use webhook mode for better performance

### API Rate Limiting
- Implement exponential backoff
- Cache frequent queries
- Use batch processing where possible

## 🆘 Support

### Getting Help

1. **Check Documentation**
   - Review this installation guide
   - Check API documentation in `/docs`
   - Review troubleshooting section

2. **Run Diagnostics**
   ```bash
   python scripts/health_check.py
   python scripts/test_workflow.py
   ```

3. **Community Support**
   - Create GitHub issue with:
     - Error messages
     - Health check results
     - Steps to reproduce

4. **Professional Support**
   - Contact for enterprise support
   - Custom implementation services
   - Training and consultation

---

**🎉 Congratulations!** Your AI Horizon RAG Agent is now ready to analyze cybersecurity workforce transformation!