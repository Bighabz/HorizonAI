import pandas as pd
import requests
import json
import os
from dotenv import load_dotenv

load_dotenv()

# Load the cleaned file
print("Loading cleaned DCWF data...")
try:
    df = pd.read_excel('DCWF_Clean.xlsx')
    print(f"✅ Loaded {len(df)} tasks from DCWF_Clean.xlsx")
except:
    print("❌ DCWF_Clean.xlsx not found! Run fix_dcwf.py first")
    exit()

# Show what we're uploading
print(f"\nColumns: {list(df.columns)}")
print("\nFirst 3 tasks:")
for i in range(min(3, len(df))):
    print(f"  {df.iloc[i]['Task ID']}: {df.iloc[i]['Task Name'][:50]}...")

# Confirm
if input("\n📤 Upload these tasks? (y/n): ").lower() != 'y':
    print("Cancelled.")
    exit()

# Prepare data for upload
print("\n🔧 Preparing data...")
tasks = []
for idx, row in df.iterrows():
    # Convert each value to string and handle any issues
    task = {
        "task_id": str(row['Task ID']),
        "task_name": str(row['Task Name'])[:500],  # Limit length
        "work_role": str(row.get('Work Role', 'General')),
        "category": str(row.get('Category', 'General')),
        "task_description": ""  # Empty for now
    }
    tasks.append(task)

print(f"✅ Prepared {len(tasks)} tasks")

# Supabase setup
url = f"{os.getenv('SUPABASE_URL')}/rest/v1/dcwf_tasks"
headers = {
    "apikey": os.getenv('SUPABASE_KEY'),
    "Authorization": f"Bearer {os.getenv('SUPABASE_KEY')}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

# First, clear existing data
print("\n🧹 Clearing existing data...")
try:
    delete_response = requests.delete(url, headers=headers)
    print(f"   Delete status: {delete_response.status_code}")
except Exception as e:
    print(f"   Warning: Could not clear data: {e}")

# Upload in small batches to avoid issues
batch_size = 50  # Smaller batches
success_count = 0

print(f"\n📤 Uploading in batches of {batch_size}...")
for i in range(0, len(tasks), batch_size):
    batch = tasks[i:i+batch_size]
    batch_num = i // batch_size + 1
    
    try:
        # Convert to JSON manually to check for issues
        json_data = json.dumps(batch)
        
        # Upload
        response = requests.post(
            url, 
            data=json_data,  # Use data instead of json parameter
            headers=headers
        )
        
        if response.status_code in [200, 201]:
            success_count += len(batch)
            print(f"✅ Batch {batch_num}: Uploaded {len(batch)} tasks (Total: {success_count})")
        else:
            print(f"❌ Batch {batch_num} failed: {response.status_code}")
            print(f"   Error: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ Batch {batch_num} error: {str(e)}")
        # Save problematic batch for debugging
        with open(f'error_batch_{batch_num}.json', 'w') as f:
            json.dump(batch, f, indent=2)
        print(f"   Saved problematic batch to error_batch_{batch_num}.json")

print(f"\n📊 Upload complete!")
print(f"   Successfully uploaded: {success_count} / {len(tasks)} tasks")

# Verify upload
print("\n🔍 Verifying upload...")
verify_response = requests.get(
    f"{url}?select=count",
    headers=headers
)
if verify_response.status_code == 200:
    print(f"✅ Supabase now has {len(verify_response.json())} tasks")