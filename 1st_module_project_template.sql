/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Орлов Михаил Евгеньевич
 * Дата: 31.07.2025
*/

   



-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?

-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

analysis_data AS (
    SELECT
        c.city AS "Город",
        CASE 
            WHEN a.days_exposition IS NULL THEN 'Активные объявления'
            WHEN a.days_exposition <= 30 THEN 'До 30 дней'
            WHEN a.days_exposition <= 90 THEN 'От 31 до 90 дней'
            WHEN a.days_exposition <= 180 THEN 'От 91 до 180 дней'
            ELSE 'Более 180 дней'
        END AS "Группа скорости продажи",
        CASE EXTRACT(DOW FROM a.first_day_exposition)
            WHEN 0 THEN 'Воскресенье'
            WHEN 1 THEN 'Понедельник'
            WHEN 2 THEN 'Вторник'
            WHEN 3 THEN 'Среда'
            WHEN 4 THEN 'Четверг'
            WHEN 5 THEN 'Пятница'
            WHEN 6 THEN 'Суббота'
        END AS "День публикации",
        COUNT(*) AS "Количество объявлений",
        AVG(f.total_area) AS "Средняя площадь",
        AVG(f.rooms) AS "Среднее комнат",
        AVG(f.balcony) AS "Среднее балконов",
        AVG(f.ceiling_height) AS "Средняя высота потолка",
        AVG(f.kitchen_area) AS "Средняя площадь кухни",
        AVG(a.last_price / f.total_area) AS "Средняя цена за м²",
        AVG(f.parks_around3000) AS "Среднее парков рядом",
        AVG(f.ponds_around3000) AS "Среднее водоемов рядом"
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE f.id IN (SELECT id FROM filtered_id)
      AND t.type = 'город'
    GROUP BY 
        c.city, 
        "Группа скорости продажи",
        "День публикации"
)
SELECT 
    "Город",
    "Группа скорости продажи",
    "День публикации",
    "Количество объявлений",
    ROUND("Средняя площадь"::numeric, 2) AS "Средняя площадь, м²",
    ROUND("Среднее комнат"::numeric, 1) AS "Среднее комнат",
    ROUND("Среднее балконов"::numeric, 1) AS "Среднее балконов",
    ROUND("Средняя высота потолка"::numeric, 2) AS "Средняя высота потолка, м",
    ROUND("Средняя площадь кухни"::numeric, 2) AS "Средняя площадь кухни, м²",
    ROUND("Средняя цена за м²"::numeric, 2) AS "Средняя цена за м², руб",
    ROUND("Среднее парков рядом"::numeric, 1) AS "Парки в радиусе 3 км",
    ROUND("Среднее водоемов рядом"::numeric, 1) AS "Водоемы в радиусе 3 км"
FROM analysis_data
ORDER BY 
    CASE "Группа скорости продажи"
        WHEN 'Активные объявления' THEN 0  -- Первыми идут активные
        WHEN 'До 30 дней' THEN 1
        WHEN 'От 31 до 90 дней' THEN 2
        WHEN 'От 91 до 180 дней' THEN 3
        ELSE 4
    END,
    "Количество объявлений" DESC,
    "Город",
    CASE "День публикации"
        WHEN 'Понедельник' THEN 1
        WHEN 'Вторник' THEN 2
        WHEN 'Среда' THEN 3
        WHEN 'Четверг' THEN 4
        WHEN 'Пятница' THEN 5
        WHEN 'Суббота' THEN 6
        WHEN 'Воскресенье' THEN 7
    END;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
