#!/usr/bin/env python3
"""
AI Horizon RAG Agent - Database Setup Script
Automated setup of all required database components
"""

import os
import sys
import requests

# Try to import optional dependencies
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("⚠️ python-dotenv not installed. Make sure to set environment variables manually.")

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
        required_tables = ['documents', 'chat_memory']
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

    def create_sample_document(self):
        """Create a sample document for testing"""
        try:
            # Generate sample embedding (dummy data)
            sample_embedding = [0.1 + (i * 0.001) for i in range(1536)]
            
            sample_doc = {
                'artifact_id': 'sample_doc_001',
                'title': 'Sample AI Impact Document',
                'content': 'This is a sample document that demonstrates how artificial intelligence can augment cybersecurity threat analysis tasks.',
                'source_type': 'pdf',
                'filename': 'sample_ai_impact.pdf',
                'classification': 'Augment',
                'confidence': 0.85,
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
        
        if len(existing_tables) < 2:
            print("\n⚠️ Some tables are missing!")
            print("Please run the SQL schema files in Supabase SQL Editor:")
            print("1. database/schema.sql")
            print("2. database/vector_functions.sql")
            return False
        
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