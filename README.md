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

## ⚡ Quick Start (15 minutes)

### 1. Environment Setup
```bash
# Copy and edit environment file
cp .env.example .env
# Edit .env with your API keys