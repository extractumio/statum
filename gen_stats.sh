#!/bin/bash

# Define the directory containing the files and the destination file
DATABASE_FILE="./db/statum.db"
OUTPUT_FOLDER="./stat/"
REPORT_FILE="./web_stats.html"
# replace it with your domain to exclude from referrers
HOSTNAME="mydomain.com"
# How many days to show in the stats
MAX_STATS_DAYS=8
# How many results to show in the stats
MAX_RESULTS=50

# The summary stats on hits, ips, visitors, user agents, returns
sqlite3 ${DATABASE_FILE} <<EOF
.output ${OUTPUT_FOLDER}/statum_general.db
.headers on
.mode html
WITH DateRange AS (
    SELECT date('now', '-${MAX_STATS_DAYS} days') AS start_date, date('now') AS end_date
),

FirstVisit AS (
    SELECT uid, MIN(dt) as first_date
    FROM hits
    WHERE statum = 1
    GROUP BY uid
),

ReturnVisitors AS (
    SELECT h.uid, fv.first_date, h.dt as return_date
    FROM hits h
    JOIN FirstVisit fv ON h.uid = fv.uid
    WHERE h.dt > fv.first_date AND h.statum = 1
)

SELECT
    h.dt,
    COUNT(DISTINCT CASE WHEN ua.bot = 0 THEN h.uid ELSE NULL END) as humans_total,
    COUNT(DISTINCT h.uid) as visitors_total,
    COUNT(DISTINCT h.user_agent_id) as total_ua,
    (SELECT COUNT() FROM hits WHERE dt = h.dt) as hits_total,
    COUNT(DISTINCT CASE WHEN rv.return_date IS NOT NULL THEN h.uid ELSE NULL END) AS returns_total,
    COUNT(DISTINCT CASE WHEN rv.return_date IS NOT NULL AND julianday(h.dt) - julianday(rv.first_date) <= 30 THEN h.uid ELSE NULL END) AS visited_months,
    COUNT(DISTINCT CASE WHEN rv.return_date IS NOT NULL AND julianday(h.dt) - julianday(rv.first_date) <= 7 THEN h.uid ELSE NULL END) AS visited_weeks
FROM hits h
LEFT JOIN ua ON h.user_agent_id = ua.hash
LEFT JOIN ReturnVisitors rv ON h.uid = rv.uid AND h.dt = rv.return_date
INNER JOIN DateRange dr ON h.dt BETWEEN dr.start_date AND dr.end_date
WHERE h.statum = 1
GROUP BY h.dt;
EOF

# The list of hosts that brought visitors
sqlite3 ${DATABASE_FILE} <<EOF
.output ${OUTPUT_FOLDER}/statum_ref_hosts.db
.headers on
.mode html
WITH raw_2days AS (
SELECT
    h.ip as ip,
    h.dt as dt,
		h.url as url,
		h.ref as ref,
COALESCE(
    NULLIF(
        replace(
            substr(
                ref,
                instr(ref, '//') + 2,
                case
                    when instr(substr(ref, instr(ref, '//') + 2), '/') = 0 then length(ref)
                    else instr(substr(ref, instr(ref, '//') + 2), '/') - 1
                end
            ),
            'www.', ''
        ),
        ''
    ),
    '[empty]'
  ) as host
FROM hits h
LEFT JOIN ua ON h.user_agent_id = ua.hash
WHERE
    h.dt BETWEEN date('now', '-1 days') and date('now')
		AND
		h.statum = 1
		AND
		ua.bot = 0
)

SELECT COUNT(*) as hits, COUNT(DISTINCT ip) as visitor_ips, COUNT(DISTINCT url) as pages_unique, host, MIN(dt), MAX(dt)
FROM raw_2days
WHERE host NOT LIKE '%${HOSTNAME}%'
GROUP BY host ORDER BY visitor_ips DESC LIMIT 50;
EOF

# The list of pages which had the most referals
sqlite3 ${DATABASE_FILE} <<EOF
.output ${OUTPUT_FOLDER}/statum_ref_pages.db
.headers on
.mode html
WITH raw_2days AS (
SELECT
    h.dt as dt,
    h.ip as ip,
		h.ref as referrer_url
FROM hits h
LEFT JOIN ua ON h.user_agent_id = ua.hash
WHERE
    h.dt BETWEEN date('now', '-1 days') and date('now')
		AND
		h.statum = 1
		AND
		ua.bot = 0
)

SELECT COUNT(*) as hits, COUNT(DISTINCT ip) as visitors_ips, referrer_url, MIN(dt), MAX(dt)
FROM raw_2days
WHERE referrer_url NOT LIKE '%${HOSTNAME}%'
GROUP BY referrer_url ORDER BY hits DESC LIMIT ${MAX_RESULTS};
EOF

