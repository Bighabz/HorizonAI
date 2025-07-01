# 🚀 AI Horizon RAG Agent - Complete Project

## 📋 Project Overview

The AI Horizon RAG Agent is a conversational AI system built with n8n that analyzes how artificial intelligence impacts cybersecurity tasks and roles. It processes documents, videos, and web content to classify AI impact and provides intelligent responses using vector search and retrieval-augmented generation (RAG).

## 🎯 Key Features

- **📄 Document Processing**: PDF, DOCX, CSV files via Dumpling AI
- **🎥 Video Processing**: YouTube and TikTok transcript extraction
- **🔍 Vector Search**: Semantic similarity search using pgvector
- **🤖 AI Classification**: Categorizes content as Replace/Augment/Remain Human/New Task
- **💬 Conversational Interface**: Telegram bot with chat history
- **📊 DCWF Mapping**: Links findings to cybersecurity workforce framework tasks
- **📈 Analytics**: Export and statistics functionality

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Telegram Bot  │────│   n8n Workflow   │────│   Supabase DB   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                         │
                              │                   ┌─────────────────┐
                              │                   │   pgvector      │
                              │                   │   Extension     │
                              │                   └─────────────────┘
                       ┌──────────────────┐
                       │  External APIs   │
                       │  - OpenAI        │
                       │  - Dumpling AI   │
                       └──────────────────┘
```

## 📁 Project Structure

```
ai-horizon-rag-agent/
├── 📄 README.md                          # This file
├── 📄 .env.example                       # Environment variables template
├── 📄 requirements.txt                   # Python dependencies
├── 📄 package.json                       # Node.js dependencies (if needed)
├── 
├── 🗂️ n8n/
│   ├── 📄 My_workflow_26.json           # Main n8n workflow
│   ├── 📄 workflow_fixed.json           # Fixed version with RAG improvements
│   └── 📄 node_configurations.json      # Individual node configs
├── 
├── 🗂️ database/
│   ├── 📄 schema.sql                    # Database schema
│   ├── 📄 seed_data.sql                 # Initial data and functions
│   ├── 📄 vector_functions.sql          # Vector search functions
│   └── 📄 dcwf_data.sql                 # DCWF reference data
├── 
├── 🗂️ data/
│   ├── 📄 DCWF_Clean.csv               # Cybersecurity workforce framework data
│   └── 📄 sample_documents/             # Test documents
├── 
├── 🗂️ scripts/
│   ├── 📄 setup_database.py            # Database setup automation
│   ├── 📄 test_workflow.py             # Workflow testing
│   ├── 📄 data_migration.py            # Data migration utilities
│   └── 📄 health_check.py              # System health monitoring
├── 
├── 🗂️ docs/
│   ├── 📄 INSTALLATION.md              # Detailed setup guide
│   ├── 📄 API_REFERENCE.md             # API documentation
│   ├── 📄 TROUBLESHOOTING.md           # Common issues and solutions
│   └── 📄 ARCHITECTURE.md              # Technical architecture details
├── 
├── 🗂️ config/
│   ├── 📄 n8n_environment.json         # n8n environment variables
│   ├── 📄 supabase_config.json         # Supabase configuration
│   └── 📄 telegram_config.json         # Telegram bot settings
└── 
└── 🗂️ tests/
    ├── 📄 test_rag_functionality.py    # RAG system tests
    ├── 📄 test_document_processing.py  # Document processing tests
    └── 📄 test_api_integrations.py     # External API tests
```

## ⚡ Quick Start (5 minutes)

### 1. Clone and Setup
```bash
# Clone this repository
git clone <your-repo-url>
cd ai-horizon-rag-agent

# Install Python dependencies
pip install -r requirements.txt

# Copy environment template
cp .env.example .env
```

### 2. Configure Environment
Edit `.env` with your credentials:
```bash
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key

# OpenAI
OPENAI_API_KEY=sk-your-openai-key

