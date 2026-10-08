-- User Analysis
-- RetailRocket E-commerce Dataset

--Сколько событий в среднем приходится на одного пользователя?
SELECT 
    ROUND(
        COUNT(*):: numeric /  COUNT(DISTINCT visitorid), 2
        ) AS avg_events_per_user
FROM events;

-- Cколько пользователей совершили ровно одно событие за весь период?
SELECT COUNT(*) one_event_users FROM (SELECT 
    visitorid, 
    COUNT(*) AS event_count 
FROM events 
GROUP BY visitorid
HAVING COUNT(*) = 1) AS user_events;

-- Процент пользователей, совершивших ровно одно событие
SELECT ROUND(
    (
        SELECT COUNT(*)::numeric
        FROM (
            SELECT visitorid
            FROM events
            GROUP BY visitorid
            HAVING COUNT(*) = 1
        ) AS user_events
    )
    /
    (
        SELECT COUNT(DISTINCT visitorid)
        FROM events
    ) * 100,
    2
) AS one_event_user_percentage;

--Сколько событий приходится на пользователя: медиана, среднее, максимум?
SELECT
    MAX(count_events),
    ROUND(AVG(count_events), 2),
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY count_events)
FROM
    (
    SELECT 
        visitorid, 
        COUNT(*) AS count_events
    FROM events
    GROUP BY visitorid
    ) AS events_user
;

--Какой тип события был у пользователей, совершивших ровно одно событие за весь период?
WITH one_event_users AS (
    SELECT 
        visitorid
    FROM events
    GROUP BY visitorid
    HAVING COUNT(*) = 1
)
SELECT
    event,
    COUNT(*) AS users_count,
    ROUND(
        COUNT(*)::numeric /
        (
            SELECT COUNT(*)
            FROM one_event_users
        ) * 100,
        2
    ) AS percentage
FROM events
WHERE visitorid IN (
     SELECT visitorid
    FROM one_event_users
)
GROUP BY event;

-- Какую долю всех событий генерируют самые активные пользователи
WITH active_users AS (
    SELECT 
        visitorid, 
        COUNT(*) AS count_events
    FROM events
    GROUP BY visitorid
),
 rank_users AS (
    SELECT 
        visitorid, 
        count_events, 
        ROW_NUMBER() OVER(ORDER BY count_events DESC, visitorid) AS user_rank,
        COUNT(*) OVER() AS total_users
    FROM active_users
)
SELECT 
    ROUND(
        SUM(
            CASE 
                WHEN user_rank <= total_users * 0.01
                THEN count_events
                ELSE 0
            END
            ):: numeric / SUM(count_events) * 100, 2) AS top_1_prc,
    ROUND(
        SUM(
            CASE 
                WHEN user_rank <= total_users * 0.05
                THEN count_events
                ELSE 0
            END
            ):: numeric / SUM(count_events) * 100, 2) AS top_5_prc,
    ROUND(
        SUM(
            CASE 
                WHEN user_rank <= total_users * 0.10
                THEN count_events
                ELSE 0
            END
            ):: numeric / SUM(count_events) * 100, 2) AS top_10_prc
FROM rank_users;

--Распределение пользователей по активности
WITH user_activity AS (
    SELECT
        visitorid,
        COUNT(*) AS event_count
    FROM events
    GROUP BY visitorid
),
activity_segments AS (
    SELECT 
        visitorid,
        CASE
            WHEN event_count = 1 THEN '1 event'
            WHEN event_count BETWEEN 2 AND 5 THEN '2-5 events'
            WHEN event_count BETWEEN 6 AND 10 THEN '6-10 events'
            WHEN event_count BETWEEN 11 AND 50 THEN '11-50 events'
            WHEN event_count > 50 THEN '51+ events'
        END AS activities_group
    FROM user_activity
)
SELECT 
    activities_group, 
    COUNT(*) AS users_count, 
    ROUND(COUNT(*)::numeric / (SELECT COUNT(*) FROM user_activity) * 100, 2) AS persentage
FROM activity_segments
GROUP BY activities_group
ORDER BY 
    CASE activities_group
        WHEN '1 event' THEN 1
        WHEN '2-5 events' THEN 2
        WHEN '6-10 events' THEN 3
        WHEN '11-50 events' THEN 4
        WHEN '51+ events' THEN 5
    END
;
