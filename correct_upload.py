import pandas as pd
import requests
import json
import os
from dotenv import load_dotenv

load_dotenv()

# Load data
df = pd.read_excel('DCWF_Clean.xlsx')
print(f"✅ Loaded {len(df)} tasks")

# Prepare data matching EXACT table structure
tasks = []
for _, row in df.iterrows():
    task = {
        "task_id": str(row['Task ID']),
        "task_name": str(row['Task Name'])[:500],
        "category": str(row.get('Category', 'General')),  # Required field
        "description": "",  # Optional, can be empty
        "keywords": [],     # Empty array for now
        "typical_roles": [str(row.get('Work Role', 'General'))]  # Array with one role
    }
    tasks.append(task)

print(f"✅ Prepared {len(tasks)} tasks")
print(f"\n📋 Sample task:")
print(json.dumps(tasks[0], indent=2))

# Confirm
if input("\n📤 Upload these tasks? (y/n): ").lower() != 'y':
    exit()

# Upload
url = f"{os.getenv('SUPABASE_URL')}/rest/v1/dcwf_tasks"
headers = {
    "apikey": os.getenv('SUPABASE_KEY'),
    "Authorization": f"Bearer {os.getenv('SUPABASE_KEY')}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

# Clear existing data
print("\n🧹 Clearing existing data...")
delete_response = requests.delete(url, headers=headers)
print(f"   Delete status: {delete_response.status_code}")

# Upload in batches
batch_size = 50
success_count = 0

print(f"\n📤 Uploading in batches of {batch_size}...")
for i in range(0, len(tasks), batch_size):
    batch = tasks[i:i+batch_size]
    batch_num = i // batch_size + 1
    
    try:
        response = requests.post(
            url, 
            json=batch,  # Using json parameter
            headers=headers
        )
        
        if response.status_code in [200, 201]:
            success_count += len(batch)
            print(f"✅ Batch {batch_num}: Uploaded {len(batch)} tasks (Total: {success_count})")
        else:
            print(f"❌ Batch {batch_num} failed: {response.status_code}")
            print(f"   Error: {response.text[:200]}...")
            break
            
    except Exception as e:
        print(f"❌ Batch {batch_num} error: {str(e)}")
        break

print(f"\n📊 Upload complete!")
print(f"   Successfully uploaded: {success_count} / {len(tasks)} tasks")

# Verify
if success_count > 0:
    verify_response = requests.get(f"{url}?limit=5", headers=headers)
    if verify_response.status_code == 200:
        print(f"\n✅ Verified! Sample tasks in database:")
        for task in verify_response.json()[:3]:
            print(f"   {task['task_id']}: {task['task_name'][:50]}...")