# The list of popular pages by ip count
sqlite3 ${DATABASE_FILE} <<EOF
.output ${OUTPUT_FOLDER}/statum_top_pages.db
.headers on
.mode html
WITH raw_2days AS (
SELECT
    h.dt as dt,
    h.ip as ip,
    h.url || h.params as url,
		h.ref as ref
FROM hits h
LEFT JOIN ua ON h.user_agent_id = ua.hash
WHERE
    h.dt BETWEEN date('now', '-1 days') and date('now')
		AND
		h.statum = 1
		AND
		ua.bot = 0
)

SELECT url, COUNT(*) as num, COUNT(DISTINCT ip) as visitors_ips
FROM raw_2days
GROUP BY url ORDER BY visitors_ips DESC LIMIT ${MAX_RESULTS};
EOF

# The list of page statuses
sqlite3 ${DATABASE_FILE} <<EOF
.output ${OUTPUT_FOLDER}/statum_http.db
.headers on
.mode html
SELECT
    dt,
    COUNT(CASE WHEN httpstatus = '200' THEN 1 END) AS status_200,
    COUNT(CASE WHEN httpstatus = '301' THEN 1 END) AS status_301,
    COUNT(CASE WHEN httpstatus = '304' THEN 1 END) AS status_304,
    COUNT(CASE WHEN httpstatus = '403' THEN 1 END) AS status_403,
    COUNT(CASE WHEN httpstatus = '404' THEN 1 END) AS status_404,
    COUNT(CASE WHEN httpstatus = '405' THEN 1 END) AS status_405,
    COUNT(CASE WHEN httpstatus = '499' THEN 1 END) AS status_499,
    COUNT(CASE WHEN httpstatus = '500' THEN 1 END) AS status_500,
    COUNT(CASE WHEN httpstatus = '502' THEN 1 END) AS status_502,
    COUNT(CASE WHEN httpstatus = '503' THEN 1 END) AS status_503,
    COUNT(*) as total
FROM hits
WHERE
    dt BETWEEN date('now', '-1 days') AND date('now')
GROUP BY dt
ORDER BY dt;
EOF

# The list of top user agents
sqlite3 ${DATABASE_FILE} <<EOF
.output ${OUTPUT_FOLDER}/statum_topua.db
.headers on
.mode html
SELECT
    h.user_agent_id,
    COUNT() AS c,
    COUNT(DISTINCT ip) as ip_count,
    ua.ua AS user_agent_name,
    ua.bot as is_bot
FROM hits h
JOIN ua ON h.user_agent_id = ua.hash
WHERE h.dt BETWEEN DATE(date('now'), '-1 days') AND date('now')
GROUP BY h.user_agent_id, ua.ua, ua.bot
ORDER BY c DESC
LIMIT 50;
EOF



# Check if source directory exists
if [ ! -d "$OUTPUT_FOLDER" ]; then
    echo "Source directory does not exist."
    exit 1
fi

# Check if destination directory exists, create if not
destination_dir=$(dirname "$REPORT_FILE")
if [ ! -d "$destination_dir" ]; then
    mkdir -p "$destination_dir"
fi

# Combine the files
{
    echo -e "<html><head><style>table { margin-bottom: 30px; } h1 {font-size: 30px;} table, th, td {border: 0px none; font-family: Helvetica } th, td { padding: 3px 4px; text-align: left; }</style><meta name=\"robots\" content=\"noimageindex, nofollow, nosnippet\"></head><body>"
    date -u
    echo -e "<h1>Summary:</h1><table>"
    cat "${OUTPUT_FOLDER}statum_general.db"
    echo -e "</table>"
    echo -e "<h1>Referred Hosts:</h1><table>"
    cat "${OUTPUT_FOLDER}statum_ref_hosts.db"
    echo -e "</table>"
    echo -e "<h1>Referred Pages:</h1><table>"
    cat "${OUTPUT_FOLDER}statum_ref_pages.db"
    echo -e "</table>"
    echo -e "<h1>Popular Pages:</h1><table>"
    cat "${OUTPUT_FOLDER}statum_top_pages.db"
    echo -e "</table>"
    echo -e "<h1>HTTP Statuses:</h1><table>"
    cat "${OUTPUT_FOLDER}statum_http.db"
    echo -e "</table>"
    echo -e "<h1>TOP UA:<h1><table>"
    cat "${OUTPUT_FOLDER}statum_topua.db"
    echo -e "</table>"
    echo -e "</body></html>"
} > "$REPORT_FILE"

echo "Web analytics file $REPORT_FILE is ready"
