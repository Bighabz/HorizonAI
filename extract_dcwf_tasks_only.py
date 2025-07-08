#!/usr/bin/env python3
"""
Extract ONLY DCWF Tasks (NOT KSAs) from DCWFMASTER.xlsx
This script filters out KSAs and only keeps actual cybersecurity tasks
"""

import pandas as pd
import numpy as np

def extract_dcwf_tasks_only(file_path="DCWFMASTER.xlsx"):
    """Extract only DCWF tasks, filtering out KSAs"""
    print("🔍 Loading DCWFMASTER.xlsx to extract TASKS only...")
    
    # Load the Excel file
    df = pd.read_excel(file_path, sheet_name="Master Task & KSA List")
    print(f"📊 Original data: {len(df)} rows")
    print(f"📋 Columns: {list(df.columns)}")
    
    # Show first few rows to understand structure
    print("\n📝 First 5 rows:")
    print(df[['DCWF #', 'Task/KSA', 'NIST SP #']].head())
    
    # Filter to only include TASKS (not KSAs)
    print("\n🎯 Filtering to TASKS only...")
    
    # Check for task type indicator
    if 'Task/KSA' in df.columns:
        # First approach: look for task indicators in the description
        tasks_df = df.copy()
        
        # Filter based on NIST SP # column (T0xxx indicates tasks)
        if 'NIST SP #' in df.columns:
            tasks_df = tasks_df[tasks_df['NIST SP #'].astype(str).str.contains('T0', na=False)]
            print(f"   Found {len(tasks_df)} entries with T0xxx NIST SP codes")
        
        # Check if there's a description column in the unnamed columns
        # Look for the description column - it might be one of the unnamed columns
        desc_col = None
        for col in df.columns:
            if col.startswith('Unnamed:'):
                # Check if this column contains description-like content
                sample_values = df[col].dropna().astype(str).head(5)
                if any(len(str(val)) > 20 for val in sample_values):  # Long text suggests descriptions
                    desc_col = col
                    break
        
        if desc_col:
            print(f"   Found description column: {desc_col}")
            # Remove entries that start with knowledge/skill/ability indicators
            tasks_df = tasks_df[~tasks_df[desc_col].astype(str).str.lower().str.startswith(('knowledge of', 'skill in', 'ability to'), na=False)]
            print(f"   After removing KSA descriptions: {len(tasks_df)} entries")
            
        # Remove entries with KSA-style IDs (K0xxx, S0xxx, A0xxx)
        if 'DCWF #' in df.columns:
            tasks_df = tasks_df[~tasks_df['DCWF #'].astype(str).str.contains('^[KSA]0', na=False)]
            print(f"   After removing KSA IDs: {len(tasks_df)} entries")
    
    # Create clean task dataframe
    clean_tasks = pd.DataFrame()
    
    # Map columns properly
    clean_tasks['task_id'] = tasks_df['DCWF #'].astype(str)
    clean_tasks['task_name'] = tasks_df['Task/KSA'].astype(str)
    clean_tasks['nist_sp_id'] = tasks_df['NIST SP #'].astype(str)
    
    # Try to find the description column
    if desc_col:
        clean_tasks['task_description'] = tasks_df[desc_col].astype(str)
    else:
        clean_tasks['task_description'] = clean_tasks['task_name']  # Use task name as fallback
    
    # Set defaults for other columns
    clean_tasks['work_role'] = 'General'
    clean_tasks['category'] = 'Task'  # All are tasks
    
    # Clean the data
    print("\n🧹 Cleaning task data...")
    
    # Remove rows with missing essential data
    before = len(clean_tasks)
    clean_tasks = clean_tasks[clean_tasks['task_id'].notna()]
    clean_tasks = clean_tasks[clean_tasks['task_name'].notna()]
    clean_tasks = clean_tasks[clean_tasks['task_id'] != 'nan']
    clean_tasks = clean_tasks[clean_tasks['task_name'] != 'nan']
    clean_tasks = clean_tasks[clean_tasks['task_id'] != '']
    clean_tasks = clean_tasks[clean_tasks['task_name'] != '']
    after = len(clean_tasks)
    print(f"   Removed {before - after} empty/invalid rows")
    
    # Strip whitespace and clean up
    clean_tasks['task_id'] = clean_tasks['task_id'].str.strip()
    clean_tasks['task_name'] = clean_tasks['task_name'].str.strip()
    clean_tasks['task_description'] = clean_tasks['task_description'].str.strip()
    clean_tasks['nist_sp_id'] = clean_tasks['nist_sp_id'].str.strip()
    
    # Remove duplicates
    before = len(clean_tasks)
    clean_tasks = clean_tasks.drop_duplicates(subset=['task_id'])
    after = len(clean_tasks)
    print(f"   Removed {before - after} duplicate task IDs")
    
    # Final validation - only tasks with proper content
    clean_tasks = clean_tasks[clean_tasks['task_description'].str.len() > 5]
    
    print(f"\n✅ Final clean tasks: {len(clean_tasks)}")
    print("\n📋 Sample tasks:")
    for i in range(min(3, len(clean_tasks))):
        row = clean_tasks.iloc[i]
        print(f"  {row['task_id']}: {row['task_name'][:50]}...")
        print(f"    {row['task_description'][:100]}...")
        print(f"    NIST: {row['nist_sp_id']}")
        print()
    
    return clean_tasks

