import pandas as pd
import numpy as np

# Load the Excel file
print("Loading DCWFMASTER.xlsx...")
df = pd.read_excel(r"C:\Users\habib\Downloads\DCWFMASTER.xlsx", sheet_name="Master Task & KSA List")

print(f"\nOriginal data: {len(df)} rows")
print(f"Columns: {list(df.columns)}")

# Show first few rows to understand the structure
print("\nFirst 5 rows:")
print(df[['DCWF #', 'Task/KSA']].head())

# Create clean dataframe
clean_df = pd.DataFrame()

# Map the columns correctly
clean_df['Task ID'] = df['DCWF #'].astype(str)
clean_df['Task Name'] = df['Task/KSA'].astype(str)
clean_df['Work Role'] = 'General'  # Default value
clean_df['Category'] = 'General'   # Default value

# Clean the data
print("\n🧹 Cleaning data...")

# Remove rows where Task ID or Task Name is NaN or 'nan'
before = len(clean_df)
clean_df = clean_df[clean_df['Task ID'].notna()]
clean_df = clean_df[clean_df['Task Name'].notna()]
clean_df = clean_df[clean_df['Task ID'] != 'nan']
clean_df = clean_df[clean_df['Task Name'] != 'nan']
clean_df = clean_df[clean_df['Task ID'] != '']
clean_df = clean_df[clean_df['Task Name'] != '']
after = len(clean_df)
print(f"   Removed {before - after} empty rows")

# Strip whitespace
clean_df['Task ID'] = clean_df['Task ID'].str.strip()
clean_df['Task Name'] = clean_df['Task Name'].str.strip()

# Remove any remaining NaN values
clean_df = clean_df.fillna('')

# Final check - no NaN values
print(f"\n✅ Final data: {len(clean_df)} clean tasks")
print("\nSample tasks:")
print(clean_df.head(3))

# Save to Excel
clean_df.to_excel('DCWF_Clean.xlsx', index=False)
print(f"\n💾 Saved to DCWF_Clean.xlsx")

# Also save as CSV for easier debugging
clean_df.to_csv('DCWF_Clean.csv', index=False)
print(f"💾 Also saved as DCWF_Clean.csv")