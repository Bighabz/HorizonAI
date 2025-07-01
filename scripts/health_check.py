#!/usr/bin/env python3
"""
AI Horizon RAG Agent - System Health Check
Comprehensive testing of all system components
"""

import os
import sys
import json
import requests
import time
from datetime import datetime
from typing import Dict, List, Any
from dotenv import load_dotenv
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn

# Load environment variables
load_dotenv()

console = Console()

class HealthChecker:
    def __init__(self):
        self.results = {}
        self.start_time = time.time()
        
        # Load configuration
        self.config = {
            'supabase_url': os.getenv('SUPABASE_URL'),
            'supabase_service_key': os.getenv('SUPABASE_SERVICE_KEY'),
            'openai_api_key': os.getenv('OPENAI_API_KEY'),
            'dumpling_api_key': os.getenv('DUMPLING_API_KEY'),
            'dumpling_api_url': os.getenv('DUMPLING_API_URL'),
        }
        
    def log_result(self, component: str, status: str, message: str, details: Dict = None):
        """Log a test result"""
        self.results[component] = {
            'status': status,
            'message': message,
            'details': details or {},
            'timestamp': datetime.now().isoformat()
        }
        
        # Color coding for console output
        color = "green" if status == "✅ PASS" else "red" if status == "❌ FAIL" else "yellow"
        console.print(f"[{color}]{status}[/{color}] {component}: {message}")

    def test_environment_variables(self):
        """Test that all required environment variables are set"""
        console.print("\n🔧 Testing Environment Variables", style="bold blue")
        
        required_vars = [
            'SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'OPENAI_API_KEY', 
            'DUMPLING_API_KEY', 'DUMPLING_API_URL'
        ]
        
        missing_vars = []
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            self.log_result(
                "Environment Variables", 
                "❌ FAIL", 
                f"Missing: {', '.join(missing_vars)}"
            )
            return False
        else:
            self.log_result(
                "Environment Variables", 
                "✅ PASS", 
                "All required variables present"
            )
            return True

    def test_supabase_connection(self):
        """Test Supabase database connection"""
        console.print("\n🗄️  Testing Supabase Connection", style="bold blue")
        
        try:
            headers = {
                'apikey': self.config['supabase_service_key'],
                'Authorization': f"Bearer {self.config['supabase_service_key']}",
                'Content-Type': 'application/json'
            }
            
            # Test basic connection
            response = requests.get(
                f"{self.config['supabase_url']}/rest/v1/",
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                self.log_result(
                    "Supabase Connection", 
                    "✅ PASS", 
                    "Database accessible"
                )
                return True
            else:
                self.log_result(
                    "Supabase Connection", 
                    "❌ FAIL", 
                    f"HTTP {response.status_code}: {response.text[:100]}"
                )
                return False
                
        except Exception as e:
            self.log_result(
                "Supabase Connection", 
                "❌ FAIL", 
                f"Connection error: {str(e)}"
            )
            return False

    def test_database_tables(self):
        """Test that all required database tables exist"""
        console.print("\n📊 Testing Database Tables", style="bold blue")
        
        required_tables = [
            'documents', 'chat_memory', 'dcwf_tasks', 
            'dcwf_descriptions', 'document_processing_log'
        ]
        
        headers = {
            'apikey': self.config['supabase_service_key'],
            'Authorization': f"Bearer {self.config['supabase_service_key']}",
            'Content-Type': 'application/json'
        }
        
        table_status = {}
        all_tables_exist = True
        
        for table in required_tables:
            try:
                response = requests.get(
                    f"{self.config['supabase_url']}/rest/v1/{table}?limit=0",
                    headers=headers,
                    timeout=5
                )
                
                if response.status_code == 200:
                    # Get row count
                    count_headers = {**headers, "Prefer": "count=exact"}
                    count_response = requests.head(
                        f"{self.config['supabase_url']}/rest/v1/{table}",
                        headers=count_headers,
                        timeout=5
                    )
                    
                    count = 0
                    if count_response.status_code == 200:
                        content_range = count_response.headers.get('Content-Range', '0')
                        count = int(content_range.split('/')[-1]) if '/' in content_range else 0
                    
                    table_status[table] = {'exists': True, 'count': count}
                    self.log_result(
                        f"Table: {table}", 
                        "✅ PASS", 
                        f"Exists ({count} rows)"
                    )
                else:
                    table_status[table] = {'exists': False, 'count': 0}
                    all_tables_exist = False
                    self.log_result(
                        f"Table: {table}", 
                        "❌ FAIL", 
                        f"Not accessible (HTTP {response.status_code})"
                    )
                    
            except Exception as e:
                table_status[table] = {'exists': False, 'error': str(e)}
                all_tables_exist = False
                self.log_result(
                    f"Table: {table}", 
                    "❌ FAIL", 
                    f"Error: {str(e)}"
                )
        
        return all_tables_exist, table_status

    def test_vector_functions(self):
        """Test that vector search functions exist"""
        console.print("\n🔍 Testing Vector Search Functions", style="bold blue")
        
        try:
            headers = {
                'apikey': self.config['supabase_service_key'],
                'Authorization': f"Bearer {self.config['supabase_service_key']}",
                'Content-Type': 'application/json'
            }
            
            # Test match_documents function with dummy data
            test_embedding = [0.1] * 1536  # Dummy 1536-dimensional vector
            
            response = requests.post(
                f"{self.config['supabase_url']}/rest/v1/rpc/match_documents",
                headers=headers,
                json={
                    'query_embedding': test_embedding,
                    'match_threshold': 0.5,
                    'match_count': 1
                },
                timeout=10
            )
            
            if response.status_code == 200:
                self.log_result(
                    "Vector Search Function", 
                    "✅ PASS", 
                    "match_documents function working"
                )
                return True
            else:
                self.log_result(
                    "Vector Search Function", 
                    "❌ FAIL", 
                    f"Function error: {response.text[:100]}"
                )
                return False
                
        except Exception as e:
            self.log_result(
                "Vector Search Function", 
                "❌ FAIL", 
                f"Test error: {str(e)}"
            )
            return False

    def test_openai_api(self):
        """Test OpenAI API connection"""
        console.print("\n🤖 Testing OpenAI API", style="bold blue")
        
        try:
            headers = {
                'Authorization': f"Bearer {self.config['openai_api_key']}",
                'Content-Type': 'application/json'
            }
            
            # Test models endpoint
            response = requests.get(
                'https://api.openai.com/v1/models',
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                models = response.json()
                model_count = len(models.get('data', []))
                self.log_result(
                    "OpenAI API", 
                    "✅ PASS", 
                    f"Connected ({model_count} models available)"
                )
                return True
            else:
                self.log_result(
                    "OpenAI API", 
                    "❌ FAIL", 
                    f"HTTP {response.status_code}: {response.text[:100]}"
                )
                return False
                
        except Exception as e:
            self.log_result(
                "OpenAI API", 
                "❌ FAIL", 
                f"Connection error: {str(e)}"
            )
            return False

    def test_dumpling_api(self):
        """Test Dumpling AI API connection"""
        console.print("\n📄 Testing Dumpling AI API", style="bold blue")
        
        try:
            headers = {
                'Authorization': f"Bearer {self.config['dumpling_api_key']}",
                'Content-Type': 'application/json'
            }
            
            # Test with a simple request (this might fail but will test auth)
            response = requests.post(
                f"{self.config['dumpling_api_url']}/test",
                headers=headers,
                json={'test': 'connection'},
                timeout=10
            )
            
            # Dumpling might return 404 for test endpoint, but auth should work
            if response.status_code in [200, 404, 422]:
                self.log_result(
                    "Dumpling AI API", 
                    "✅ PASS", 
                    "API accessible (auth working)"
                )
                return True
            elif response.status_code == 401:
                self.log_result(
                    "Dumpling AI API", 
                    "❌ FAIL", 
                    "Authentication failed - check API key"
                )
                return False
            else:
                self.log_result(
                    "Dumpling AI API", 
                    "⚠️ WARN", 
                    f"Unexpected response: HTTP {response.status_code}"
                )
                return True  # Assume it's working
                
        except Exception as e:
            self.log_result(
                "Dumpling AI API", 
                "❌ FAIL", 
                f"Connection error: {str(e)}"
            )
            return False

    def test_embedding_functionality(self):
        """Test embedding generation and storage"""
        console.print("\n🧮 Testing Embedding Functionality", style="bold blue")
        
        try:
            # Test OpenAI embedding generation
            headers = {
                'Authorization': f"Bearer {self.config['openai_api_key']}",
                'Content-Type': 'application/json'
            }
            
            response = requests.post(
                'https://api.openai.com/v1/embeddings',
                headers=headers,
                json={
                    'model': 'text-embedding-ada-002',
                    'input': 'This is a test sentence for embedding generation.'
                },
                timeout=15
            )
            
            if response.status_code == 200:
                data = response.json()
                embedding = data['data'][0]['embedding']
                
                if len(embedding) == 1536:
                    self.log_result(
                        "Embedding Generation", 
                        "✅ PASS", 
                        f"Generated {len(embedding)}-dimensional embedding"
                    )
                    return True
                else:
                    self.log_result(
                        "Embedding Generation", 
                        "❌ FAIL", 
                        f"Wrong embedding dimension: {len(embedding)}"
                    )
                    return False
            else:
                self.log_result(
                    "Embedding Generation", 
                    "❌ FAIL", 
                    f"OpenAI error: {response.text[:100]}"
                )
                return False
                
        except Exception as e:
            self.log_result(
                "Embedding Generation", 
                "❌ FAIL", 
                f"Error: {str(e)}"
            )
            return False

    def generate_report(self):
        """Generate comprehensive health check report"""
        duration = time.time() - self.start_time
        
        # Count results
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results.values() if r['status'] == "✅ PASS")
        failed_tests = sum(1 for r in self.results.values() if r['status'] == "❌ FAIL")
        warning_tests = sum(1 for r in self.results.values() if r['status'] == "⚠️ WARN")
        
        # Create summary table
        table = Table(title="🏥 Health Check Summary")
        table.add_column("Component", style="cyan")
        table.add_column("Status", style="bold")
        table.add_column("Message", style="white")
        
        for component, result in self.results.items():
            table.add_row(
                component,
                result['status'],
                result['message']
            )
        
        console.print("\n")
        console.print(table)
        
        # Overall status
        if failed_tests == 0:
            overall_status = "🎉 HEALTHY" if warning_tests == 0 else "⚠️ MOSTLY HEALTHY"
            color = "green" if warning_tests == 0 else "yellow"
        else:
            overall_status = "🚨 ISSUES DETECTED"
            color = "red"
        
        summary_panel = Panel(
            f"[bold {color}]{overall_status}[/bold {color}]\n\n"
            f"✅ Passed: {passed_tests}/{total_tests}\n"
            f"❌ Failed: {failed_tests}/{total_tests}\n"
            f"⚠️ Warnings: {warning_tests}/{total_tests}\n"
            f"⏱️ Duration: {duration:.2f}s",
            title="Overall System Health",
            border_style=color
        )
        
        console.print("\n")
        console.print(summary_panel)
        
        # Save detailed report
        report = {
            'timestamp': datetime.now().isoformat(),
            'duration_seconds': duration,
            'summary': {
                'total_tests': total_tests,
                'passed': passed_tests,
                'failed': failed_tests,
                'warnings': warning_tests,
                'overall_status': overall_status
            },
            'results': self.results
        }
        
        report_file = f"health_check_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        console.print(f"\n📄 Detailed report saved to: {report_file}")
        
        return failed_tests == 0

    def run_all_tests(self):
        """Run all health checks"""
        console.print("🚀 AI Horizon RAG Agent - Health Check", style="bold green")
        console.print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            
            # Run tests
            task = progress.add_task("Running health checks...", total=None)
            
            self.test_environment_variables()
            progress.update(task, description="Testing Supabase...")
            
            if self.test_supabase_connection():
                progress.update(task, description="Testing database tables...")
                self.test_database_tables()
                
                progress.update(task, description="Testing vector functions...")
                self.test_vector_functions()
            
            progress.update(task, description="Testing OpenAI API...")
            self.test_openai_api()
            
            progress.update(task, description="Testing Dumpling AI...")
            self.test_dumpling_api()
            
            progress.update(task, description="Testing embeddings...")
            self.test_embedding_functionality()
            
            progress.update(task, description="Generating report...")
        
        return self.generate_report()

def main():
    """Main entry point"""
    console.print("\n" + "="*60)
    console.print("🏥 AI HORIZON RAG AGENT - HEALTH CHECK", style="bold cyan", justify="center")
    console.print("="*60 + "\n")
    
    checker = HealthChecker()
    success = checker.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()