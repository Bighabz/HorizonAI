# 🚀 AI Horizon RAG Agent - Quick Start

Get your AI Horizon RAG Agent running in **15 minutes**!

## ⚡ Prerequisites (5 minutes)

You need these accounts/keys:

1. **Supabase** → [Create free account](https://supabase.com)
2. **OpenAI** → [Get API key](https://platform.openai.com/api-keys) 
3. **Dumpling AI** → [Sign up](https://app.dumplingai.com)
4. **Telegram Bot** → Message [@BotFather](https://t.me/botfather)

## 🎯 Setup (10 minutes)

### 1. Environment Setup
```bash
# Copy and edit environment file
cp .env.example .env
# Edit .env with your API keys
```

### 2. Database Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Setup database (automated)
python scripts/setup_database.py
```

**OR manually in Supabase SQL Editor:**
1. Run `database/schema.sql`
2. Run `database/vector_functions.sql`

### 3. Import n8n Workflow
1. Open your n8n instance
2. Import `n8n/workflow_fixed.json`
3. Add your API credentials
4. Activate workflow

### 4. Test Everything
```bash
python scripts/health_check.py
```

## 🎉 You're Ready!

### Test Your Bot

1. **Send message to your Telegram bot:**
   ```
   Hello! Tell me about AI in cybersecurity.
   ```

2. **Upload a document:**
   - Send any PDF/DOCX file
   - Bot will process and classify it
   - Ask questions about the content

3. **Try these sample queries:**
   ```
   What tasks will AI replace in cybersecurity?
   How does AI augment threat analysis?
   Show me documents about workforce transformation.
   ```

## 🔧 Key Features

- **📄 Document Processing**: Upload PDFs, DOCX files
- **🤖 AI Classification**: Replace/Augment/Remain Human/New Task  
- **🔍 Vector Search**: Semantic similarity search
- **💬 Chat Memory**: Contextual conversations
- **📊 DCWF Mapping**: Links to cybersecurity framework

## 🆘 Need Help?

**Common Issues:**
- Vector search not working → Run `database/vector_functions.sql`
- Bot not responding → Check webhook URL and credentials
- Documents not processing → Verify Dumpling AI credits

**Get Support:**
- Run: `python scripts/health_check.py`
- Check: `docs/TROUBLESHOOTING.md`
- Review: `docs/INSTALLATION.md`

---

**🎯 That's it!** Your AI Horizon RAG Agent is ready to analyze cybersecurity workforce transformation.