filtered_ads AS (
    SELECT 
        a.id,
        a.first_day_exposition,
        a.days_exposition,
        EXTRACT(MONTH FROM a.first_day_exposition)::INT AS pub_month_num,
        TO_CHAR(a.first_day_exposition, 'Month') AS pub_month_name,
        CASE 
            WHEN a.days_exposition IS NOT NULL 
            THEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 DAY' * a.days_exposition)::INT
            ELSE NULL 
        END AS rem_month_num,
        CASE 
            WHEN a.days_exposition IS NOT NULL 
            THEN TO_CHAR(a.first_day_exposition + INTERVAL '1 DAY' * a.days_exposition, 'Month')
            ELSE NULL 
        END AS rem_month_name
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE t.type = 'город'
      AND f.id IN (SELECT id FROM filtered_id)
),
monthly_data AS (
    SELECT
        m.month_num,
        TO_CHAR(TO_DATE(m.month_num::TEXT, 'MM'), 'Month') AS month_name,
        COUNT(DISTINCT CASE WHEN f.pub_month_num = m.month_num THEN f.id END) AS publications,
        COUNT(DISTINCT CASE WHEN f.rem_month_num = m.month_num THEN f.id END) AS removals
    FROM generate_series(1,12) AS m(month_num)
    LEFT JOIN filtered_ads f ON true
    GROUP BY m.month_num
),
analysis_results AS (
    -- Топ месяцев по публикациям
    SELECT 
        'Топ публикаций' AS analysis_type,
        month_num,
        TRIM(month_name) AS month_name,
        publications AS value,
        ROW_NUMBER() OVER (ORDER BY publications DESC) AS rank
    FROM monthly_data
    
    UNION ALL
    
    -- Топ месяцев по снятиям
    SELECT 
        'Топ снятий' AS analysis_type,
        month_num,
        TRIM(month_name) AS month_name,
        removals AS value,
        ROW_NUMBER() OVER (ORDER BY removals DESC) AS rank
    FROM monthly_data
    
    UNION ALL
    
    -- Разница публикаций и снятий
    SELECT 
        'Чистое изменение' AS analysis_type,
        month_num,
        TRIM(month_name) AS month_name,
        publications - removals AS value,
        NULL AS rank
    FROM monthly_data
    
    UNION ALL
    
    -- Соотношение публикаций/снятий
    SELECT 
        'Соотношение Публикаций к Снятиям' AS analysis_type,
        month_num,
        TRIM(month_name) AS month_name,
        CASE 
            WHEN removals > 0 THEN publications::FLOAT / removals 
            ELSE NULL 
        END AS value,
        NULL AS rank
    FROM monthly_data
)

SELECT 
    analysis_type,
    month_num,
    month_name,
    value,
    CASE 
        WHEN analysis_type IN ('Топ публикаций', 'Топ снятий') 
        THEN RANK() OVER (PARTITION BY analysis_type ORDER BY value DESC)
        ELSE NULL 
    END AS rank
FROM analysis_results
ORDER BY 
    CASE analysis_type
        WHEN 'Топ публикаций' THEN 1
        WHEN 'Топ снятий' THEN 2
        WHEN 'Чистое изменение' THEN 3
        WHEN 'Соотношение Публикаций к Снятиям' THEN 4
    END,
    CASE 
        WHEN analysis_type IN ('Топ публикаций', 'Топ снятий') THEN rank 
        ELSE month_num
    END;

-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

SELECT
    TO_CHAR(first_day_exposition, 'MM') AS publication_month,
    AVG(last_price / total_area) AS avg_price_per_square_meter, -- средняя стоимость квадратного метра
    AVG(total_area) AS avg_area  -- средняя площадь квартир
FROM real_estate.advertisement
JOIN real_estate.flats USING (id)
GROUP BY publication_month
ORDER BY publication_month;


-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
city_analysis AS (
    SELECT
        city,
        AVG(last_price / total_area) AS avg_price_per_square_meter,  -- средняя стоимость квадратного метра
        AVG(total_area) AS avg_area,  -- средняя площадь квартир
        STDDEV(last_price / total_area) AS stddev_price_per_square_meter,  -- стандартное отклонение стоимости квадратного метра
        STDDEV(total_area) AS stddev_area  -- стандартное отклонение площади
    FROM filtered_data
    GROUP BY city
)
SELECT *
FROM city_analysis
ORDER BY avg_price_per_square_meter DESC;


-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
city_analysis AS (
    SELECT
        AVG(last_price / total_area) AS avg_price_per_square_meter,  -- средняя стоимость квадратного метра
        AVG(total_area) AS avg_area  -- средняя площадь квартир
    FROM filtered_data
)
SELECT *
FROM city_analysis;
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.
WITH filtered_data AS (
    SELECT
        f.city_id,
        c.city,
        a.id,
        a.days_exposition,
        a.last_price,
        f.total_area
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    WHERE c.city <> 'Санкт-Петербург'  -- фильтруем только Ленинградскую область
),
city_activity AS (
    SELECT
        city_id,
        city,
        COUNT(*) AS total_listings,
        SUM(CASE WHEN days_exposition > 0 THEN 1 ELSE 0 END) AS sold_listings,
        AVG(days_exposition) AS avg_days_exposition  -- средняя продолжительность 
    FROM filtered_data
    GROUP BY city_id, city
    HAVING COUNT(*) >= 50  -- фильтруем только населённые пункты с более чем 50 объявлениями
),
final_results AS (
    SELECT
        city,
        total_listings,
        sold_listings,
        (sold_listings::FLOAT / total_listings) * 100 AS sold_percentage,
        avg_days_exposition
    FROM city_activity
    ORDER BY avg_days_exposition ASC 
    LIMIT 15  -- выбираем топ-15 населённых пунктов
)
SELECT *
FROM final_results;
-- Напишите ваш запрос здесь