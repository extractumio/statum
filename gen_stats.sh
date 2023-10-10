sqlite3 ./db/statum.db <<EOF
.mode tabs
.output ./statum_stats.txt
.headers on
.mode tabs
WITH FirstVisit AS (
    SELECT
        uid,
        MIN(dt) as first_date
    FROM hits
    WHERE statum = 1
    GROUP BY uid
),

ReturnVisitors AS (
    SELECT
        h.uid,
        fv.first_date,
        h.dt as return_date
    FROM hits h
    JOIN FirstVisit fv ON h.uid = fv.uid
    WHERE h.dt > fv.first_date AND h.statum = 1
)

SELECT
    h.dt,
    COUNT(DISTINCT CASE WHEN ua.bot = 0 THEN h.uid ELSE NULL END) as human_uids,
    COUNT(DISTINCT h.uid) as total_uids,
    COUNT(DISTINCT h.user_agent_id) as total_uas,
    COUNT() as hits,
    COUNT(DISTINCT CASE WHEN rv.return_date IS NOT NULL THEN h.uid ELSE NULL END) AS returns_total,
    COUNT(DISTINCT CASE WHEN rv.return_date IS NOT NULL AND julianday(h.dt) - julianday(rv.first_date) <= 30 THEN h.uid ELSE NULL END) AS returns_months,
    COUNT(DISTINCT CASE WHEN rv.return_date IS NOT NULL AND julianday(h.dt) - julianday(rv.first_date) <= 7 THEN h.uid ELSE NULL END) AS returns_week
FROM hits h
LEFT JOIN ua ON h.user_agent_id = ua.hash
LEFT JOIN ReturnVisitors rv ON h.uid = rv.uid AND h.dt = rv.return_date
WHERE h.dt BETWEEN date('now', '-30 days') AND date('now')
AND h.statum = 1
GROUP BY h.dt;
EOF
