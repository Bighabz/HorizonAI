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

# Try to import optional dependencies
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("⚠️ python-dotenv not installed. Make sure to set environment variables manually.")

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    console = Console()
except ImportError:
    print("⚠️ rich not installed. Using basic output.")
    class Console:
        def print(self, *args, **kwargs):
            print(*args)
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
        
    def log_result(self, component, status, message):
        """Log a test result"""
        self.results[component] = {
            'status': status,
            'message': message,
            'timestamp': datetime.now().isoformat()
        }
        
        print(f"{status} {component}: {message}")

    def test_environment_variables(self):
        """Test that all required environment variables are set"""
        print("\n🔧 Testing Environment Variables")
        
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
        print("\n🗄️ Testing Supabase Connection")
        
        try:
            headers = {
                'apikey': self.config['supabase_service_key'],
                'Authorization': f"Bearer {self.config['supabase_service_key']}",
                'Content-Type': 'application/json'
            }
            
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
                    f"HTTP {response.status_code}"
                )
                return False
                
        except Exception as e:
            self.log_result(
                "Supabase Connection", 
                "❌ FAIL", 
                f"Connection error: {str(e)}"
            )
            return False

    def test_openai_api(self):
        """Test OpenAI API connection"""
        print("\n🤖 Testing OpenAI API")
        
        try:
            headers = {
                'Authorization': f"Bearer {self.config['openai_api_key']}",
                'Content-Type': 'application/json'
            }
            
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
                    f"HTTP {response.status_code}"
                )
                return False
                
        except Exception as e:
            self.log_result(
                "OpenAI API", 
                "❌ FAIL", 
                f"Connection error: {str(e)}"
            )
            return False

    def generate_report(self):
        """Generate comprehensive health check report"""
        duration = time.time() - self.start_time
        
        # Count results
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results.values() if r['status'] == "✅ PASS")
        failed_tests = sum(1 for r in self.results.values() if r['status'] == "❌ FAIL")
        
        print(f"\n" + "="*50)
        print(f"🏥 HEALTH CHECK SUMMARY")
        print(f"="*50)
        print(f"✅ Passed: {passed_tests}/{total_tests}")
        print(f"❌ Failed: {failed_tests}/{total_tests}")
        print(f"⏱️ Duration: {duration:.2f}s")
        
        if failed_tests == 0:
            print(f"\n🎉 SYSTEM HEALTHY!")
        else:
            print(f"\n🚨 ISSUES DETECTED")
            print("Check your .env file and API keys")
        
        return failed_tests == 0

    def run_all_tests(self):
        """Run all health checks"""
        print("🚀 AI Horizon RAG Agent - Health Check")
        print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        self.test_environment_variables()
        
        if self.test_supabase_connection():
            print("✅ Supabase connection working")
        
        self.test_openai_api()
        
        return self.generate_report()

def main():
    """Main entry point"""
    checker = HealthChecker()
    success = checker.run_all_tests()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()