import requests
import os
from dotenv import load_dotenv

load_dotenv()

# Check table structure
url = f"{os.getenv('SUPABASE_URL')}/rest/v1/dcwf_tasks?limit=0"
headers = {
    "apikey": os.getenv('SUPABASE_KEY'),
    "Authorization": f"Bearer {os.getenv('SUPABASE_KEY')}"
}

print("🔍 Checking dcwf_tasks table structure...")
response = requests.get(url, headers=headers)
print(f"Status: {response.status_code}")
print(f"Headers: {response.headers}")

# Try to get one row to see structure
url2 = f"{os.getenv('SUPABASE_URL')}/rest/v1/dcwf_tasks?limit=1"
response2 = requests.get(url2, headers=headers)
if response2.status_code == 200:
    data = response2.json()
    if data:
        print("\nTable columns:")
        for key in data[0].keys():
            print(f"  - {key}")
    else:
        print("\nNo data in table yet")