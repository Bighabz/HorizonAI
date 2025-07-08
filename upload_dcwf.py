#!/usr/bin/env python3
"""
DCWF Tasks Upload Script for AI Horizon
Run this in VSCode to upload your Excel file to Supabase
"""

import pandas as pd
import requests
import json
from typing import List, Dict
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration from .env file
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_KEY')

def read_dcwf_excel(file_path: str) -> pd.DataFrame:
    """Read DCWF tasks from Excel file"""
    try:
        # Read Excel file
        df = pd.read_excel(file_path)
        print(f"✅ Loaded {len(df)} rows from {file_path}")
        print(f"📋 Columns found: {', '.join(df.columns)}")
        return df
    except Exception as e:
        print(f"❌ Error reading Excel file: {e}")
        return None

def preview_data(df: pd.DataFrame):
    """Preview the data before upload"""
    print("\n📊 Data Preview:")
    print("-" * 50)
    print(df.head())
    print("-" * 50)
    print(f"\nTotal rows: {len(df)}")
    print(f"Columns: {list(df.columns)}")

def standardize_task_data(df: pd.DataFrame) -> List[Dict]:
    """Standardize task data for upload"""
    tasks = []
    
    # Common column name variations
    id_columns = ['Task ID', 'task_id', 'ID', 'id', 'Task_ID']
    name_columns = ['Task Name', 'task_name', 'Name', 'name', 'Task_Name', 'Task']
    role_columns = ['Work Role', 'work_role', 'Role', 'role', 'Work_Role']
    desc_columns = ['Description', 'description', 'Task Description', 'task_description', 'Details']
    cat_columns = ['Category', 'category', 'Type', 'type', 'Task Category']
    
    # Find actual column names
    id_col = next((col for col in id_columns if col in df.columns), None)
    name_col = next((col for col in name_columns if col in df.columns), None)
    role_col = next((col for col in role_columns if col in df.columns), None)
    desc_col = next((col for col in desc_columns if col in df.columns), None)
    cat_col = next((col for col in cat_columns if col in df.columns), None)
    
    if not id_col or not name_col:
        print("❌ Error: Could not find required columns (Task ID and Task Name)")
        print(f"   Available columns: {', '.join(df.columns)}")
        return []
    
    print(f"\n✅ Column mapping:")
    print(f"   Task ID: {id_col}")
    print(f"   Task Name: {name_col}")
    print(f"   Work Role: {role_col or 'Not found (using default)'}")
    print(f"   Description: {desc_col or 'Not found (using empty)'}")
    print(f"   Category: {cat_col or 'Not found (using default)'}")
    
    # Process each row
    for idx, row in df.iterrows():
        task_id = str(row[id_col]).strip() if pd.notna(row[id_col]) else None
        task_name = str(row[name_col]).strip() if pd.notna(row[name_col]) else None
        
        if not task_id or not task_name:
            continue
            
        task = {
            "task_id": task_id,
            "task_name": task_name,
            "work_role": str(row[role_col]).strip() if role_col and pd.notna(row.get(role_col)) else "General",
            "task_description": str(row[desc_col]).strip() if desc_col and pd.notna(row.get(desc_col)) else "",
            "category": str(row[cat_col]).strip() if cat_col and pd.notna(row.get(cat_col)) else "General"
        }
        tasks.append(task)
    
    print(f"\n✅ Prepared {len(tasks)} valid tasks for upload")
    return tasks

