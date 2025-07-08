import pandas as pd
import os

# Load the Excel file
file_path = input("Path to DCWFMASTER.xlsx: ").strip().strip('"')
excel = pd.ExcelFile(file_path)

# Show all sheets
print("\nAvailable sheets:")
for i, sheet in enumerate(excel.sheet_names):
    print(f"{i+1}. {sheet}")

# Choose sheet
choice = int(input("\nWhich sheet number? ")) - 1
df = pd.read_excel(file_path, sheet_name=excel.sheet_names[choice])

print(f"\nLoaded {len(df)} rows")
print(f"Columns: {list(df.columns)}")

# Create clean version
clean_df = pd.DataFrame()

# Map columns (you'll need to adjust based on what you see)
print("\nMapping columns...")
clean_df['Task ID'] = df.iloc[:, 0]  # First column
clean_df['Task Name'] = df.iloc[:, 1]  # Second column  
clean_df['Work Role'] = df.iloc[:, 2] if len(df.columns) > 2 else 'General'
clean_df['Category'] = df.iloc[:, 3] if len(df.columns) > 3 else 'General'

# Remove empty rows
clean_df = clean_df.dropna(subset=['Task ID', 'Task Name'])

# Save
clean_df.to_excel('DCWF_Ready.xlsx', index=False)
print(f"\nSaved {len(clean_df)} tasks to DCWF_Ready.xlsx")