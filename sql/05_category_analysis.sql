-- CATEGORY ANALYSIS


-- Покрытие категорий для всех событий

SELECT
    COUNT(*) AS total_events,
    COUNT(categoryid) AS events_with_category,
    ROUND(
        COUNT(categoryid) :: numeric/
        COUNT(*) * 100, 2
    ) AS pct_events_with_category
FROM events AS e
LEFT JOIN LATERAL (
    SELECT
        itemid,
        categoryid,
        datetime_item
    FROM item_category_history
    WHERE itemid = e.itemid
    AND datetime_item <= e.datetime
    ORDER BY datetime_item DESC
    LIMIT 1
) AS cat ON TRUE
;

-- 10 категорий с наибольшим числом просмотров

SELECT
    cat.categoryid,
    SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS view_events,
    SUM(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
    SUM(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS transaction_events
FROM events AS e
LEFT JOIN LATERAL (
    SELECT h.categoryid
    FROM item_category_history AS h
    WHERE h.itemid = e.itemid
      AND h.datetime_item <= e.datetime
    ORDER BY h.datetime_item DESC
    LIMIT 1
) AS cat ON TRUE
WHERE cat.categoryid IS NOT NULL
GROUP BY cat.categoryid
ORDER BY view_events DESC, cat.categoryid
LIMIT 10;


-- Activity by root category


WITH RECURSIVE category_roots AS (
    SELECT
        categoryid,
        parentid,
        categoryid AS root_categoryid
    FROM category_tree
    WHERE parentid IS NULL
    UNION ALL
    SELECT
        child.categoryid,
        child.parentid,
        parent.root_categoryid
    FROM category_tree AS child
    JOIN category_roots AS parent
    ON child.parentid = parent.categoryid
),
event_categories AS (
    SELECT
        e.event,
        cat.categoryid
    FROM events AS e
    LEFT JOIN LATERAL (
        SELECT h.categoryid
        FROM item_category_history AS h
        WHERE h.itemid = e.itemid
            AND h.datetime_item <= e.datetime
        ORDER BY h.datetime_item DESC
        LIMIT 1
    ) AS cat ON TRUE
    WHERE cat.categoryid IS NOT NULL
)
SELECT
    roots.root_categoryid,
    COUNT(*) AS total_events,
    SUM(CASE WHEN ec.event = 'view' THEN 1 ELSE 0 END) AS view_events,
    SUM(CASE WHEN ec.event = 'addtocart' THEN 1 ELSE 0 END) AS addtocart_events,
    SUM(CASE WHEN ec.event = 'transaction' THEN 1 ELSE 0 END) AS transaction_events
FROM event_categories AS ec
LEFT JOIN category_roots AS roots
    ON roots.categoryid = ec.categoryid
GROUP BY roots.root_categoryid
ORDER BY view_events DESC, roots.root_categoryid NULLS LAST
;
