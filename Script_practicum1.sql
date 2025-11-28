/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Орлов Михаил Евгеньевич
 * Дата: 24.06.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
count (*) AS total_palyers, -- общее кол-во игроков
SUM(payer) AS paying_player, -- колво- платящих игроков
AVG(payer) AS paying_raito -- доля платящих игроков
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
race_id, --раса персонажа
sum(payer) AS paying_players_by_race, --количество платящих игроков
count(*) AS total_players_by_race, --  общее количество зарегистрированных игроков
avg (payer) AS paying_raito_by_race -- доля платящих игроков, для каждой расы
FROM 
fantasy.users
GROUP BY 
race_id 
ORDER by
race_id;



-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
count (transaction_id) AS tottal_purchases, -- общее кол во покупок
sum (amount) AS total_spent, -- суммарная стоимоть всех покупок
min (amount) AS min_purchase_value,  -- минимальная стоимость покупки
max (amount) AS max_purchase_value, -- макс стоимость покупки
AVG(amount) AS average_purchase_value, -- среднее значение стоимсоти покупки
percentile_cont(0.5) WITHIN GROUP (ORDER BY amount) AS median_purchase_value, -- медиана стоимости покупки
STDDEV (amount) AS standard_deviation -- стандартное отклонение стоимости покупки
FROM 
fantasy.events
-- 2.2: Аномальные нулевые покупки:
SELECT
count(*) FILTER (WHERE amount = 0) AS purchases_with_zero_amount, -- кол-во покупок с 0 стоимостью
count(*) AS total_purchases, -- общее колво покупок
count (*) FILTER (WHERE amount =0) * 1.0 / count(*) AS share_of_zero_amount_purchases   -- доля покупок с 0 стоимостью
FROM 
fantasy.events;
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
SELECT 
payer,  -- значение, которое указывает, является ли игрок платящим — покупал ли валюту «райские лепестки» за реальные деньги. 1 — платящий, 0 — не платящий.
count(DISTINCT id)  AS total_players, -- общее количество игроков в группе
round (avg(CAST(number_of_purchases AS NUMERIC)), 2) AS avg_purchases_per_player, -- среднее количество покупок на одного игрока
ROUND(AVG(CAST(total_spent AS NUMERIC)), 2) AS avg_total_spent_per_player  -- средняя суммарная стоимость покупок на одного игрока
FROM (
SELECT
u.id,  -- идентификатор игрока. Первичный ключ таблицы
u.payer, --является ли игрок платящим
count(e.transaction_id) AS number_of_purchases, -- колво покупок игрока
sum (e.amount) AS total_spent   --суммарная стоимость покупок игрока
 FROM 
        fantasy.users u
    INNER JOIN 
        fantasy.events e ON u.id = e.id
    GROUP BY 
        u.id, u.payer
) player_statistics
GROUP BY 
    payer;


-- 2.4: Популярные эпические предметы:
-- общее колво продаж каждого предмета и доля от всех продаж
WITH item_sales AS (
    SELECT 
        item_code,  -- Код предмета
        COUNT(*) AS total_sales,  -- Абсолютное количество продаж
        COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS sales_percentage  -- Доля продаж от общего объёма
    FROM 
        fantasy.events
    GROUP BY 
        item_code
)
SELECT 
    game_items,  -- Название предмета
    total_sales,  -- Количество продаж
    sales_percentage  -- Доля продаж
FROM 
    fantasy.items i
JOIN 
    item_sales isales ON i.item_code = isales.item_code
ORDER BY 
    total_sales DESC;
-- подсчте доли игроков которые купили игровой предмет хотя бы один раз
WITH item_sales AS (
    SELECT 
        item_code,  -- Код предмета
        COUNT(*) AS total_sales,  -- Абсолютное количество продаж
        COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS sales_percentage,  -- Доля продаж от общего объёма
        COUNT(DISTINCT id) AS buyers_count  -- Количество уникальных игроков, купивших предмет
    FROM 
        fantasy.events
    GROUP BY 
        item_code
),
total_players AS (
    SELECT 
        COUNT(DISTINCT id) AS total_unique_players  -- Общее количество уникальных игроков
    FROM 
        fantasy.events
)
SELECT 
    game_items,  -- Название предмета
    total_sales,  -- Количество продаж
    sales_percentage,  -- Доля продаж
    buyers_count,  -- Количество игроков, купивших предмет
    buyers_count * 1.0 / tp.total_unique_players AS buyers_percentage  -- Доля игроков, купивших предмет
FROM 
    fantasy.items i
JOIN 
    item_sales isales ON i.item_code = isales.item_code
CROSS JOIN 
    total_players tp
