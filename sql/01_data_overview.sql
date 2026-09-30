
-- 1. DATA OVERVIEW

-- Total number of events
SELECT 
    COUNT(*)
FROM events;

-- Number of unique visitors
SELECT 
    COUNT(DISTINCT visitorid) 
FROM events;

-- Число уникальных товаров (itemid) встречающихся в событиях
SELECT 
    COUNT(DISTINCT itemid) 
FROM events;

--Сколько событий каждого типа произошло за весь период?
SELECT 
    event,
    COUNT(*) 
FROM events 
GROUP BY event 
ORDER BY COUNT(*) DESC;

--Какой процент всех событий приходится на view, addtocart и transaction?
SELECT 
    event,
    COUNT(*), 
    ROUND(
        COUNT(*) * 100.0 /(SELECT COUNT(*) FROM events),2
        ) AS percentage 
FROM events 
GROUP BY event;

--Сколько уникальных пользователей совершало каждый тип события?
SELECT * 
FROM events 
LIMIT 5;
SELECT 
    event, 
    COUNT(DISTINCT visitorid) AS unique_users 
FROM events 
GROUP BY event;

--Какой процент всех уникальных пользователей совершал каждый тип события?
SELECT 
    event, 
    COUNT(DISTINCT visitorid) AS unique_users,
    ROUND(
        COUNT(DISTINCT visitorid) * 100.0 / (SELECT COUNT(DISTINCT visitorid) FROM events), 2
        ) AS persentage
FROM events 
GROUP BY event;

-- Минимальная и максимальная дата события в таблице events
SELECT 
    MIN(datetime), 
    MAX(datetime) 
FROM events;

-- Сколько событий приходится на один день
SELECT 
    datetime :: date AS event_date,
    COUNT(event) AS event_count
FROM events
GROUP BY datetime :: date 
ORDER BY event_date;