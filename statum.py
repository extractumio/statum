# by Greg Z, 2023, info@extractum.io
import os
import re
import gzip
import sys
import sqlite3
import hashlib
import argparse
from datetime import datetime
from urllib.parse import parse_qs, unquote, urlparse
from is_bot import Bots

# ======================================================================================================================
# Change the following variables to suit your needs
# ======================================================================================================================

# the list of files to be processed from the log and stored in the database
EXTENSION_INCLUDES = r'\.(txt|html?|ico|php|phtml|php5|php7|py|pl|sh|cgi|shtml)$'
LOG_PATTERN = re.compile(
    r'(?P<ip>[\d.]+) - - \[(?P<date>.*?)\] "(?P<method>\w+) (?P<url>.*?) HTTP/.*?" (?P<status>\d+) (?P<size>\d+) ".*?" "(?P<user_agent>.*?)"'
)

LOG_ROOT = '/var/log/nginx'
#LOG_ROOT = './logs'

# The script will scan for access.log, access.log.1, access.log.2.gz, access.log.3.gz, etc.
LOG_FILENAME = 'access.log' # prefix of the log file name
# ======================================================================================================================

# to determine if the user agent is a mobile browser
regexp_mobile = re.compile(
    r"(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino",
    re.I | re.M)

def sanitize_string(s):
    # Remove all non-alphanumeric characters
    sanitized = re.sub(r'[^a-zA-Z0-9]', '', s)

    # Limit the length to 80 characters
    return sanitized[:80]

def detect_mobile_browser(user_agent):
    b = regexp_mobile.search(user_agent)
    if b:
        return True
    return False

print("Statum - Simple Yet Handy Web Analytics by Extractum.io")

# Argument parsing
parser = argparse.ArgumentParser(description="Parse WebServer Log Files.")
parser.add_argument('--today', action='store_true', help='Parse only today\'s log files.')
parser.add_argument('--full', action='store_true', help='Parse all log files.')

if len(sys.argv) == 1:  # No arguments provided
    parser.print_help(sys.stderr)
    sys.exit(1)

args = parser.parse_args()

# Database connection
conn = sqlite3.connect('db/statum.db')
cur = conn.cursor()

today = datetime.now().strftime('%Y-%m-%d')
bots = Bots()

# Processing based on arguments
if args.full:
    cur.execute('DROP TABLE IF EXISTS hits')
    cur.execute('DROP TABLE IF EXISTS ua')

cur.execute('''
CREATE TABLE IF NOT EXISTS hits (
    dt DATE,
    statum INTEGER,
    ip TEXT,
    ts INTEGER,
    method TEXT,
    url TEXT,
    params TEXT,
    ref TEXT,
    hash TEXT,
    size INTEGER,
    httpstatus INTEGER,
    user_agent_id TEXT,
    uid TEXT,
    resolution TEXT,
    language TEXT,
    os TEXT,
    FOREIGN KEY (user_agent_id) REFERENCES ua (hash)
)
''')

cur.execute('''
CREATE TABLE IF NOT EXISTS ua (
    hash TEXT PRIMARY KEY,
    ua TEXT,
    mobile INTEGER,
    bot INTEGER
)
''')

if args.today:
    cur.execute(f'DELETE FROM hits WHERE dt = ?', (today,))

# User agent dictionary
ua_dict = {}

# Record Counter
record_counter = 0

ua_inserts = []  # To keep track of user-agent inserts
hits_inserts = []  # To keep track of hit inserts

