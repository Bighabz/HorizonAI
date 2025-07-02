# AI Horizon RAG Agent for Cybersecurity Workforce Analysis

## 🎯 Project Overview

This project builds an AI-powered Retrieval-Augmented Generation (RAG) agent that analyzes how artificial intelligence impacts cybersecurity workforce tasks based on the **DCWF (Department of Homeland Security Cybersecurity Workforce Framework)**.

### Key Features
- **Document Processing**: Upload PDFs, Word docs → OCR → AI classification → Vector storage
- **YouTube Analysis**: Extract transcripts → Analyze AI impact → Store with embeddings  
- **RAG Chat Interface**: Query knowledge base with semantic search
- **DCWF Task Mapping**: Maps findings to specific cybersecurity task IDs (T0001-T0999+)
- **AI Impact Classification**: Categorizes as Replace/Augment/Remain Human/New Task

## 📁 Repository Structure

```
├── DCWFMASTER.xlsx                    # Complete DCWF framework data (1,350+ tasks, 1,772+ KSAs)
├── AIHORIZON.txt                      # AI Horizon forecasting pipeline requirements  
├── AI_HORIZON_WORKFLOW_FIX_PROMPT.md  # Technical prompt for workflow development
├── README.md                          # This file
├── requirements.txt                   # Python dependencies
├── n8n_credentials_setup.md           # API credentials setup guide
└── .gitignore                         # Git ignore rules
```

## � Current Status: WORKFLOW NEEDS FIXING

The n8n workflow requires technical expertise to properly connect all nodes for:
- Vector search with pgvector/Supabase
- OpenAI embeddings and chat completions
- Document processing with Dumpling AI OCR
- Telegram bot integration

**See `AI_HORIZON_WORKFLOW_FIX_PROMPT.md` for complete technical specifications.**

## 🔧 Technical Stack

- **Workflow Engine**: n8n (self-hosted)
- **Vector Database**: Supabase PostgreSQL with pgvector extension
- **AI Models**: OpenAI GPT-4o-mini, text-embedding-ada-002
- **OCR Service**: Dumpling AI for document/video processing
- **Interface**: Telegram Bot (@research_bot)
- **Framework**: DCWF cybersecurity workforce tasks

## 📊 Data Sources

### DCWFMASTER.xlsx
- **1,350 Tasks** mapped to cybersecurity work roles
- **1,772 KSAs** (Knowledge, Skills, Abilities)
- **3,123 total entries** with NIST SP mappings
- Real DHS cybersecurity workforce framework data

### AIHORIZON.txt  
- AI Horizon Forecasting Pipeline requirements
- Classification methodology (Replace/Augment/Remain Human/New Task)
- Scoring criteria (credibility, impact, specificity)
- Integration specifications

## 🎯 Use Cases

1. **Workforce Planning**: Analyze how AI will impact specific cybersecurity roles
2. **Training Development**: Identify skills that need human focus vs automation
3. **Research Analysis**: Process academic papers, reports, videos for AI impact insights
4. **Strategic Planning**: Evidence-based forecasting for cybersecurity workforce evolution

## 🔑 API Requirements

- **OpenAI API**: For embeddings and chat completions
- **Supabase**: PostgreSQL database with pgvector for semantic search
- **Dumpling AI**: OCR and transcript extraction
- **Telegram Bot API**: User interface

## 📋 Next Steps

1. **Fix n8n Workflow**: Use the technical prompt to create working node connections
2. **Setup Database**: Import DCWF data and create vector indexes
3. **Test Integration**: Verify document processing, chat, and vector search
4. **Deploy Production**: Configure credentials and activate bot

## 🤝 Contributing

This project analyzes real cybersecurity workforce data. Contributions should:
- Maintain data accuracy and DCWF framework integrity
- Follow evidence-based AI impact analysis methodology
- Ensure proper vector search and RAG functionality

## � License

This project contains public domain DCWF data from the Department of Homeland Security.

---

**Status**: Repository cleaned and organized. Workflow development needed for production deployment.