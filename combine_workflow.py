#!/usr/bin/env python3
"""
Simple script to combine workflow parts into complete JSON file
"""

import os

# Read all parts in order
parts = ['workflow_part_aa', 'workflow_part_ab', 'workflow_part_ac', 
         'workflow_part_ad', 'workflow_part_ae', 'workflow_part_af', 
         'workflow_part_ag']

content = ""
for part in parts:
    if os.path.exists(part):
        with open(part, 'rb') as f:
            content += f.read().decode('utf-8')

# Write complete file
with open('ai_horizon_complete_workflow.json', 'w') as f:
    f.write(content)

print("✅ Workflow file created: ai_horizon_complete_workflow.json")
print(f"📏 File size: {len(content):,} bytes")
print("\n📋 Next steps:")
print("1. Download this file to your computer")
print("2. Go to https://n8n.waxmybot.com")
print("3. Click '+' → '...' → 'Import from file'")
print("4. Upload ai_horizon_complete_workflow.json")