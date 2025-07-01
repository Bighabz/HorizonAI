#!/usr/bin/env python3
"""
AI Horizon RAG Agent - Database Setup via Supabase REST API
Sets up all required tables and loads DCWF reference data
"""

import os
import json
import requests
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

class DatabaseSetup:
    def __init__(self):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.service_key = os.getenv('SUPABASE_SERVICE_KEY')
        self.headers = {
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        }
        
    def log_success(self, message):
        print(f"✅ {message}")
        
    def log_error(self, message):
        print(f"❌ {message}")
        
    def log_info(self, message):
        print(f"ℹ️  {message}")

    def check_table_exists(self, table_name):
        """Check if a table exists by trying to query it"""
        try:
            url = f"{self.supabase_url}/rest/v1/{table_name}?limit=0"
            response = requests.get(url, headers=self.headers)
            return response.status_code == 200
        except:
            return False

    def get_table_count(self, table_name):
        """Get row count for a table"""
        try:
            url = f"{self.supabase_url}/rest/v1/{table_name}?select=count"
            headers = {**self.headers, "Prefer": "count=exact"}
            response = requests.head(url, headers=headers)
            if response.status_code == 200:
                count = response.headers.get('Content-Range', '0').split('/')[-1]
                return int(count) if count != '*' else 0
            return 0
        except:
            return 0

    def check_existing_tables(self):
        """Check status of all required tables"""
        print("\n📊 CHECKING EXISTING TABLES")
        print("=" * 50)
        
        tables = [
            'documents',
            'chat_memory',
            'dcwf_tasks', 
            'dcwf_descriptions',
            'document_processing_log'
        ]
        
        table_status = {}
        for table in tables:
            exists = self.check_table_exists(table)
            if exists:
                count = self.get_table_count(table)
                self.log_success(f"Table '{table}': Exists ({count} rows)")
                table_status[table] = {'exists': True, 'count': count}
            else:
                self.log_error(f"Table '{table}': Missing or inaccessible")
                table_status[table] = {'exists': False, 'count': 0}
                
        return table_status

    def test_vector_search(self):
        """Test if vector search is working on documents table"""
        print("\n🔍 TESTING VECTOR SEARCH")
        print("=" * 50)
        
        try:
            # Try to get documents with embeddings
            url = f"{self.supabase_url}/rest/v1/documents?select=id,title,embedding&limit=1"
            response = requests.get(url, headers=self.headers)
            
            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0:
                    doc = data[0]
                    if 'embedding' in doc and doc['embedding']:
                        self.log_success("Vector embeddings: Present in documents")
                        return True
                    else:
                        self.log_error("Vector embeddings: Missing in documents")
                else:
                    self.log_info("Documents table: Empty")
            else:
                self.log_error(f"Documents table access: {response.status_code}")
                
        except Exception as e:
            self.log_error(f"Vector search test error: {e}")
            
        return False

    def load_dcwf_data(self):
        """Load DCWF data from CSV into database"""
        print("\n📋 LOADING DCWF DATA")
        print("=" * 50)
        
        try:
            # Check if already loaded
            count = self.get_table_count('dcwf_tasks')
            if count > 3000:
                self.log_success(f"DCWF data already loaded: {count} tasks")
                return True
                
            # Load from CSV
            if not os.path.exists('DCWF_Clean.csv'):
                self.log_error("DCWF_Clean.csv not found")
                return False
                
            df = pd.read_csv('DCWF_Clean.csv')
            self.log_info(f"Loading {len(df)} DCWF tasks...")
            
            # Prepare data for insertion
            tasks = []
            for _, row in df.iterrows():
                task = {
                    "task_id": str(row['Task ID']),
                    "task_name": str(row['Task Name']),
                    "category": str(row['Category']),
                    "description": "",  # Empty for now
                    "keywords": [],     # Empty array
                    "typical_roles": [str(row['Work Role'])] if pd.notna(row['Work Role']) else []
                }
                tasks.append(task)
            
            # Insert in batches of 100
            batch_size = 100
            total_inserted = 0
            
            for i in range(0, len(tasks), batch_size):
                batch = tasks[i:i + batch_size]
                
                url = f"{self.supabase_url}/rest/v1/dcwf_tasks"
                response = requests.post(url, headers=self.headers, json=batch)
                
                if response.status_code in [200, 201]:
                    total_inserted += len(batch)
                    print(f"  Inserted batch {i//batch_size + 1}: {total_inserted}/{len(tasks)}")
                else:
                    self.log_error(f"Batch insert failed: {response.status_code} - {response.text}")
                    break
            
            if total_inserted == len(tasks):
                self.log_success(f"DCWF data loaded: {total_inserted} tasks")
                return True
            else:
                self.log_error(f"Partial load: {total_inserted}/{len(tasks)} tasks")
                return False
                
        except Exception as e:
            self.log_error(f"DCWF data loading error: {e}")
            return False

    def test_basic_operations(self):
        """Test basic CRUD operations on key tables"""
        print("\n🧪 TESTING BASIC OPERATIONS")
        print("=" * 50)
        
        # Test chat_memory insert
        try:
            test_message = {
                "user_id": "test_user",
                "chat_id": "test_chat",
                "username": "test",
                "role": "user",
                "content": "Test message for setup verification",
                "metadata": {"test": True}
            }
            
            url = f"{self.supabase_url}/rest/v1/chat_memory"
            response = requests.post(url, headers=self.headers, json=test_message)
            
            if response.status_code in [200, 201]:
                self.log_success("Chat memory: Insert test passed")
                
                # Clean up test data
                cleanup_url = f"{self.supabase_url}/rest/v1/chat_memory?user_id=eq.test_user"
                requests.delete(cleanup_url, headers=self.headers)
                
            else:
                self.log_error(f"Chat memory insert failed: {response.status_code}")
                
        except Exception as e:
            self.log_error(f"Chat memory test error: {e}")

        # Test documents table structure
        try:
            url = f"{self.supabase_url}/rest/v1/documents?limit=1"
            response = requests.get(url, headers=self.headers)
            
            if response.status_code == 200:
                self.log_success("Documents table: Access verified")
            else:
                self.log_error(f"Documents table access: {response.status_code}")
                
        except Exception as e:
            self.log_error(f"Documents table test error: {e}")

    def create_sample_document(self):
        """Create a sample document to test the full pipeline"""
        print("\n📄 CREATING SAMPLE DOCUMENT")
        print("=" * 50)
        
        try:
            # Check if sample already exists
            url = f"{self.supabase_url}/rest/v1/documents?artifact_id=eq.sample_setup_test"
            response = requests.get(url, headers=self.headers)
            
            if response.status_code == 200 and response.json():
                self.log_success("Sample document already exists")
                return True
            
            # Create sample document
            sample_doc = {
                "artifact_id": "sample_setup_test",
                "title": "AI Horizon Setup Test Document",
                "summary": "This is a test document created during setup to verify the system is working correctly.",
                "content": "This document tests the AI Horizon RAG system. It should be classified as 'Augment' since it's about AI helping with cybersecurity tasks rather than replacing humans entirely. Key topics include: artificial intelligence, cybersecurity automation, human-AI collaboration, threat detection, and security operations.",
                "source_type": "test",
                "filename": "setup_test.txt",
                "classification": "Augment",
                "confidence": 0.85,
                "rationale": "Test document for system verification",
                "impact_score": 0.7,
                "dcwf_task_ids": ["TVM-001", "ANL-004"],
                "work_roles": ["Vulnerability Assessment Analyst", "Threat Analyst"],
                "category": "AI Strategy",
                "tags": ["ai", "cybersecurity", "test", "setup"],
                "user_id": "system",
                "chat_id": "setup",
                "username": "System Setup",
                "metadata": {"created_by": "setup_script", "test": True}
            }
            
            # Note: We'll skip embedding for now since we can't test OpenAI
            url = f"{self.supabase_url}/rest/v1/documents"
            response = requests.post(url, headers=self.headers, json=sample_doc)
            
            if response.status_code in [200, 201]:
                self.log_success("Sample document created successfully")
                return True
            else:
                self.log_error(f"Sample document creation failed: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            self.log_error(f"Sample document creation error: {e}")
            return False

    def generate_setup_report(self):
        """Generate final setup report"""
        print("\n📋 SETUP REPORT")
        print("=" * 50)
        
        table_status = self.check_existing_tables()
        
        print(f"\n🗃️  Database Status:")
        for table, status in table_status.items():
            status_text = f"✅ Ready ({status['count']} rows)" if status['exists'] else "❌ Missing"
            print(f"  {table}: {status_text}")
        
        # Check if system is ready for use
        critical_tables = ['documents', 'chat_memory', 'dcwf_tasks']
        ready = all(table_status.get(table, {}).get('exists', False) for table in critical_tables)
        
        print(f"\n🚀 System Status: {'✅ Ready for use' if ready else '❌ Needs attention'}")
        
        if ready:
            print("\n🎯 Next Steps:")
            print("  1. Test the Telegram bot with a simple message")
            print("  2. Upload a test document (PDF or DOCX)")
            print("  3. Verify vector search is working")
            print("  4. Check AI classification accuracy")
        else:
            print("\n🔧 Required Actions:")
            print("  1. Ensure all database tables are created")
            print("  2. Load DCWF reference data")
            print("  3. Test basic CRUD operations")

    def run_setup(self):
        """Run complete database setup"""
        print("🚀 AI HORIZON DATABASE SETUP")
        print("=" * 60)
        
        # Check current state
        table_status = self.check_existing_tables()
        
        # Load DCWF data if needed
        if table_status.get('dcwf_tasks', {}).get('count', 0) < 3000:
            self.load_dcwf_data()
        
        # Test vector search capability
        self.test_vector_search()
        
        # Test basic operations
        self.test_basic_operations()
        
        # Create sample document
        self.create_sample_document()
        
        # Generate final report
        self.generate_setup_report()

if __name__ == "__main__":
    setup = DatabaseSetup()
    setup.run_setup()