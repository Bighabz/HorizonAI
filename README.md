# AI Horizon RAG Agent for n8n

An advanced RAG (Retrieval-Augmented Generation) agent built with n8n for analyzing AI's impact on cybersecurity workforce using the DCWF framework.

## 🚀 Features

- **Telegram Bot Integration** - Interactive bot (@research_bot) for document processing and queries
- **Document Processing** - Supports PDFs, Word docs, YouTube videos via Dumpling AI
- **Vector Search** - Semantic search using Supabase with pgvector extension
- **AI Classification** - Categorizes content as Replace/Augment/Remain Human/New Task
- **DCWF Mapping** - Maps findings to 900+ DCWF cybersecurity tasks
- **Chat Memory** - Maintains conversation context for better responses
- **Weekly Reports** - Automated analysis summaries

## 📁 Repository Structure

```
.
├── ai_horizon_complete_workflow.json  # Complete n8n workflow (import this!)
├── supabase_reset_schema.sql         # Database schema with pgvector
├── supabase_schema_complete.sql      # Alternative schema setup
├── My_workflow_26.json               # Original workflow reference
├── DCWF_Clean.csv                    # DCWF task data (CSV format)
├── DCWF_Clean.xlsx                   # DCWF task data (Excel format)
├── Horizon_Pipeline                  # Pipeline requirements document
├── requirements.txt                  # Python dependencies
└── README.md                         # This file
```

## 🛠️ Setup Instructions

### 1. Database Setup (Supabase)

Run the schema setup in your Supabase SQL editor:
```sql
-- Use supabase_reset_schema.sql to drop old tables and create new ones
-- This includes pgvector extension and all required functions
```

### 2. Import n8n Workflow

1. Go to your n8n instance (e.g., https://n8n.waxmybot.com)
2. Click **"+"** → **"..."** → **"Import from file"**
3. Upload `ai_horizon_complete_workflow.json`

### 3. Configure Credentials in n8n

Create these credentials in n8n:

#### Telegram Bot API
- Name: `Telegram Bot API`
- Access Token: `[Your Bot Token]`

#### OpenAI API
- Name: `OpenAI API`
- API Key: `[Your OpenAI Key]`

#### Dumpling AI API
- Name: `Dumpling AI API`
- API Key: `[Your Dumpling Key]`

#### Supabase API
- Name: `Supabase API`
- URL: `[Your Supabase URL]`
- Service Key: `[Your Service Key]`

### 4. Activate Workflow

1. Open the imported workflow
2. Click **"Activate"** toggle
3. Test with Telegram bot

## 💬 Usage

### Document Processing
- Send PDF/Word documents to the Telegram bot
- Send YouTube video links for transcript analysis
- Documents are classified and stored with vector embeddings

### RAG Queries
- Ask questions about AI's impact on cybersecurity
- Get DCWF task mappings
- Receive evidence-based analysis with confidence scores

### Commands
- `/stats` - View your usage statistics
- `/export` - Export analysis results

## 🔧 Technical Details

- **Vector Similarity**: Uses cosine distance < 0.3 for relevance
- **Embeddings**: OpenAI text-embedding-ada-002
- **LLM**: GPT-4o-mini for classification and responses
- **Context Window**: Last 5 chat messages + top 3 relevant documents

## 📊 DCWF Classification System

Content is classified into:
- **Replace**: AI will fully automate this task
- **Augment**: AI will support but not fully automate
- **Remain Human**: Task remains primarily human-driven
- **New Task**: Emerging duties created by AI advances

Each classification includes:
- Credibility score (0-1)
- Impact score (0-1)
- Specificity score (0-1)
- Confidence level
- DCWF task mappings

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

This project is part of the AI Horizon Forecasting initiative for cybersecurity workforce analysis.