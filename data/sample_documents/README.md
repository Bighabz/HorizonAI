# Sample Documents

This directory contains sample documents for testing the AI Horizon RAG Agent.

## Purpose

These documents are used to:
- Test document processing workflows
- Validate RAG functionality
- Demonstrate AI impact classification
- Provide examples for new users

## Document Types

### 1. PDF Documents
- `ai_cybersecurity_report.pdf` - Sample cybersecurity AI report
- `threat_analysis_guide.pdf` - Threat analysis methodology

### 2. DOCX Documents  
- `workforce_transformation.docx` - Cybersecurity workforce analysis
- `ai_implementation_strategy.docx` - AI implementation guide

### 3. Text Files
- `sample_analysis.txt` - Plain text analysis document
- `dcwf_mapping_example.txt` - DCWF task mapping example

## Usage

1. **Upload via Telegram Bot:**
   - Send any of these files to your bot
   - Bot will process and classify the document
   - You can then ask questions about the content

2. **Bulk Processing:**
   ```bash
   python scripts/process_sample_documents.py
   ```

3. **Testing:**
   ```bash
   python scripts/test_document_processing.py
   ```

## Expected Classifications

| Document | Expected Classification | Confidence |
|----------|------------------------|------------|
| ai_cybersecurity_report.pdf | Augment | 85%+ |
| threat_analysis_guide.pdf | Remain Human | 70%+ |
| workforce_transformation.docx | Replace | 80%+ |
| ai_implementation_strategy.docx | New Task | 75%+ |

## Adding New Samples

To add new sample documents:

1. **Place file in this directory**
2. **Update this README** with expected classification
3. **Test processing:**
   ```bash
   python scripts/test_single_document.py your_document.pdf
   ```

## File Size Limits

- **PDF/DOCX:** 30MB maximum
- **Text files:** 10MB maximum
- **Images:** Not supported (use OCR preprocessing)

## Notes

- All sample documents are for testing purposes only
- Documents should represent realistic cybersecurity content
- Ensure proper licensing for any real documents used