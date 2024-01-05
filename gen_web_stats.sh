#!/bin/bash

# Define the directory containing the files and the destination file
source_directory="./stat/"
destination_file="/home/llm_discover_web/www/stat/srep.html"

# Check if source directory exists
if [ ! -d "$source_directory" ]; then
    echo "Source directory does not exist."
    exit 1
fi

# Check if destination directory exists, create if not
destination_dir=$(dirname "$destination_file")
if [ ! -d "$destination_dir" ]; then
    mkdir -p "$destination_dir"
fi

# Combine the files
{
    echo -e "<html><head><style>table { margin-bottom: 30px; } h1 {font-size: 30px;} table, th, td {border: 0px none; font-family: Helvetica } th, td { padding: 3px 4px; text-align: left; }</style><meta name=\"robots\" content=\"noimageindex, nofollow, nosnippet\"></head><body>"
    date -u
    echo -e "<h1>Summary:</h1><table>"
    cat "${source_directory}statum_general.db"
    echo -e "</table>"
    echo -e "<h1>Referred Hosts:</h1><table>"
    cat "${source_directory}statum_ref_hosts.db"
    echo -e "</table>"
    echo -e "<h1>Referred Pages:</h1><table>"
    cat "${source_directory}statum_ref_pages.db"
    echo -e "</table>"
    echo -e "<h1>Popular Pages:</h1><table>"
    cat "${source_directory}statum_top_pages.db"
    echo -e "</table>"
    echo -e "<h1>HTTP Statuses:</h1><table>"
    cat "${source_directory}statum_http.db"
    echo -e "</table>"
    echo -e "<h1>TOP UA:<h1><table>"
    cat "${source_directory}statum_topua.db"
    echo -e "</table>"
    echo -e "</body></html>"
} > "$destination_file"

echo "Files combined into $destination_file"
