import os
from dotenv import load_dotenv
import requests

# Load environment variables
load_dotenv()

# Check if variables are loaded
print("🔍 Checking environment variables...")
print(f"SUPABASE_URL: {os.getenv('SUPABASE_URL')}")
print(f"SUPABASE_KEY: {os.getenv('SUPABASE_KEY')[:20]}...") # Show first 20 chars

# Test connection
url = f"{os.getenv('SUPABASE_URL')}/rest/v1/"
headers = {
    "apikey": os.getenv('SUPABASE_KEY'),
    "Authorization": f"Bearer {os.getenv('SUPABASE_KEY')}"
}

print("\n🧪 Testing Supabase connection...")
try:
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        print("✅ Connection successful!")
    else:
        print(f"❌ Connection failed: {response.status_code}")
        print(f"Error: {response.text}")
except Exception as e:
    print(f"❌ Error: {e}")