def save_tasks_for_workflow(tasks_df):
    """Save tasks in the format needed for the workflow"""
    print("\n💾 Saving tasks for workflow...")
    
    # Save full version with descriptions
    tasks_df.to_excel('DCWF_Tasks_Only.xlsx', index=False)
    tasks_df.to_csv('DCWF_Tasks_Only.csv', index=False)
    print(f"   Saved {len(tasks_df)} tasks to DCWF_Tasks_Only.xlsx")
    
    # Create simplified version for upload scripts
    upload_df = tasks_df[['task_id', 'task_name', 'task_description', 'nist_sp_id', 'work_role', 'category']].copy()
    upload_df.to_excel('DCWF_Ready_Tasks.xlsx', index=False)
    print(f"   Saved upload-ready version to DCWF_Ready_Tasks.xlsx")
    
    # Generate task keywords for AI classification
    print("\n🔍 Generating task keywords for AI classification...")
    keywords = {}
    for _, row in tasks_df.iterrows():
        task_id = row['task_id']
        text = f"{row['task_name']} {row['task_description']}".lower()
        words = [w for w in text.split() if len(w) > 3 and w.isalpha()]
        
        # Remove common stop words
        stop_words = {'this', 'that', 'with', 'from', 'have', 'will', 'their', 'there', 'these', 'those', 'information', 'security', 'system', 'systems', 'technology', 'data', 'management', 'processes', 'procedures', 'operations', 'activities', 'requirements', 'capabilities', 'personnel', 'resources', 'support', 'ensure', 'provide', 'maintain', 'develop', 'implement', 'conduct', 'perform', 'analyze', 'identify', 'establish', 'coordinate', 'manage', 'administrative', 'technical', 'operational'}
        
        keywords[task_id] = {
            'keywords': list(set(words) - stop_words)[:15],  # Top 15 keywords
            'task_name': row['task_name'],
            'nist_sp_id': row['nist_sp_id'],
            'description': row['task_description'][:200] + '...' if len(row['task_description']) > 200 else row['task_description']
        }
    
    # Save keywords file
    import json
    with open('dcwf_task_keywords.json', 'w') as f:
        json.dump(keywords, f, indent=2)
    print(f"   Saved keyword mappings to dcwf_task_keywords.json")

if __name__ == "__main__":
    print("🚀 DCWF Tasks Only Extractor")
    print("="*50)
    
    # Extract tasks only
    tasks_df = extract_dcwf_tasks_only()
    
    if len(tasks_df) > 0:
        # Save for workflow
        save_tasks_for_workflow(tasks_df)
        
        print("\n✅ Task extraction complete!")
        print(f"📊 {len(tasks_df)} cybersecurity tasks extracted (KSAs excluded)")
        print("\n📌 Files created:")
        print("   • DCWF_Tasks_Only.xlsx - Full task data with descriptions")
        print("   • DCWF_Ready_Tasks.xlsx - Upload-ready format")
        print("   • dcwf_task_keywords.json - Keywords for AI classification")
        print("\n🎯 Next steps:")
        print("   1. Upload tasks using the corrected upload script")
        print("   2. Update workflow to reference only tasks")
        print("   3. Test AI classification with task-only mapping")
    else:
        print("\n❌ No tasks found! Check the DCWFMASTER.xlsx file structure.") 