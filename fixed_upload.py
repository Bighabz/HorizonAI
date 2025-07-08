import pandas as pd
import requests
import json
import os
from dotenv import load_dotenv

load_dotenv()

# Load cleaned data
df = pd.read_excel('DCWF_Clean.xlsx')
print(f"✅ Loaded {len(df)} tasks")

# Prepare data WITHOUT task_description
tasks = []
for _, row in df.iterrows():
    task = {
        "task_id": str(row['Task ID']),
        "task_name": str(row['Task Name'])[:500],
        "work_role": str(row.get('Work Role', 'General')),
        "category": str(row.get('Category', 'General'))
        # NO task_description field!
    }
    tasks.append(task)

print(f"✅ Prepared {len(tasks)} tasks")

# Upload
url = f"{os.getenv('SUPABASE_URL')}/rest/v1/dcwf_tasks"
headers = {
    "apikey": os.getenv('SUPABASE_KEY'),
    "Authorization": f"Bearer {os.getenv('SUPABASE_KEY')}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

# Clear existing
print("\n🧹 Clearing existing data...")
requests.delete(url, headers=headers)

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
            data=json.dumps(batch),
            headers=headers
        )
        
        if response.status_code in [200, 201]:
            success_count += len(batch)
            print(f"✅ Batch {batch_num}: Uploaded {len(batch)} tasks (Total: {success_count})")
        else:
            print(f"❌ Batch {batch_num} failed: {response.status_code}")
            print(f"   Error: {response.text[:200]}...")
            # Save first failed batch for debugging
            if batch_num == 1:
                with open('debug_batch.json', 'w') as f:
                    json.dump(batch[:5], f, indent=2)
                print("   Saved first 5 tasks to debug_batch.json")
            break
            
    except Exception as e:
        print(f"❌ Batch {batch_num} error: {str(e)}")
        break

print(f"\n📊 Upload complete!")
print(f"   Successfully uploaded: {success_count} / {len(tasks)} tasks")