# Processing files
for root, dirs, files in os.walk(LOG_ROOT):
    for file in files:
        if args.today and file == LOG_FILENAME:  # When --recent, look for 'access_log' only
            filepath = os.path.join(root, file)
            print(f"Processing file: {filepath}")  # Show current processing file
            # proceed with further processing
        elif not args.today and file.startswith(LOG_FILENAME):  # Otherwise, proceed as before
            filepath = os.path.join(root, file)
            print(f"Processing file: {filepath}")  # Show current processing file
            # proceed with further processing
        else:
            continue
            
        # Open the file, decompressing it if necessary
        opener = gzip.open if filepath.endswith('.gz') else open
        with opener(filepath, 'rt') as log_file:
            for line in log_file:
                match = LOG_PATTERN.match(line)
                if match:
                    data = match.groupdict()

                    # Assuming match.group('request') contains the entire request string
                    request_parts = urlparse(data['url'])
                    data['url'] = request_parts.path  # extracting the path
                    data['ref'] = ''
                    data['uid'] = data['ip']

                    # default values for the case when the records are being extracted from local logs only
                    data['s'] = ''
                    data['l'] = ''
                    data['os'] = ''
                    data['statum'] = 0

                    # special case for statum record (HEAD /statum.txt)
                    if data['method'] == 'HEAD' and '/statum.txt' in data['url']:
                        data['method'] = 'GET'
                        parsed = parse_qs(request_parts.query)
                        data['statum'] = 1

                        # Decoding the URI and referrer
                        url = unquote(parsed['uri'][0]) if 'uri' in parsed else None
                        data['ref'] = unquote(parsed['r'][0]) if 'r' in parsed else None

                        if 's' in parsed:
                            data['s'] = parsed['s'][0]

                        if 'l' in parsed:
                            data['l'] = parsed['l'][0]

                        if 'os' in parsed:
                            data['os'] = parsed['os'][0]

                        if url:
                            request_parts = urlparse(url)
                            data['url'] = request_parts.path

                    if not re.search(EXTENSION_INCLUDES, data['url']):
                        if re.search(r'\.\w{1,5}$', data['url']):
                            continue

                    # Parameters
                    data['params'] = ''
                    if request_parts.query:
                        data['params'] = '?' + request_parts.query

                    data['hash'] = ''
                    # extract the part after # and before ?
                    if request_parts.fragment:
                        data['hash'] = '#' + request_parts.fragment

                    date_str = data['date'].split()[0]
                    dt = datetime.strptime(date_str, '%d/%b/%Y:%H:%M:%S')

                    data['dt'] = dt.strftime('%Y-%m-%d')
                    data['ts'] = int(dt.timestamp())

                    ua = data['user_agent']
                    ua_hash = hashlib.sha256(ua.encode()).hexdigest()[:12]
                    mobile = 1 if detect_mobile_browser(ua) else 0
                    bot = 1 if bots.is_bot(ua) else 0

                    if ua_hash not in ua_dict:
                        ua_inserts.append((ua_hash, ua, mobile, bot))
                        ua_dict[ua_hash] = None

                    data['user_agent_id'] = ua_hash

                    hits_inserts.append((data['ip'], data['statum'], data['dt'], data['ts'], data['method'], data['url'],
                                        data['params'], data['ref'], data['hash'], data['size'], data['status'], data['user_agent_id'],
                                        data['uid'], data['s'], data['l'], data['os']))

                    # Consider inserting data in chunks to avoid memory issues
                    if len(hits_inserts) >= 1000:
                        cur.executemany('INSERT OR IGNORE INTO ua (hash, ua, mobile, bot) VALUES (?, ?, ?, ?)', ua_inserts)
                        cur.executemany('''
                            INSERT OR IGNORE INTO hits (ip, statum, dt, ts, method, url, params, ref, hash, size, httpstatus, user_agent_id, uid, resolution, language, os)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ''', hits_inserts)

                        record_counter += len(hits_inserts)  # Increase record counter

                        ua_inserts.clear()
                        hits_inserts.clear()
                        conn.commit()

        if args.today:
            print(f"Records imported for today ({today}): {record_counter}")  # Show number of records imported today
        else:
            print(f"Records imported so far: {record_counter}")  # Show number of records imported by far

# If any data remains, insert them
if ua_inserts:
    cur.executemany('INSERT OR IGNORE INTO ua (hash, ua, mobile, bot) VALUES (?, ?, ?, ?)', ua_inserts)

if hits_inserts:
    cur.executemany('''
        INSERT OR IGNORE INTO hits (ip, statum, dt, ts, method, url, params, ref, hash, size, httpstatus, user_agent_id, uid, resolution, language, os)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', hits_inserts)

record_counter += len(hits_inserts)  # Increase record counter

conn.commit()
conn.close()

print(f"Records imported total: {record_counter}")  # Show number of records imported by far

# The End
