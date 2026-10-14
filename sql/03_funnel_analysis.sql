-- FUNNEL ANALYSIS

-- ОСНОВНАЯ ВОРОНКА
-- Каждому пользователю нужно дать одинаковые 7 суток для прохождения пути.
-- Если первый просмотр произошёл слишком близко к концу данных,
-- отсутствие покупки нельзя считать непройденной конверсией.

-- Первый наблюдаемый view каждого пользователя
WITH first_view AS (
    SELECT
        visitorid, MIN(datetime) AS first_view_at
    FROM events
    WHERE event = 'view'
    GROUP BY visitorid
),

-- Конец наблюдений среди всех событий
observation_end AS (
    SELECT
        MAX(datetime) AS observation_end_at
    FROM events
)

-- Пользователи, у которых первый просмотр не позже 7 дней до конца наблюдений
SELECT
    visitorid,
    first_view_at,
    first_view_at + INTERVAL '7 days' AS window_end_at
FROM first_view
WHERE first_view_at + INTERVAL '7 days' <= (
    SELECT
        observation_end_at
    FROM observation_end
);

-- Проверка размера входной аудитории.
WITH first_view AS (
    SELECT
        visitorid, MIN(datetime) AS first_view_at
    FROM events
    WHERE event = 'view'
    GROUP BY visitorid
),
observation_end AS (
    SELECT
        MAX(datetime) AS observation_end_at
    FROM events
),
visitors_with_7_days AS (
    SELECT
        visitorid,
        first_view_at,
        first_view_at + INTERVAL '7 days' AS window_end_at
    FROM first_view
    WHERE first_view_at + INTERVAL '7 days' <= (
        SELECT
            observation_end_at
        FROM observation_end
)
),

-- Переход к корзине
first_cart AS (
    SELECT
        v.visitorid,
        v.first_view_at,
        v.window_end_at,
        MIN(e.datetime) AS first_cart_at
    FROM visitors_with_7_days AS v
    LEFT JOIN events AS e
    ON v.visitorid = e.visitorid
    AND e.event = 'addtocart'
    AND e.datetime > v.first_view_at
    AND e.datetime <= v.window_end_at
    GROUP BY
        v.visitorid,
        v.first_view_at,
        v.window_end_at
),

-- Первую покупка после найденной корзины
first_transaction AS (
    SELECT
        c.visitorid,
        c.first_view_at,
        c.first_cart_at,
        c.window_end_at,
        MIN(e.datetime) AS first_transaction_at
    FROM first_cart AS c
    LEFT JOIN events AS e
    ON c.visitorid = e.visitorid
    AND e.event = 'transaction'
    AND e.datetime > c.first_cart_at
    AND e.datetime <= c.window_end_at
    GROUP BY
        c.visitorid,
        c.first_view_at,
        c.first_cart_at,
        c.window_end_at
),
count_all AS (
    SELECT
        COUNT(first_view_at) AS view_users,
        COUNT(first_cart_at) AS cart_users,
        COUNT(first_transaction_at) AS transaction_users
    FROM first_transaction
)
SELECT
    view_users,
    cart_users,
    transaction_users,
    ROUND(cart_users::numeric / view_users * 100, 2) AS conv_view_to_cart,
    ROUND(transaction_users::numeric / cart_users * 100, 2) AS conv_cart_to_trans,
    ROUND(transaction_users::numeric / view_users * 100, 2) AS conv_view_to_trans,
    view_users - cart_users AS users_without_cart,
    cart_users - transaction_users AS cart_users_without_transaction
FROM count_all
;

-- ДОПОЛНИТЕЛЬНАЯ ВОРОНКА
-- У скольких пользователей нашлась хотя бы одна последовательность,
-- даже если она началась не с первого просмотра или заняла больше 7 суток

-- ============================================================
-- Дополнительная пользовательская воронка за весь период
-- view → addtocart → transaction
-- ============================================================

WITH first_views AS (
    -- Первый зарегистрированный просмотр каждого пользователя
    SELECT
        visitorid,
        MIN(datetime) AS first_view_at
    FROM events
    WHERE event = 'view'
    GROUP BY visitorid
),

valid_carts AS (
    -- Первое добавление в корзину, перед которым был просмотр
    SELECT
        c.visitorid,
        MIN(c.datetime) AS first_cart_at
    FROM events AS c
    WHERE c.event = 'addtocart'
      AND EXISTS (
          SELECT 1
          FROM first_views AS v
          WHERE v.visitorid = c.visitorid
            AND v.first_view_at < c.datetime
      )
    GROUP BY c.visitorid
),

valid_transactions AS (
    -- Первая покупка после подходящего добавления в корзину
    SELECT
        t.visitorid,
        MIN(t.datetime) AS first_transaction_at
    FROM events AS t
    WHERE t.event = 'transaction'
      AND EXISTS (
          SELECT 1
          FROM valid_carts AS c
          WHERE c.visitorid = t.visitorid
            AND c.first_cart_at < t.datetime
      )
    GROUP BY t.visitorid
),

funnel_counts AS (
    -- Количество пользователей на каждом этапе
    SELECT
        (SELECT COUNT(*) FROM first_views) AS view_users,
        (SELECT COUNT(*) FROM valid_carts) AS cart_users,
        (SELECT COUNT(*) FROM valid_transactions) AS transaction_users
)

SELECT
    view_users,
    cart_users,
    transaction_users,

    ROUND(
        cart_users::numeric / view_users * 100,
        2
    ) AS view_to_cart_pct,

    ROUND(
        transaction_users::numeric / cart_users * 100,
        2
    ) AS cart_to_transaction_pct,

    ROUND(
        transaction_users::numeric / view_users * 100,
        2
    ) AS view_to_transaction_pct

FROM funnel_counts;


-- ТОВАРНАЯ ВОРОНКА

WITH view_user_item AS (
    SELECT
        visitorid,
        itemid,
        MIN(datetime) AS view_time
    FROM events
    WHERE event = 'view'
    GROUP BY visitorid, itemid
),
cart_user_item AS (
    SELECT
        visitorid,
        itemid,
        MIN(datetime) as cart_time
    FROM events as e
    WHERE event = 'addtocart'
    AND EXISTS(
        SELECT 1
        FROM view_user_item AS v
        WHERE e.visitorid = v.visitorid
        AND e.itemid = v.itemid
        AND e.datetime > v.view_time
    )
    GROUP BY visitorid, itemid

),
trans_user_item AS (
    SELECT
        visitorid,
        itemid,
        MIN(datetime) as trans_time
    FROM events AS e
    WHERE event = 'transaction'
    AND EXISTS(
        SELECT 1
        FROM cart_user_item as c
        WHERE e.visitorid = c.visitorid
        AND e.itemid = c.itemid
        AND e.datetime > c.cart_time
    )
    GROUP BY visitorid, itemid
),
funnel_user_item as (
    SELECT
        (SELECT COUNT(*) AS count_view FROM view_user_item) AS count_view,
        (SELECT COUNT(*) AS count_cart FROM cart_user_item) AS count_cart,
        (SELECT COUNT(*) AS count_transaction FROM trans_user_item) AS count_transaction
)
SELECT
    count_view,
    count_cart,
    count_transaction,

    ROUND((count_cart::numeric / count_view)*100,2) AS conv_view_to_cart,

    ROUND((count_transaction::numeric / count_cart)*100,2) AS conv_cart_to_trans,

    ROUND((count_transaction::numeric / count_view)*100,2) AS conv_view_to_trans

FROM funnel_user_item;