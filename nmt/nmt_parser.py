import re
import os
import pandas as pd
import glob
import matplotlib.pyplot as plt
from datetime import datetime
import argparse
from pathlib import Path

def parse_nmt_file(file_content):
    # Regex patterns for total and categories
    total_pattern = r"Total: reserved=(\d+KB) \+\d+KB, committed=(\d+KB) \+\d+KB"
    category_pattern = r"-\s+(\S.+)\s+\(reserved=(\d+KB)[^,]*, committed=(\d+KB)[^)]*\)"

    # Parse total reserved and committed
    total_match = re.search(total_pattern, file_content)
    total_reserved, total_committed = total_match.groups() if total_match else (None, None)

    # Parse categories
    categories = []
    for match in re.finditer(category_pattern, file_content):
        category, reserved, committed = match.groups()
        if category.strip() != "Java Heap":
            categories.append({
                'Category': category.strip(),
                'Reserved': reserved,
                'Committed': committed
            })

    return {
        'TotalReserved': total_reserved,
        'TotalCommitted': total_committed,
        'Categories': categories
    }

#Volvo "nmt_11202024.00/00/01.txt"
def extract_timestamp_from_filename(filename):
    # Extract the date and time portion from the filename
    match = re.search(r"nmt_(\d{8})\.(\d{2}):(\d{2}):(\d{2})\.txt", filename)
    if match:
        date_str, hour, minute, second = match.groups()
        # Format to datetime object
        return datetime.strptime(f"{date_str} {hour}:{minute}:{second}", "%m%d%Y %H:%M:%S")
    else:
        raise ValueError(f"Filename {filename} does not match expected pattern")

#Airbus AirNavX "11-25-2024-12H-01M-fr0-viaas-5890"
def extract_timestamp_from_filename2(filename): 
    # Extract the date and time portion from the filename
    match = re.search(r"(\d{2})-(\d{2})-(\d{4})-(\d{2})H-(\d{2})M-(.*)$", filename)
    if match:
        month, day, year, hour, minute, host = match.groups()
        return datetime.strptime(f"{month}{day}{year} {hour}:{minute}", "%m%d%Y %H:%M"), host
    else:
        raise ValueError(f"Filename {filename} does not match expected pattern")

def process_files(file_pattern):
    data = []
    print(file_pattern)
    for file_path in glob.glob(file_pattern):
        if os.path.isfile(file_path): 
            print(file_path)
            with open(file_path, 'r') as file:
                content = file.read()
                parsed_data = parse_nmt_file(content)
                timestamp, host = extract_timestamp_from_filename2(file_path)
                for category in parsed_data['Categories']:
                    data.append({
                        'Timestamp': timestamp,
                        'Category': category['Category'],
                        'Reserved': int(category['Reserved'].replace('KB', '')),
                        'Committed': int(category['Committed'].replace('KB', '')),
                        'Host': host
                    })
    return pd.DataFrame(data)

def plot(df, host:str, value_col: str, output_dir: str, stacked = True):
    # Filter data for the current host
    df_host = df[df['Host'] == host]
    # Pivot the data
    df_pivot = df_host.pivot(index='Timestamp', columns='Category', values=value_col)
    # Sort the columns by their maximum values in descending order
    df_pivot = df_pivot[df_pivot.max().sort_values(ascending=False).index]

    file_suffix=".png"
    title_suffix=""
    if stacked:
        file_suffix = "_stacked.png"
        title_suffix =  "(stacked)"

    # Plot the data
    if stacked:
        df_pivot.plot.area(figsize=(12, 6), stacked=stacked)
    else:
        df_pivot.plot(figsize=(12, 6))
    plt.title(f'{value_col} Native Memory Usage Over Time for {host}, by category {title_suffix}')
    plt.ylabel(f'{value_col} Memory (KB)')
    plt.xlabel('Timestamp')
    plt.legend(title="Category", loc='upper left', bbox_to_anchor=(1, 1))
    plt.grid(True)
    # plt.show()
    filename = os.path.join(output_dir, f"{host}_{value_col}_memory_usage{file_suffix}")
    plt.savefig(filename, format='png', dpi=300, bbox_inches='tight')
    plt.close() 

def main():
    parser = argparse.ArgumentParser(description="A script to plot a memory usage timeline from Java NMT files.")
    parser.add_argument(
        "--fromdir", 
        type=Path,  
        required=True, 
        help="directory where the NMT reports are located" 
    )
    parser.add_argument(
        "--stacked",  # The boolean flag
        action="store_true",  # Set to True if '--stacked' is provided
        help="Indicates if the chart is stacked (defaults to False if not provided)"
    )
    parser.add_argument(
        "--value",  # The option name
        choices=["committed", "reserved"],  # Restrict to these two choices
        default="reserved",
        help="Memory Value to plot, either 'committed' or 'reserved'"
    )
    args = parser.parse_args()
    if not args.fromdir.exists():
        print(f"Error: The path '{args.dir}' does not exist.")
        return
    if not args.fromdir.is_dir():
        print(f"Error: The path '{args.dir}' is not a directory.")
        return
    input_dir=args.fromdir.resolve()
    file_pattern = f"{input_dir}/*"
    output_dir=f"{input_dir}/output"
    os.makedirs(output_dir, exist_ok=True)

    # Process files and generate a dataframe
    df = process_files(file_pattern)
    # Save to CSV for easy plotting in tools like Excel
    df.to_csv(f"{output_dir}/nmt_df.csv", index=False)

    # Plot with matplotlib
    print(df)
    hosts = df['Host'].unique()
    for host in hosts:
        # for col in ['Committed', 'Reserved']:
            plot(df, host, args.value.capitalize(), output_dir, stacked=args.stacked)


if __name__ == "__main__":
    main()