def upload_to_supabase(tasks: List[Dict], batch_size: int = 100):
    """Upload tasks to Supabase in batches"""
    if not SUPABASE_KEY or SUPABASE_KEY == "YOUR_NEW_SERVICE_KEY_AFTER_ROTATION":
        print("\n❌ Error: Please update SUPABASE_KEY in .env file!")
        print("   Current value suggests you haven't added your actual key.")
        return
    
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    
    total_uploaded = 0
    failed_batches = []
    
    print(f"\n📤 Starting upload to Supabase...")
    
    # Upload in batches
    for i in range(0, len(tasks), batch_size):
        batch = tasks[i:i + batch_size]
        batch_num = i // batch_size + 1
        
        try:
            response = requests.post(
                f"{SUPABASE_URL}/rest/v1/dcwf_tasks",
                headers=headers,
                json=batch
            )
            
            if response.status_code in [200, 201]:
                total_uploaded += len(batch)
                print(f"✅ Batch {batch_num}: Uploaded {len(batch)} tasks")
            else:
                failed_batches.append(batch_num)
                print(f"❌ Batch {batch_num}: Failed - {response.status_code}")
                print(f"   Error: {response.text[:200]}...")
                
        except Exception as e:
            failed_batches.append(batch_num)
            print(f"❌ Batch {batch_num}: Error - {e}")
    
    # Summary
    print(f"\n{'='*50}")
    print(f"📊 Upload Summary:")
    print(f"   Total tasks processed: {len(tasks)}")
    print(f"   Successfully uploaded: {total_uploaded}")
    print(f"   Failed batches: {len(failed_batches)}")
    if failed_batches:
        print(f"   Failed batch numbers: {failed_batches}")
    print(f"{'='*50}")

def generate_keyword_file(tasks: List[Dict]):
    """Generate keyword mappings file"""
    print("\n📝 Generating keyword mappings...")
    
    keywords = {}
    for task in tasks:
        task_id = task['task_id']
        # Extract keywords from task name and description
        text = f"{task['task_name']} {task['task_description']}".lower()
        words = [w for w in text.split() if len(w) > 3 and w.isalpha()]
        
        # Remove common words
        stop_words = {'this', 'that', 'with', 'from', 'have', 'will', 'their', 'there', 'these', 'those'}
        keywords[task_id] = {
            'keywords': list(set(words) - stop_words)[:10],
            'work_role': task['work_role'],
            'task_name': task['task_name']
        }
    
    # Save to file
    with open('dcwf_keywords.json', 'w') as f:
        json.dump(keywords, f, indent=2)
    
    print(f"✅ Saved keyword mappings to dcwf_keywords.json")
    print(f"   Total mappings: {len(keywords)}")

def main():
    """Main function"""
    print("🚀 AI Horizon DCWF Tasks Uploader")
    print("="*50)
    
    # Check environment
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("\n❌ Error: Missing environment variables!")
        print("   Please create a .env file with:")
        print("   SUPABASE_URL=your_supabase_url")
        print("   SUPABASE_KEY=your_service_key")
        return
    
    # Get file path
    excel_file = input("\n📁 Enter path to DCWF Excel file (or drag & drop): ").strip().strip('"')
    
    # Check if file exists
    if not os.path.exists(excel_file):
        print(f"\n❌ Error: File '{excel_file}' not found")
        return
    
    # Process
    print(f"\n1️⃣ Reading Excel file...")
    df = read_dcwf_excel(excel_file)
    if df is None:
        return
    
    # Preview data
    preview_data(df)
    
    # Ask to continue
    response = input("\n❓ Does this look correct? Continue? (y/n): ")
    if response.lower() != 'y':
        print("❌ Upload cancelled.")
        return
    
    print(f"\n2️⃣ Standardizing task data...")
    tasks = standardize_task_data(df)
    
    if not tasks:
        print("❌ No valid tasks found to upload.")
        return
    
    # Show sample
    print(f"\n📋 Sample task:")
    sample = tasks[0]
    for key, value in sample.items():
        print(f"   {key}: {value[:50]}..." if len(str(value)) > 50 else f"   {key}: {value}")
    
    # Confirm upload
    response = input(f"\n❓ Ready to upload {len(tasks)} tasks to Supabase? (y/n): ")
    if response.lower() != 'y':
        print("❌ Upload cancelled.")
        return
    
    print(f"\n3️⃣ Uploading to Supabase...")
    upload_to_supabase(tasks)
    
    print(f"\n4️⃣ Generating keyword mappings...")
    generate_keyword_file(tasks)
    
    print("\n✅ Process complete!")
    print("\n📌 Next steps:")
    print("1. Check Supabase to verify the upload")
    print("2. Test the n8n workflow with your Telegram bot")
    print("3. Send a YouTube link or document URL to analyze")

if __name__ == "__main__":
    main()