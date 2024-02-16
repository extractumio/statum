# Statum: A User Friendly Web Analytics for Developing Websites

Statum, developed by Extractum.io, is a open-source user-friendly web analytics tool that leverages both web-server logs and client-side collected statistics. 
This dual-source approach offers a comprehensive view of a website's traffic, facilitating swift analysis and reporting on various aspects such as visitor activity, page errors, and more.

Notably, Statum is designed for easy installation and use. It functions effectively as a standalone tool or in conjunction with other web analytics tools, like Google Analytics.

And it's free.

![alt text](logo/statum.webp "Statum")

## Features:
- Parses Nginx/Apache server logs.
- Filters and extracts relevant details like IP, method, URL, user-agent, etc.
- Categorizes user-agents into mobile, bot, and others.
- Enriches and augments local log file statistics on web traffic with web-based javascript analytics and provide a comprehensive data on return visitors.
- HTML report with statistics on web traffic, return visitors, and more.

## Prerequisites:
1. Python 3.x
2. SQLite3 (comes with Python's standard library)
3. `is_bot` library - An external library for bot detection based on user-agent. 

## Client-side Installation for Enhanced Analytics:
To enhance the analytics with web-based javascript tracking, 
1. create an empty file statum.txt in the root folder of your webserver 
2. insert the following code in your web pages:
```html
<script src="/js/statum.js"></script>
```
The script will automatically detect the URL of the page and send a request to the Statum server. The server will parse the request and extract the relevant details. The details will be stored in the database and can be used for analytics.
This will enhance the analytics with user id, browser parameters (resolution, language, os) and "returned visitors" statistics.

> **Note:** place the /js/statum.js file in the corresponding directory of your web server.

## How to Run Statum for Statistics Collection:
1. Update the following variables in the statum.py script according to your web server logs location and format (default is nginx format):
```
EXTENSION_INCLUDES = r'\.(txt|html?|ico|php|phtml|php5|php7|py|pl|sh|cgi|shtml)$'
LOG_PATTERN = re.compile(
    r'(?P<ip>[\d.]+) - - \[(?P<date>.*?)\] "(?P<method>\w+) (?P<url>.*?) HTTP/.*?" (?P<status>\d+) (?P<size>\d+) ".*?" "(?P<user_agent>.*?)"'
)
LOG_ROOT = '/var/log/nginx'
LOG_FILENAME = 'access.log'
```
and specify the location of the database file (the file will be created during the first run):
```
PATH_TO_DATABASE = 'db/statum.db'
```
2. Ensure SQLite3 is installed and the Python environment is set up.
3. Install the requirements:
```bash
pip install -r requirements.txt
```
4. Navigate to the directory containing the script and execute:
```bash
python statum.py --full
```
## How to Run Statum for Report Generation
To generate the statistics, update the path and the hostname in `gen_stats.sh`:
```
DATABASE_FILE="./db/statum.db"
OUTPUT_FOLDER="./stat/"
REPORT_FILE="./web_stats.html"
HOSTNAME="mydomain.com"
```

and run the script:
 ```bash
 ./gen_stats.sh
 ```
It will generate intermediate .db files (html cache) and the resultant statistics in the `OUTPUT_FOLDER` directory.

6. Open the `REPORT_FILE` in a browser to view the statistics.

## Command-Line Options:
- `--today`: Only parse and import today's log files.
- `--full`: Parse and import all available log files. If the tables already exist in the database, they will be dropped and recreated.
- `--missing`: Incremental update of the database with the missing log files. This option is useful if you want to update the database with the latest log files without reprocessing the entire log files.   

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
- Gregory Z
- License: Apache 2.0

## Feedback & Contributions:
For feedback, issues, or contributions, please contact `info@extractum.io`.

## TODO
- Speed up log parsing by replacing is_bot library with a custom function.
