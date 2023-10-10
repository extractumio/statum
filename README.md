# Statum: A Handy Web Analytics for Developing Websites

Statum is a simple yet handy web analytics tool developed by Extractum.io that parses web server log files, enriches them with web-based data and inserts pertinent details into an SQLite database. 
This enables quick analysis and reporting of web server activity.

## Features:
- Parses Nginx/Apache server logs.
- Filters and extracts relevant details like IP, method, URL, user-agent, etc.
- Categorizes user-agents into mobile, bot, and others.
- Enriches and augments local log file statistics with web-based javascript analytics and provide a comprehensive data on return visitors.

## Prerequisites:
1. Python 3.x
2. SQLite3 (comes with Python's standard library)
3. `is_bot` library - An external library for bot detection based on user-agent. Ensure it's installed and available.

## Web-based Installation:
To enhance the analytics with web-based javascript tracking, 
1. create an empty file statum.txt in the root folder of your webserver 
2. insert the following code in your web pages:
```html
<script src="/js/statum.js"></script>
```
The script will automatically detect the URL of the page and send a request to the Statum server. The server will parse the request and extract the relevant details. The details will be stored in the database and can be used for analytics.
This will enhance the analytics with user id, browser parameters (resolution, language, os) and "returned visitors" statistics.

> **Note:** place the /js/statum.js file in the corresponding directory of your web server.

## How to Run:
1. Place the script in a directory containing the log files (or modify the `LOG_ROOT` variable in the script to point to the directory containing the log files).
2. Ensure SQLite3 is installed and the Python environment is set up.
3. Install the necessary libraries:
```bash
pip install is_bot
```
4. Navigate to the directory containing the script and execute:
```bash
python statum.py --<option>
```

## Command-Line Options:
- `--today`: Only parse and import today's log files.
- `--full`: Parse and import all available log files. If the tables already exist in the database, they will be dropped and recreated.

## Output:
The script will process the log files and insert data into an SQLite3 database named `statum.db`. Two tables, namely `hits` and `ua`, will store the parsed data.

## Cron Job:
To automate the process, you can set up a cron job to run the script periodically. For example, to run the script every 30 minutes, add the following line to your crontab:
```bash
*/30 * * * * cd /home/statum && python3 ./statum.py --today && bash ./gen_stats.sh
```

> **Note 1:** update the home directory of statum with the relevant one, i.e. `/home/statum` in the above example.

> **Note 2:** gen_stats.sh will generate the statistics and save them in a file named .output ./statum_stats.txt in the same directory. You can use this file to display the statistics on a web page. 
> If you want to make this stats available on the web, change the path in the following line `.output ./statum_stats.txt`

## Notes:
- By default, the script looks for log files named with the prefix `access.log*` (like `access.log`, `access.log.1`, `access.log.2.gz`, etc.) in the directory specified by `LOG_ROOT`.
- The script efficiently handles `.gz` compressed log files.
- Ensure the SQLite3 database (`statum.db`) is backed up if you run the script with the `--full` option since it will recreate tables and any existing data will be lost.

## Author:
- Greg Z, 2023, info@extractum.io
- License: Apache 2.0

## Feedback & Contributions:
For feedback, issues, or contributions, please contact `info@extractum.io`.

## TODO
- Speed up log parsing by replacing is_bot library with a custom function.
