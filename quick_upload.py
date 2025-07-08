import pandas as pd
import requests
import os
from dotenv import load_dotenv

load_dotenv()

# Load prepared file
df = pd.read_excel('DCWF_Ready.xlsx')
print(f"Loading {len(df)} tasks...")

# Convert to list of dicts
tasks = df.to_dict('records')

# Upload
url = f"{os.getenv('SUPABASE_URL')}/rest/v1/dcwf_tasks"
headers = {
    "apikey": os.getenv('SUPABASE_KEY'),
    "Authorization": f"Bearer {os.getenv('SUPABASE_KEY')}",
    "Content-Type": "application/json"
}

# Upload in batches of 100
for i in range(0, len(tasks), 100):
    batch = tasks[i:i+100]
    response = requests.post(url, json=batch, headers=headers)
    if response.status_code in [200, 201]:
        print(f"✓ Uploaded batch {i//100 + 1}")
    else:
        print(f"✗ Error: {response.text}")

print("Done!")