#!/usr/bin/env python3
"""
AI Horizon RAG Agent - Project Analysis & Setup
Analyzes the current state and provides implementation roadmap
"""

import os
import json
import requests
import psycopg2
from dotenv import load_dotenv
import pandas as pd

load_dotenv()

class HorizonAnalyzer:
    def __init__(self):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_KEY')
        self.supabase_service_key = os.getenv('SUPABASE_SERVICE_KEY')
        self.db_url = os.getenv('SUPABASE_DB_URL')
        self.openai_key = os.getenv('OPENAI_API_KEY')
        self.dumpling_key = os.getenv('DUMPLING_API_KEY')
        
        self.issues = []
        self.successes = []
        
    def log_success(self, message):
        print(f"✅ {message}")
        self.successes.append(message)
        
    def log_issue(self, message):
        print(f"❌ {message}")
        self.issues.append(message)
        
    def log_info(self, message):
        print(f"ℹ️  {message}")

    def check_credentials(self):
        """Check if all required credentials are present"""
        print("\n🔑 CHECKING CREDENTIALS")
        print("=" * 50)
        
        credentials = {
            'SUPABASE_URL': self.supabase_url,
            'SUPABASE_KEY': self.supabase_key,
            'SUPABASE_SERVICE_KEY': self.supabase_service_key,
            'SUPABASE_DB_URL': self.db_url,
            'OPENAI_API_KEY': self.openai_key,
            'DUMPLING_API_KEY': self.dumpling_key
        }
        
        for name, value in credentials.items():
            if value:
                self.log_success(f"{name}: Present")
            else:
                self.log_issue(f"{name}: Missing")

    def test_supabase_connection(self):
        """Test Supabase REST API connection"""
        print("\n🔗 TESTING SUPABASE CONNECTION")
        print("=" * 50)
        
        # Test with anon key
        headers_anon = {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json"
        }
        
        # Test with service key
        headers_service = {
            "apikey": self.supabase_service_key,
            "Authorization": f"Bearer {self.supabase_service_key}",
            "Content-Type": "application/json"
        }
        
        test_url = f"{self.supabase_url}/rest/v1/"
        
        try:
            # Test anon key
            response = requests.get(test_url, headers=headers_anon)
            if response.status_code == 200:
                self.log_success("Supabase REST API (anon key): Connected")
            else:
                self.log_issue(f"Supabase REST API (anon key): {response.status_code}")
                
            # Test service key
            response = requests.get(test_url, headers=headers_service)
            if response.status_code == 200:
                self.log_success("Supabase REST API (service key): Connected")
            else:
                self.log_issue(f"Supabase REST API (service key): {response.status_code}")
                
        except Exception as e:
            self.log_issue(f"Supabase connection error: {e}")

    def test_database_connection(self):
        """Test direct PostgreSQL connection"""
        print("\n🗄️  TESTING DATABASE CONNECTION")
        print("=" * 50)
        
        try:
            conn = psycopg2.connect(self.db_url)
            cursor = conn.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()
            self.log_success(f"PostgreSQL: Connected ({version[0][:50]}...)")
            
            # Check pgvector extension
            cursor.execute("SELECT * FROM pg_extension WHERE extname = 'vector';")
            vector_ext = cursor.fetchone()
            if vector_ext:
                self.log_success("pgvector extension: Installed")
            else:
                self.log_issue("pgvector extension: Not found")
                
            conn.close()
            
        except Exception as e:
            self.log_issue(f"Database connection error: {e}")

    def check_tables(self):
        """Check if required tables exist and their structure"""
        print("\n📊 CHECKING DATABASE TABLES")
        print("=" * 50)
        
        required_tables = [
            'documents',
            'chat_memory', 
            'dcwf_tasks',
            'dcwf_descriptions',
            'document_processing_log'
        ]
        
        try:
            conn = psycopg2.connect(self.db_url)
            cursor = conn.cursor()
            
            for table in required_tables:
                cursor.execute(f"""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_schema = 'public' 
                        AND table_name = '{table}'
                    );
                """)
                exists = cursor.fetchone()[0]
                
                if exists:
                    # Check row count
                    cursor.execute(f"SELECT COUNT(*) FROM {table};")
                    count = cursor.fetchone()[0]
                    self.log_success(f"Table '{table}': Exists ({count} rows)")
                    
                    # Show structure for key tables
                    if table in ['documents', 'chat_memory']:
                        cursor.execute(f"""
                            SELECT column_name, data_type 
                            FROM information_schema.columns 
                            WHERE table_name = '{table}' 
                            ORDER BY ordinal_position;
                        """)
                        columns = cursor.fetchall()
                        self.log_info(f"  Columns: {', '.join([col[0] for col in columns])}")
                else:
                    self.log_issue(f"Table '{table}': Missing")
            
            conn.close()
            
        except Exception as e:
            self.log_issue(f"Table check error: {e}")

    def test_external_apis(self):
        """Test external API connections"""
        print("\n🌐 TESTING EXTERNAL APIS")
        print("=" * 50)
        
        # Test OpenAI
        try:
            headers = {
                "Authorization": f"Bearer {self.openai_key}",
                "Content-Type": "application/json"
            }
            response = requests.get("https://api.openai.com/v1/models", headers=headers)
            if response.status_code == 200:
                self.log_success("OpenAI API: Connected")
            else:
                self.log_issue(f"OpenAI API: {response.status_code}")
        except Exception as e:
            self.log_issue(f"OpenAI API error: {e}")
            
        # Test Dumpling AI
        try:
            headers = {
                "Authorization": f"Bearer {self.dumpling_key}",
                "Content-Type": "application/json"
            }
            # Simple test endpoint (adjust based on actual API)
            test_data = {"test": "connection"}
            response = requests.post(f"{os.getenv('DUMPLING_API_URL')}/test", 
                                   headers=headers, json=test_data)
            if response.status_code in [200, 404]:  # 404 might mean endpoint doesn't exist but auth worked
                self.log_success("Dumpling AI API: Connected")
            else:
                self.log_issue(f"Dumpling AI API: {response.status_code}")
        except Exception as e:
            self.log_issue(f"Dumpling AI API error: {e}")

    def analyze_workflow(self):
        """Analyze the n8n workflow file"""
        print("\n⚙️  ANALYZING N8N WORKFLOW")
        print("=" * 50)
        
        try:
            with open('My_workflow_26.json', 'r') as f:
                workflow = json.load(f)
                
            nodes = workflow.get('nodes', [])
            connections = workflow.get('connections', {})
            
            self.log_success(f"Workflow loaded: {len(nodes)} nodes")
            
            # Check for key nodes
            node_types = {}
            for node in nodes:
                node_type = node.get('type', 'unknown')
                node_types[node_type] = node_types.get(node_type, 0) + 1
                
            self.log_info(f"Node types: {dict(node_types)}")
            
            # Check for critical nodes
            critical_nodes = [
                'n8n-nodes-base.telegramTrigger',
                'n8n-nodes-base.supabase', 
                'n8n-nodes-base.httpRequest',
                'n8n-nodes-base.code'
            ]
            
            for node_type in critical_nodes:
                if node_type in node_types:
                    self.log_success(f"Has {node_type}: {node_types[node_type]} instances")
                else:
                    self.log_issue(f"Missing {node_type}")
                    
        except Exception as e:
            self.log_issue(f"Workflow analysis error: {e}")

    def check_dcwf_data(self):
        """Check DCWF data loading"""
        print("\n📋 CHECKING DCWF DATA")
        print("=" * 50)
        
        try:
            # Check CSV file
            if os.path.exists('DCWF_Clean.csv'):
                df = pd.read_csv('DCWF_Clean.csv')
                self.log_success(f"DCWF CSV: {len(df)} rows loaded")
                self.log_info(f"Columns: {list(df.columns)}")
                
                # Check if data is loaded in database
                conn = psycopg2.connect(self.db_url)
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM dcwf_tasks;")
                db_count = cursor.fetchone()[0]
                
                if db_count > 0:
                    self.log_success(f"DCWF tasks in DB: {db_count} rows")
                else:
                    self.log_issue("DCWF tasks: Not loaded in database")
                    
                conn.close()
            else:
                self.log_issue("DCWF_Clean.csv: File not found")
                
        except Exception as e:
            self.log_issue(f"DCWF data check error: {e}")

    def generate_implementation_plan(self):
        """Generate implementation roadmap based on findings"""
        print("\n🗺️  IMPLEMENTATION ROADMAP")
        print("=" * 50)
        
        print("\n📋 PHASE 1: Database Setup")
        if any("Table" in issue and "Missing" in issue for issue in self.issues):
            print("  1. Create missing database tables")
            print("  2. Set up pgvector extension")
            print("  3. Load DCWF reference data")
        else:
            print("  ✅ Database tables already exist")
            
        print("\n📋 PHASE 2: Basic RAG Chat")
        print("  1. Fix vector search implementation")
        print("  2. Improve chat context building")
        print("  3. Test conversation flow")
        
        print("\n📋 PHASE 3: Document Processing")
        print("  1. Verify Dumpling AI integration")
        print("  2. Test PDF/DOCX extraction")
        print("  3. Improve chunking strategy")
        print("  4. Fix embedding generation")
        
        print("\n📋 PHASE 4: Advanced Features")
        print("  1. YouTube/TikTok processing")
        print("  2. DCWF task mapping")
        print("  3. Export functionality")
        print("  4. Statistics dashboard")
        
        print("\n📋 IMMEDIATE FIXES NEEDED:")
        for issue in self.issues:
            print(f"  - {issue}")

    def run_full_analysis(self):
        """Run complete analysis"""
        print("🚀 AI HORIZON RAG AGENT - PROJECT ANALYSIS")
        print("=" * 60)
        
        self.check_credentials()
        self.test_supabase_connection()
        self.test_database_connection()
        self.check_tables()
        self.test_external_apis()
        self.analyze_workflow()
        self.check_dcwf_data()
        self.generate_implementation_plan()
        
        print(f"\n📊 SUMMARY")
        print("=" * 30)
        print(f"✅ Successes: {len(self.successes)}")
        print(f"❌ Issues: {len(self.issues)}")
        
        if len(self.issues) == 0:
            print("\n🎉 System appears to be fully functional!")
        else:
            print(f"\n🔧 {len(self.issues)} issues need attention")

if __name__ == "__main__":
    analyzer = HorizonAnalyzer()
    analyzer.run_full_analysis()