ORDER BY 
    buyers_percentage DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- сначала посчитаем общее кол-во игроков на каждой расе
WITH
registered_players AS (
    SELECT 
        race_id, 
        COUNT(id) AS total_players
    FROM 
        fantasy.users
    GROUP BY 
        race_id
),
-- считаем кол-во игроков совершивших покупки и их процент от общего числа

paying_players AS (
    SELECT 
        u.race_id, 
        COUNT(DISTINCT u.id) AS paying_players_count,
        COUNT(DISTINCT u.id) * 1.0 / rp.total_players AS paying_players_ratio
    FROM 
        fantasy.users u
    JOIN 
        fantasy.events e ON u.id = e.id
    JOIN 
        registered_players rp ON u.race_id = rp.race_id
    WHERE 
        e.amount > 0  -- Фильтрация покупок с нулевой стоимостью
    GROUP BY 
        u.race_id, rp.total_players
),
-- собираем информацию об активных игроках, которые совершили покупки
purchase_activity AS (
    SELECT 
        u.race_id, 
        COUNT(e.transaction_id) AS total_purchases,  -- общее количество покупок
        AVG(e.amount) AS avg_purchase_value,  -- средняя стоимость одной покупки
        SUM(e.amount) AS total_spent  -- суммарная стоимость всех покупок
    FROM 
        fantasy.users u
    JOIN 
        fantasy.events e ON u.id = e.id
    WHERE 
        e.amount > 0  -- Фильтрация покупок с нулевой стоимостью
    GROUP BY 
        u.race_id
)
SELECT 
    r.race,  -- название расы
    rp.total_players,  -- общее количество зарегистрированных игроков
    pp.paying_players_count,  -- количество игроков, совершивших покупки
    pp.paying_players_ratio,  -- доля платящих игроков
    pa.total_purchases / pp.paying_players_count AS avg_purchases_per_paying_player,  -- среднее количество покупок на одного платящего игрока
    pa.avg_purchase_value,  -- средняя стоимость одной покупки
    pa.total_spent / pp.paying_players_count AS avg_total_spent_per_paying_player,  -- средняя суммарная стоимость всех покупок на одного платящего игрока
    pa.total_spent / COUNT(DISTINCT u.id) AS avg_total_spent_per_all_players  -- новая метрика: средняя суммарная стоимость всех покупок на одного игрока (включая неплатящих)
FROM 
    fantasy.race r
JOIN 
    registered_players rp ON r.race_id = rp.race_id
JOIN 
    paying_players pp ON r.race_id = pp.race_id
JOIN 
    purchase_activity pa ON r.race_id = pa.race_id
JOIN 
    fantasy.users u ON r.race_id = u.race_id
GROUP BY 
    r.race, rp.total_players, pp.paying_players_count, pp.paying_players_ratio, pa.total_purchases, pa.avg_purchase_value, pa.total_spent
ORDER BY 
    avg_total_spent_per_paying_player DESC;
-- Задача 2: Частота покупок
WITH purchase_data AS (
    SELECT 
        ev.id, 
        amount, 
        CONCAT(date, ' ', time) AS full_purchase_time, 
        LEAD(CONCAT(date, ' ', time)) OVER (PARTITION BY ev.id ORDER BY CONCAT(date, ' ', time)) AS next_full_purchase_time 
    FROM 
        fantasy.events ev
    WHERE 
        amount > 0
),
purchase_summary AS (
    SELECT 
        ev.id, 
        COUNT(*) AS num_purchases, 
        AVG(
            EXTRACT(DAY FROM age(TO_TIMESTAMP(next_full_purchase_time, 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP(full_purchase_time, 'YYYY-MM-DD HH24:MI:SS')))
        ) AS avg_days_between_purchases 
    FROM 
        purchase_data ev
    GROUP BY 
        ev.id
)
SELECT 
    CASE 
        WHEN num_purchases > 10 AND avg_days_between_purchases < 7 THEN 'Активные игроки'
        WHEN num_purchases BETWEEN 3 AND 10 AND avg_days_between_purchases BETWEEN 7 AND 30 THEN 'Умеренно активные игроки'
        ELSE 'Низкоактивные игроки'
    END AS player_group,
    COUNT(DISTINCT ps.id) AS player_count, 
    AVG(ps.num_purchases) AS avg_purchases_per_player, 
    AVG(ps.avg_days_between_purchases) AS avg_days_between_purchases, -- Среднее колво дней между покупками
    AVG(CASE WHEN us.payer = 1 THEN 1 ELSE 0 END) AS paying_players_ratio 
FROM 
    purchase_summary ps
JOIN 
    fantasy.users us ON ps.id = us.id
GROUP BY 
    player_group
ORDER BY 
    player_count DESC;
