-- COHORT ANALYSIS


-- Размер когорт по неделе первого наблюдаемого события пользователя


WITH user_cohort AS (
    SELECT
        visitorid,
        MIN(datetime) AS first_seen_at,
        DATE_TRUNC('week', MIN(datetime)) AS cohort_week
    FROM events
    GROUP BY visitorid
)
SELECT
    cohort_week,
    COUNT(*) AS cohort_size
FROM user_cohort
GROUP BY cohort_week
ORDER BY cohort_week
;


-- Доля пользователей, совершивших любое событие в следующие недели W1–W4


WITH weekly_activity AS (
    SELECT
        DISTINCT visitorid,
        DATE_TRUNC('week', datetime) AS activity_week
    FROM events
),
user_cohort AS (
    SELECT
        visitorid,
        MIN(datetime) AS first_seen_at,
        DATE_TRUNC('week', MIN(datetime)) AS cohort_week
    FROM events
    GROUP BY visitorid
),
cohort_sizes AS (
    SELECT
        cohort_week,
        COUNT(*) AS cohort_size
    FROM user_cohort
    GROUP BY cohort_week
)
SELECT
    u.cohort_week,
    (w.activity_week::date - u.cohort_week::date) / 7 AS week_number,
    COUNT(*) AS returned_users,
    s.cohort_size,
    ROUND(100.0 * COUNT(*) / s.cohort_size, 2) AS retention_pct

FROM weekly_activity as w
JOIN user_cohort AS u
ON w.visitorid = u.visitorid
JOIN cohort_sizes AS s
ON u.cohort_week = s.cohort_week
WHERE (w.activity_week::date - u.cohort_week::date) / 7 BETWEEN 1 AND 4
AND w.activity_week < DATE_TRUNC('week', (SELECT MAX(datetime) FROM events))
AND u.cohort_week > DATE_TRUNC('week', (SELECT MIN(datetime) FROM events))
GROUP BY u.cohort_week, (w.activity_week::date - u.cohort_week::date) / 7, s.cohort_size
ORDER BY u.cohort_week, (w.activity_week::date - u.cohort_week::date) / 7
;
