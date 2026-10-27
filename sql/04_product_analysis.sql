-- PRODUCT ANALYSIS

-- Топ 10 товаров с уникальными зрителями

SELECT
    itemid,
    COUNT(*) AS view_events,
    COUNT(DISTINCT visitorid) AS unique_viewers
FROM events
WHERE event = 'view'
GROUP BY itemid
ORDER BY
    unique_viewers DESC,
    view_events DESC,
    itemid
LIMIT 10
;


-- Топ-10 покупаемых товаров

SELECT
    itemid,
    COUNT(*) AS trans_events,
    COUNT(DISTINCT visitorid) AS unique_buyers
FROM events
WHERE event = 'transaction'
GROUP BY itemid
ORDER BY
    unique_buyers DESC,
    trans_events DESC,
    itemid
LIMIT 10
;

-- Топ-10 добавляемых в корзину товаров

SELECT
    itemid,
    COUNT(*) AS to_cart_events,
    COUNT(DISTINCT visitorid) AS unique_to_cart_users
FROM events
WHERE event = 'addtocart'
GROUP BY itemid
ORDER BY
    unique_to_cart_users DESC,
    to_cart_events DESC,
    itemid
LIMIT 10
;

-- Общая таблица по товарам

SELECT
    itemid,
    SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
    SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
    SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
FROM events
GROUP BY itemid
;

-- Итоги таблицы

WITH product_events AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
        SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
        SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
    FROM events
    GROUP BY itemid
)
SELECT
    COUNT(*) AS count_items,
    SUM(view_events) AS sum_view_events,
    SUM(addtocart_events) AS sum_addtocart_events,
    SUM(trans_events) AS sum_trans_events
FROM product_events
;


-- Охват товаров по этапам

WITH product_events AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
        SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
        SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
    FROM events
    GROUP BY itemid
)
SELECT
    SUM(CASE WHEN view_events > 0 THEN 1 ELSE 0 END) AS items_with_view,
    SUM(CASE WHEN addtocart_events > 0 THEN 1 ELSE 0 END) AS items_with_addtocart,
    SUM(CASE WHEN trans_events > 0 THEN 1 ELSE 0 END) AS items_with_transaction
FROM product_events
;

-- Оценка концентрации просмотров
WITH product_events AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
        SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
        SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
    FROM events
    GROUP BY itemid
),
top_10_view AS (
    SELECT
        itemid,
        view_events
    FROM product_events
    ORDER BY
        view_events DESC,
        itemid
    LIMIT 10
)
SELECT ROUND(
    (SELECT
    SUM(view_events) AS sum_top10_view_events
FROM top_10_view)::numeric /
(SELECT
    SUM(view_events)
FROM product_events ) * 100, 2
    ) AS pct_view_events
;

-- Доля просмотров топ-1%

WITH product_events AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
        SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
        SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
    FROM events
    GROUP BY itemid
),
ranked_items AS (
    SELECT
        itemid,
        view_events,
        ROW_NUMBER() OVER(ORDER BY view_events DESC, itemid) as item_rank,
        COUNT(*) OVER () AS total_items
    FROM product_events
)
SELECT
    SUM(CASE WHEN item_rank <= total_items * 0.01 THEN 1 ELSE 0 END)
    AS top_1pct_items,
    ROUND(
        (
            SELECT
                SUM(view_events)
            FROM ranked_items
            WHERE item_rank <= total_items * 0.01
        )::numeric / SUM(view_events) * 100, 2
) AS top_1pct_view_share
FROM ranked_items
;

-- Оценка на сколько "длинный хвост"


WITH product_events AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
        SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
        SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
    FROM events
    GROUP BY itemid
)
SELECT
    SUM(CASE WHEN view_events = 1 THEN 1 ELSE 0 END) AS items_with_one_view,
    SUM(CASE WHEN view_events > 0 THEN 1 ELSE 0 END) AS items_with_view,
    ROUND(
        SUM(CASE WHEN view_events = 1 THEN 1 ELSE 0 END)::numeric /
        SUM(CASE WHEN view_events > 0 THEN 1 ELSE 0 END) * 100, 2
    ) AS pct_view_1
FROM product_events;


-- Концентрация покупок

WITH product_events AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
        SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
        SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
    FROM events
    GROUP BY itemid
),
ranked_items AS (
    SELECT
        itemid,
        trans_events,
        ROW_NUMBER() OVER(ORDER BY trans_events DESC, itemid) as item_rank,
        COUNT(*) OVER () AS total_items
    FROM product_events
)
SELECT
    SUM(CASE WHEN item_rank <= total_items * 0.01 THEN 1 ELSE 0 END)
    AS top_1pct_items,
    ROUND(
        (
            SELECT
                SUM(trans_events)
            FROM ranked_items
            WHERE item_rank <= total_items * 0.01
        )::numeric / SUM(trans_events) * 100, 2
) AS top_1pct_trans_share
FROM ranked_items
;

-- Проверка совпадение лидеров
WITH product_events AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
        SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
        SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS trans_events
    FROM events
    GROUP BY itemid
),
ranked_items AS (
    SELECT
        itemid,
        view_events,
        trans_events,
        ROW_NUMBER() OVER(ORDER BY view_events DESC, itemid) AS view_rank,
        ROW_NUMBER() OVER(ORDER BY trans_events DESC, itemid) AS trans_rank,
        COUNT(*) OVER () AS total_items
    FROM product_events
)
 SELECT
    SUM(CASE WHEN view_rank <= total_items * 0.01
    AND trans_rank <= total_items * 0.01 THEN 1 ELSE 0 END) AS count_1_pct_top
FROM ranked_items
;
