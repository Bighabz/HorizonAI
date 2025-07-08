#!/usr/bin/env python3
"""
DCWF Tasks Only Upload Script for AI Horizon
Upload ONLY cybersecurity tasks (NO KSAs) to Supabase
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

def read_dcwf_tasks_only(file_path: str) -> pd.DataFrame:
    """Read DCWF tasks only from Excel file"""
    try:
        # Read the tasks-only Excel file
        df = pd.read_excel(file_path)
        print(f"✅ Loaded {len(df)} tasks from {file_path}")
        print(f"📋 Columns found: {', '.join(df.columns)}")
        return df
    except Exception as e:
        print(f"❌ Error reading Excel file: {e}")
        return None

def preview_tasks_data(df: pd.DataFrame):
    """Preview the tasks data before upload"""
    print("\n📊 Tasks Data Preview:")
    print("-" * 50)
    print(df.head())
    print("-" * 50)
    print(f"\nTotal tasks: {len(df)}")
    print(f"Columns: {list(df.columns)}")
    
    # Show sample task descriptions
    if 'task_description' in df.columns:
        print("\n📝 Sample task descriptions:")
        for i in range(min(3, len(df))):
            row = df.iloc[i]
            print(f"  {row['task_id']}: {row['task_description'][:100]}...")

def prepare_tasks_for_upload(df: pd.DataFrame) -> List[Dict]:
    """Prepare tasks for upload to Supabase"""
    tasks = []
    
    required_columns = ['task_id', 'task_name', 'task_description', 'nist_sp_id']
    missing_columns = [col for col in required_columns if col not in df.columns]
    
    if missing_columns:
        print(f"❌ Error: Missing required columns: {missing_columns}")
        print(f"   Available columns: {', '.join(df.columns)}")
        return []
    
    print(f"\n✅ Column mapping:")
    print(f"   Task ID: task_id")
    print(f"   Task Name: task_name")
    print(f"   Task Description: task_description")
    print(f"   NIST SP ID: nist_sp_id")
    print(f"   Work Role: work_role")
    print(f"   Category: category")
    
    # Process each task
    for idx, row in df.iterrows():
        task_id = str(row['task_id']).strip() if pd.notna(row['task_id']) else None
        task_name = str(row['task_name']).strip() if pd.notna(row['task_name']) else None
        task_description = str(row['task_description']).strip() if pd.notna(row['task_description']) else None
        nist_sp_id = str(row['nist_sp_id']).strip() if pd.notna(row['nist_sp_id']) else None
        
        if not task_id or not task_name or not task_description:
            print(f"⚠️  Skipping row {idx}: missing essential data")
            continue
            
        task = {
            "task_id": task_id,
            "task_name": task_name,
            "task_description": task_description,
            "nist_sp_id": nist_sp_id,
            "work_role": str(row.get('work_role', 'General')).strip(),
            "category": str(row.get('category', 'Task')).strip()
        }
        tasks.append(task)
    
    print(f"\n✅ Prepared {len(tasks)} valid tasks for upload")
    return tasks

def upload_tasks_to_supabase(tasks: List[Dict], batch_size: int = 100):
    """Upload tasks to Supabase database"""
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
    
    # First, clear existing task data
    print(f"\n🧹 Clearing existing task data...")
    try:
        delete_response = requests.delete(
            f"{SUPABASE_URL}/rest/v1/dcwf_tasks",
            headers=headers
        )
        print(f"   Delete status: {delete_response.status_code}")
    except Exception as e:
        print(f"   Warning: Could not clear existing data: {e}")
    
    total_uploaded = 0
    failed_batches = []
    
    print(f"\n📤 Starting task upload to Supabase...")
    
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
    print(f"📊 Tasks Upload Summary:")
    print(f"   Total tasks processed: {len(tasks)}")
    print(f"   Successfully uploaded: {total_uploaded}")
    print(f"   Failed batches: {len(failed_batches)}")
    if failed_batches:
        print(f"   Failed batch numbers: {failed_batches}")
    print(f"{'='*50}")

def verify_upload(sample_size: int = 5):
    """Verify the upload by checking some sample tasks"""
    if not SUPABASE_KEY:
        print("\n❌ Cannot verify: Missing SUPABASE_KEY")
        return
    
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.get(
            f"{SUPABASE_URL}/rest/v1/dcwf_tasks?limit={sample_size}",
            headers=headers
        )
        
        if response.status_code == 200:
            tasks = response.json()
            print(f"\n✅ Verification: Found {len(tasks)} sample tasks in database")
            for task in tasks[:3]:
                print(f"   {task['task_id']}: {task['task_name']}")
        else:
            print(f"\n❌ Verification failed: {response.status_code}")
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"\n❌ Verification error: {e}")

def main():
    """Main function"""
    print("🚀 AI Horizon DCWF Tasks Only Uploader")
    print("="*50)
    print("📌 This script uploads ONLY cybersecurity tasks (NO KSAs)")
    
    # Check environment
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("\n❌ Error: Missing environment variables!")
        print("   Please create a .env file with:")
        print("   SUPABASE_URL=your_supabase_url")
        print("   SUPABASE_KEY=your_service_key")
        return
    
    # Use the tasks-only file
    tasks_file = "DCWF_Ready_Tasks.xlsx"
    
    # Check if file exists
    if not os.path.exists(tasks_file):
        print(f"\n❌ Error: File '{tasks_file}' not found")
        print("   Please run 'python extract_dcwf_tasks_only.py' first")
        return
    
    # Process
    print(f"\n1️⃣ Reading tasks-only Excel file...")
    df = read_dcwf_tasks_only(tasks_file)
    if df is None:
        return
    
    # Preview data
    preview_tasks_data(df)
    
    # Ask to continue
    response = input("\n❓ Does this look correct? Continue? (y/n): ")
    if response.lower() != 'y':
        print("❌ Upload cancelled.")
        return
    
    print(f"\n2️⃣ Preparing tasks for upload...")
    tasks = prepare_tasks_for_upload(df)
    
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
    
    print(f"\n3️⃣ Uploading tasks to Supabase...")
    upload_tasks_to_supabase(tasks)
    
    print(f"\n4️⃣ Verifying upload...")
    verify_upload()
    
    print("\n✅ Tasks upload complete!")
    print("\n📌 Next steps:")
    print("1. Update the workflow to use the new tasks-only database")
    print("2. Test the n8n workflow with task-only classification")
    print("3. Send a document to analyze for task-specific AI impact")

if __name__ == "__main__":
    main() 