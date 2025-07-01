#!/usr/bin/env python3
"""
AI Horizon RAG Agent - Database Setup Script
Automated setup of all required database components
"""

import os
import sys
import json
import requests
import pandas as pd
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables
load_dotenv()

class DatabaseSetup:
    def __init__(self):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.service_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        if not self.supabase_url or not self.service_key:
            print("❌ Missing required environment variables!")
            print("Please set SUPABASE_URL and SUPABASE_SERVICE_KEY in .env file")
            sys.exit(1)
            
        self.headers = {
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
            "Content-Type": "application/json"
        }
        
    def log_success(self, message):
        print(f"✅ {message}")
        
    def log_error(self, message):
        print(f"❌ {message}")
        
    def log_info(self, message):
        print(f"ℹ️ {message}")

    def test_connection(self):
        """Test basic Supabase connection"""
        try:
            response = requests.get(
                f"{self.supabase_url}/rest/v1/",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                self.log_success("Connected to Supabase successfully")
                return True
            else:
                self.log_error(f"Supabase connection failed: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            self.log_error(f"Connection error: {str(e)}")
            return False

    def check_tables_exist(self):
        """Check if required tables exist"""
        required_tables = ['documents', 'chat_memory', 'dcwf_tasks', 'dcwf_descriptions']
        existing_tables = []
        
        for table in required_tables:
            try:
                response = requests.get(
                    f"{self.supabase_url}/rest/v1/{table}?limit=0",
                    headers=self.headers,
                    timeout=5
                )
                
                if response.status_code == 200:
                    existing_tables.append(table)
                    self.log_success(f"Table '{table}' exists")
                else:
                    self.log_error(f"Table '{table}' not found")
                    
            except Exception as e:
                self.log_error(f"Error checking table '{table}': {str(e)}")
        
        return existing_tables

    def check_vector_functions(self):
        """Check if vector search functions exist"""
        try:
            # Test match_documents function with dummy data
            test_embedding = [0.1] * 1536
            
            response = requests.post(
                f"{self.supabase_url}/rest/v1/rpc/match_documents",
                headers=self.headers,
                json={
                    'query_embedding': test_embedding,
                    'match_threshold': 0.5,
                    'match_count': 1
                },
                timeout=10
            )
            
            if response.status_code == 200:
                self.log_success("Vector search functions are working")
                return True
            else:
                self.log_error("Vector search functions not found or not working")
                return False
                
        except Exception as e:
            self.log_error(f"Error testing vector functions: {str(e)}")
            return False

    def load_dcwf_data(self):
        """Load DCWF data from CSV file"""
        try:
            # Check if data already exists
            response = requests.head(
                f"{self.supabase_url}/rest/v1/dcwf_descriptions",
                headers={**self.headers, "Prefer": "count=exact"},
                timeout=5
            )
            
            if response.status_code == 200:
                count = response.headers.get('Content-Range', '0').split('/')[-1]
                if int(count) > 0:
                    self.log_info(f"DCWF data already exists ({count} rows)")
                    return True
            
            # Load CSV file
            csv_path = Path(__file__).parent.parent / "data" / "DCWF_Clean.csv"
            if not csv_path.exists():
                csv_path = Path(__file__).parent.parent / "DCWF_Clean.csv"
            
            if not csv_path.exists():
                self.log_error("DCWF_Clean.csv not found")
                return False
            
            df = pd.read_csv(csv_path)
            self.log_info(f"Loaded DCWF CSV with {len(df)} rows")
            
            # Transform data for database
            dcwf_records = []
            for _, row in df.iterrows():
                record = {
                    'code': str(row.get('Code', '')),
                    'category': str(row.get('Category', '')),
                    'name': str(row.get('Name', '')),
                    'description': str(row.get('Description', '')),
                    'ai_impact': 'To be analyzed',
                    'examples': []
                }
                dcwf_records.append(record)
            
            # Insert in batches
            batch_size = 100
            for i in range(0, len(dcwf_records), batch_size):
                batch = dcwf_records[i:i+batch_size]
                
                response = requests.post(
                    f"{self.supabase_url}/rest/v1/dcwf_descriptions",
                    headers=self.headers,
                    json=batch,
                    timeout=30
                )
                
                if response.status_code not in [200, 201]:
                    self.log_error(f"Failed to insert DCWF batch {i//batch_size + 1}")
                    return False
            
            self.log_success(f"Loaded {len(dcwf_records)} DCWF records")
            return True
            
        except Exception as e:
            self.log_error(f"Error loading DCWF data: {str(e)}")
            return False

    def create_sample_document(self):
        """Create a sample document for testing"""
        try:
            # Check if sample already exists
            response = requests.get(
                f"{self.supabase_url}/rest/v1/documents?artifact_id=eq.sample_doc_001",
                headers=self.headers,
                timeout=5
            )
            
            if response.status_code == 200 and response.json():
                self.log_info("Sample document already exists")
                return True
            
            # Generate sample embedding (dummy data)
            sample_embedding = [0.1 + (i * 0.001) for i in range(1536)]
            
            sample_doc = {
                'artifact_id': 'sample_doc_001',
                'title': 'Sample AI Impact Document',
                'summary': 'A sample document demonstrating AI impact analysis on cybersecurity tasks.',
                'content': 'This is a sample document that demonstrates how artificial intelligence can augment cybersecurity threat analysis tasks. It shows the integration of AI tools with human expertise to improve detection accuracy and response times.',
                'source_type': 'pdf',
                'filename': 'sample_ai_impact.pdf',
                'classification': 'Augment',
                'confidence': 0.85,
                'rationale': 'AI enhances human capabilities in threat analysis while requiring human oversight for complex decisions.',
                'impact_score': 0.7,
                'dcwf_task_ids': ['AN-001', 'AN-002'],
                'work_roles': ['Cyber Threat Analyst', 'Incident Analyst'],
                'category': 'Threat Analysis',
                'tags': ['AI', 'threat analysis', 'augmentation', 'cybersecurity'],
                'embedding': sample_embedding,
                'user_id': 'system',
                'chat_id': 'system',
                'username': 'system'
            }
            
            response = requests.post(
                f"{self.supabase_url}/rest/v1/documents",
                headers=self.headers,
                json=sample_doc,
                timeout=10
            )
            
            if response.status_code in [200, 201]:
                self.log_success("Created sample document")
                return True
            else:
                self.log_error(f"Failed to create sample document: {response.text}")
                return False
                
        except Exception as e:
            self.log_error(f"Error creating sample document: {str(e)}")
            return False

    def run_setup(self):
        """Run complete database setup"""
        print("🚀 AI Horizon RAG Agent - Database Setup")
        print("=" * 50)
        
        # Test connection
        if not self.test_connection():
            print("\n❌ Setup failed - cannot connect to Supabase")
            return False
        
        # Check tables
        print("\n📊 Checking database tables...")
        existing_tables = self.check_tables_exist()
        
        if len(existing_tables) < 4:
            print("\n⚠️ Some tables are missing!")
            print("Please run the SQL schema files in Supabase SQL Editor:")
            print("1. database/schema.sql")
            print("2. database/vector_functions.sql")
            return False
        
        # Check vector functions
        print("\n🔍 Checking vector search functions...")
        if not self.check_vector_functions():
            print("\n⚠️ Vector search functions are missing!")
            print("Please run database/vector_functions.sql in Supabase SQL Editor")
            return False
        
        # Load DCWF data
        print("\n📚 Loading DCWF reference data...")
        self.load_dcwf_data()
        
        # Create sample document
        print("\n📄 Creating sample document...")
        self.create_sample_document()
        
        print("\n🎉 Database setup completed successfully!")
        print("\nNext steps:")
        print("1. Import n8n/workflow_fixed.json into your n8n instance")
        print("2. Configure API credentials in n8n")
        print("3. Run: python scripts/health_check.py")
        
        return True

def main():
    """Main entry point"""
    setup = DatabaseSetup()
    success = setup.run_setup()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()