# Dumpling AI
DUMPLING_API_KEY=sk_your-dumpling-key

# Telegram
TELEGRAM_BOT_TOKEN=your-bot-token
```

### 3. Setup Database
```bash
# Run automated setup
python scripts/setup_database.py

# Or manually execute SQL files in Supabase SQL Editor:
# 1. database/schema.sql
# 2. database/vector_functions.sql
# 3. database/seed_data.sql
```

### 4. Import n8n Workflow
1. Open n8n interface
2. Import `n8n/workflow_fixed.json`
3. Update credentials (OpenAI, Supabase, Telegram)
4. Activate workflow

### 5. Test System
```bash
# Run health check
python scripts/health_check.py

# Test RAG functionality
python scripts/test_workflow.py
```

## 🔧 Detailed Installation

See [INSTALLATION.md](docs/INSTALLATION.md) for comprehensive setup instructions.

## 📖 Usage Examples

### Basic Chat
```
User: "Hello"
Bot: "Hello! I'm your AI Horizon assistant. I help analyze how AI impacts cybersecurity work..."
```

### Document Upload
```
User: [uploads PDF file]
Bot: "📄 Document processed successfully!
📌 File: AI_Strategy_Report.pdf
🏷️ Classification: Augment (87% confidence)
💬 Ask me anything about it!"
```

### RAG Query
```
User: "What does the document say about threat analysis?"
Bot: "Based on the uploaded document (92.3% similarity):

The 'AI Strategy Report' indicates that threat analysis will be **Augmented** by AI rather than replaced. Key points:
- AI will automate initial threat detection and pattern recognition
- Human analysts remain critical for complex threat assessment
- Hybrid approach shows 40% efficiency improvement..."
```

## 🧪 Testing

```bash
# Run all tests
python -m pytest tests/

# Test specific functionality
python tests/test_rag_functionality.py
python tests/test_document_processing.py

# Manual testing via scripts
python scripts/test_workflow.py
```

## 📊 Monitoring & Analytics

### Health Check Dashboard
```bash
python scripts/health_check.py
```

### System Metrics
- Document processing time: ~30-60 seconds
- Vector search response: <2 seconds
- Chat response time: <15 seconds
- Embedding generation: ~5-10 seconds

## 🔧 Configuration

### n8n Environment Variables
Set these in your n8n instance:
```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_SERVICE_KEY": "your-service-key",
  "OPENAI_API_KEY": "sk-your-openai-key",
  "DUMPLING_API_KEY": "sk_your-dumpling-key"
}
```

### Telegram Bot Setup
1. Create bot with @BotFather
2. Get bot token
3. Set webhook URL to your n8n instance
4. Configure bot commands in config/telegram_config.json

## 🚨 Troubleshooting

### Common Issues

1. **Vector search not working**
   - Ensure pgvector extension is enabled
   - Check if match_documents function exists
   - Verify embeddings are being stored

2. **Document processing fails**
   - Check Dumpling AI API key and credits
   - Verify file size limits (30MB for docs)
   - Ensure proper MIME type detection

3. **Chat responses are generic**
   - Verify vector search is returning results
   - Check OpenAI API key and quota
   - Review context building logic

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed solutions.

## 🔄 Deployment

### Development
- Run n8n locally with imported workflow
- Use ngrok for webhook testing
- Monitor logs for debugging

### Production
- Deploy n8n to cloud platform (Railway, DigitalOcean, etc.)
- Use production Supabase instance
- Set up monitoring and alerting
- Configure backup procedures

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Make changes and test thoroughly
4. Submit pull request with detailed description

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

- 📧 Create an issue for bugs or feature requests
- 💬 Join our Discord community (link)
- 📖 Check documentation in `/docs` folder
- 🔍 Search existing issues before creating new ones

## 🎯 Roadmap

- [ ] Web interface for document management
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] Integration with more document sources
- [ ] Real-time collaboration features
- [ ] Mobile app development

---

**Built with ❤️ for the cybersecurity community**